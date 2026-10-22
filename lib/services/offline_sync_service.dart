// lib/services/offline_sync_service.dart
//
// V.10.10 Saisie offline — V.10.11 Synchronisation
// Médecin : enregistre consultations hors ligne (SQLite + pending_sync),
// push automatique vers Laravel dès que le réseau revient.

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import 'db_service.dart';
import 'medecin_api_service.dart';
import 'sync_service_hybrid.dart';

class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  final _db = DatabaseService.instance;
  final _api = MedecinApiService.instance;
  final _hybrid = SyncServiceHybrid.instance;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _syncing = false;
  bool _online = true;

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<String?> lastSyncMessage = ValueNotifier(null);

  bool get currentlyOnline => _online;

  /// Démarre l'écoute réseau (à appeler depuis la nav médecin).
  Future<void> start() async {
    await refreshPendingCount();
    _online = await _hybrid.isOnline();
    isOnline.value = _online;

    await _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      final online = results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
      final wasOffline = !_online;
      _online = online;
      isOnline.value = online;

      if (online && wasOffline) {
        lastSyncMessage.value = 'Connexion rétablie — synchronisation…';
        await syncNow(reason: 'reconnect');
      }
    });

    // Sync au démarrage si en ligne et file non vide
    if (_online && pendingCount.value > 0) {
      await syncNow(reason: 'startup');
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> refreshPendingCount() async {
    pendingCount.value = await _db.getPendingSyncCount();
  }

  // ── Cache RDV (pour ouvrir consultation hors ligne) ──────────────────────

  Future<void> cacheAppointments(List<Appointment> list) async {
    await _db.replaceCachedAppointments(
      list.map((a) => a.toCacheMap()).toList(),
    );
  }

  Future<List<Appointment>> loadCachedAppointments() async {
    final rows = await _db.getCachedAppointments();
    return rows.map(Appointment.fromCacheMap).toList();
  }

  // ── Enregistrement consultation (online ou offline) ─────────────────────

  /// Retourne `synced` si push immédiat, `queued` si mis en file locale.
  Future<OfflineSaveResult> saveConsultation({
    required Map<String, dynamic> payload,
    required int appointmentId,
    required String patientName,
  }) async {
    final online = await _hybrid.isOnline();
    _online = online;
    isOnline.value = online;

    if (online) {
      try {
        await _api.createConsultationFromPayload(payload);
        // Marquer localement le RDV comme Termine dans le cache
        await _db.updateCachedAppointmentStatut(appointmentId, 'Termine');
        await refreshPendingCount();
        return OfflineSaveResult.synced;
      } catch (e) {
        // API down → file d'attente
        debugPrint('⚠️ Push consultation échoué, queue: $e');
      }
    }

    // Enrichir pour sync différée (jour J offline → sync J+1)
    final queued = Map<String, dynamic>.from(payload);
    queued['offline_recorded_at'] =
        DateTime.now().toIso8601String();

    await _db.enqueueRawSync(
      entityType: 'consultation',
      entityId: appointmentId,
      action: 'create',
      payload: queued,
    );
    await _db.updateCachedAppointmentStatut(appointmentId, 'Termine');
    await refreshPendingCount();
    lastSyncMessage.value =
        'Consultation de $patientName enregistrée hors ligne';
    return OfflineSaveResult.queued;
  }

  /// PUSH file d'attente + sync carnet patients.
  Future<OfflineSyncResult> syncNow({String reason = 'manual'}) async {
    if (_syncing) {
      return OfflineSyncResult(
        success: false,
        online: _online,
        message: 'Sync déjà en cours',
      );
    }

    final online = await _hybrid.isOnline();
    _online = online;
    isOnline.value = online;

    if (!online) {
      return OfflineSyncResult(
        success: false,
        online: false,
        message: 'Hors ligne — sync impossible',
      );
    }

    _syncing = true;
    var consultationsPushed = 0;
    try {
      consultationsPushed = await _pushPendingConsultations();
      final hybrid = await _hybrid.syncAll();
      await refreshPendingCount();

      if (pendingCount.value > 0) {
        return OfflineSyncResult(
          success: false,
          online: true,
          message:
              'Sync partielle — ${pendingCount.value} élément(s) restent en attente. '
              '${hybrid.message}',
          consultationsPushed: consultationsPushed,
          patientsPushed: hybrid.pendingPushed,
        );
      }
      if (!hybrid.success) {
        return OfflineSyncResult(
          success: false,
          online: true,
          message: hybrid.message,
          consultationsPushed: consultationsPushed,
          patientsPushed: hybrid.pendingPushed,
        );
      }

      final msg =
          'Sync OK ($reason) — $consultationsPushed consultation(s), '
          '${hybrid.pendingPushed} patient(s)';
      lastSyncMessage.value = msg;
      return OfflineSyncResult(
        success: true,
        online: true,
        message: msg,
        consultationsPushed: consultationsPushed,
        patientsPushed: hybrid.pendingPushed,
      );
    } catch (e) {
      final msg = 'Erreur sync : $e';
      lastSyncMessage.value = msg;
      return OfflineSyncResult(
        success: false,
        online: true,
        message: msg,
      );
    } finally {
      _syncing = false;
      await refreshPendingCount();
    }
  }

  Future<int> _pushPendingConsultations() async {
    final items = await _db.getPendingSyncItems(entityType: 'consultation');
    var pushed = 0;

    for (final item in items) {
      try {
        final payload =
            jsonDecode(item['payload'] as String) as Map<String, dynamic>;
        await _api.createConsultationFromPayload(payload);
        await _db.removePendingSyncItem(item['id'] as int);
        final apptId = item['entity_id'] as int?;
        if (apptId != null) {
          await _db.updateCachedAppointmentStatut(apptId, 'Termine');
        }
        pushed++;
      } catch (e) {
        debugPrint('❌ Échec sync consultation ${item['id']}: $e');
        // On laisse en file pour retry
      }
    }
    return pushed;
  }
}

enum OfflineSaveResult { synced, queued }

class OfflineSyncResult {
  final bool success;
  final bool online;
  final String message;
  final int consultationsPushed;
  final int patientsPushed;

  OfflineSyncResult({
    required this.success,
    required this.online,
    required this.message,
    this.consultationsPushed = 0,
    this.patientsPushed = 0,
  });
}
