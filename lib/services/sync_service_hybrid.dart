// lib/services/sync_service_hybrid.dart
//
// Synchronisation hybride SQLite ↔ MySQL via API Laravel
// - En ligne : MySQL (API) est la source de vérité, cache SQLite mis à jour
// - Hors ligne : SQLite + file d'attente pending_sync
// - Retour en ligne : PUSH de la queue puis PULL depuis MySQL

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/patient.dart';
import 'api_service.dart';
import 'db_service.dart';

class SyncServiceHybrid {
  static final SyncServiceHybrid instance = SyncServiceHybrid._internal();
  SyncServiceHybrid._internal();

  final DatabaseService _db = DatabaseService.instance;
  final _storage = const FlutterSecureStorage();

  DateTime? lastSyncAt;
  bool _lastOnline = true;

  bool get wasOnline => _lastOnline;

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  }

  Future<void> _ensureAuthToken() async {
    if (ApiService.authToken != null) return;
    final token = await _storage.read(key: 'jwt_token');
    if (token != null && token.isNotEmpty) {
      ApiService.authToken = token;
    }
  }

  /// Synchronisation complète : PUSH queue puis PULL MySQL → SQLite
  Future<HybridSyncResult> syncAll() async {
    final online = await isOnline();
    _lastOnline = online;

    if (!online) {
      return HybridSyncResult(
        success: false,
        online: false,
        message: 'Hors ligne — données locales utilisées',
      );
    }

    try {
      await _ensureAuthToken();
      final pushed = await _pushPendingChanges();
      final pendingPatients = await _db.getPendingSyncItems(
        entityType: 'patient',
      );
      if (pendingPatients.isNotEmpty) {
        return HybridSyncResult(
          success: false,
          online: true,
          message:
              '${pendingPatients.length} modification(s) patient non synchronisée(s) — cache local conservé',
          pendingPushed: pushed,
        );
      }

      final patients = await ApiService.fetchPatients();
      await _db.replaceAllPatients(patients);
      lastSyncAt = DateTime.now();

      return HybridSyncResult(
        success: true,
        online: true,
        message: 'Sync OK (${patients.length} patients, $pushed en file)',
        patientCount: patients.length,
        pendingPushed: pushed,
      );
    } catch (e) {
      print('⚠️ Sync API échouée, fallback SQLite: $e');
      return HybridSyncResult(
        success: false,
        online: true,
        message: 'API indisponible — cache local conservé ($e)',
      );
    }
  }

  Future<int> _pushPendingChanges() async {
    // Uniquement le carnet patients — les consultations passent par OfflineSyncService
    final items = await _db.getPendingSyncItems(entityType: 'patient');
    var pushed = 0;

    for (final item in items) {
      try {
        final action = item['action'] as String;
        final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
        final serverId = item['server_id'] as int?;
        final localId = item['entity_id'] as int?;

        switch (action) {
          case 'create':
            final created = await ApiService.createPatient(
              Patient.fromMap({...payload, 'id': null}),
            );
            if (localId != null && created.syncId != null) {
              await _db.updatePatientServerId(localId, created.syncId!);
            } else {
              throw StateError(
                'Le serveur n’a pas retourné l’identifiant patient',
              );
            }
            break;
          case 'update':
            if (serverId == null) {
              throw StateError(
                'Identifiant serveur manquant pour la mise à jour',
              );
            }
            await ApiService.updatePatient(serverId, payload);
            break;
          case 'delete':
            if (serverId == null) {
              throw StateError(
                'Identifiant serveur manquant pour la suppression',
              );
            }
            await ApiService.deletePatient(serverId);
            break;
          default:
            throw StateError('Action de synchronisation inconnue : $action');
        }

        await _db.removePendingSyncItem(item['id'] as int);
        pushed++;
      } catch (e) {
        print('❌ Échec sync item ${item['id']}: $e');
      }
    }
    return pushed;
  }

  // ========== LECTURE (API d'abord, SQLite en fallback) ==========

  Future<List<Patient>> getRecentPatients(int limit) async {
    return _db.getRecentPatients(limit);
  }

  Future<List<Patient>> getAllPatients() async {
    return _db.getAllPatients();
  }

  Future<int> getPatientCount() async {
    return _db.getPatientCount();
  }

  Future<List<Patient>> searchPatients(String query) async {
    return _db.searchPatients(query);
  }

  Future<Patient?> getPatientById(int id) async {
    return _db.getPatientById(id);
  }

  // ========== ÉCRITURE (SQLite d'abord, puis API ou queue) ==========

  Future<int> insertPatient(Patient patient) async {
    final localId = await _db.insertPatient(patient);
    final online = await isOnline();

    if (online) {
      try {
        await _ensureAuthToken();
        final created = await ApiService.createPatient(patient);
        await _db.updatePatientServerId(localId, created.syncId!);
        return created.syncId ?? localId;
      } catch (e) {
        print('⚠️ Push create échoué, mise en queue: $e');
      }
    }

    await _db.enqueueSync(
      action: 'create',
      patient: patient.copyWith(id: localId),
      localId: localId,
    );
    return localId;
  }

  Future<int> updatePatient(Patient patient) async {
    final rows = await _db.updatePatient(patient);
    final online = await isOnline();

    final localId = patient.id;
    if (patient.serverId == null && localId != null) {
      final pending = await _db.getPendingSyncItems(
        entityType: 'patient',
        entityId: localId,
      );
      Map<String, dynamic>? createItem;
      for (final item in pending) {
        if (item['action'] == 'create') {
          createItem = item;
          break;
        }
      }
      if (createItem != null) {
        await _db.updatePendingSyncItemPayload(
          createItem['id'] as int,
          patient.toApiMap(),
        );
        return rows;
      }
    }

    if (online && patient.serverId != null) {
      try {
        await _ensureAuthToken();
        await ApiService.updatePatient(patient.serverId!, patient.toApiMap());
        return rows;
      } catch (e) {
        print('⚠️ Push update échoué, mise en queue: $e');
      }
    }

    await _db.enqueueSync(
      action: 'update',
      patient: patient,
      localId: patient.id,
    );
    return rows;
  }

  Future<int> deletePatient(int id) async {
    final patient = await _db.getPatientById(id);
    if (patient == null) return 0;

    if (patient.serverId == null) {
      final pending = await _db.getPendingSyncItems(
        entityType: 'patient',
        entityId: id,
      );
      final hasPendingCreate = pending.any(
        (item) => item['action'] == 'create',
      );
      if (hasPendingCreate) {
        await _db.removePendingSyncItems(entityType: 'patient', entityId: id);
        return _db.deletePatient(id);
      }
    }

    final online = await isOnline();
    final rows = await _db.deletePatient(id);

    if (online && patient.serverId != null) {
      try {
        await _ensureAuthToken();
        await ApiService.deletePatient(patient.serverId!);
        return rows;
      } catch (e) {
        print('⚠️ Push delete échoué, mise en queue: $e');
      }
    }

    await _db.enqueueSync(
      action: 'delete',
      patient: patient,
      localId: id,
    );
    return rows;
  }

  Future<int> getPendingCount() => _db.getPendingSyncCount();
}

class HybridSyncResult {
  final bool success;
  final bool online;
  final String message;
  final int patientCount;
  final int pendingPushed;

  HybridSyncResult({
    required this.success,
    required this.online,
    required this.message,
    this.patientCount = 0,
    this.pendingPushed = 0,
  });
}
