// lib/services/calendar_sync_service.dart
//
// Synchronise les créneaux du doctor ET les RDV du patient
// avec le calendrier natif du téléphone (Google Calendar, Samsung Calendar, etc.)
//
// Doctor  : ajoute ses créneaux de disponibilité dans l'agenda
// Patient : ajoute son RDV confirmé dans l'agenda
//
// Les événements créés sont regroupés dans un calendrier dédié
// "Mob-Clinic" pour ne pas polluer les calendriers personnels.

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/appointment.dart';

class CalendarSyncService {
  CalendarSyncService._();
  static final CalendarSyncService instance = CalendarSyncService._();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  static const String _calendarIdKey  = 'mob_clinic_calendar_id';
  static const String _calendarName   = 'Mob-Clinic';

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Demande la permission calendrier.
  /// Retourne true si accordée.
  Future<bool> requestPermission() async {
    try {
      final result = await _plugin.requestPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      debugPrint('[CalendarSync] Permission error: $e');
      return false;
    }
  }

  /// Vérifie si la permission est déjà accordée.
  Future<bool> hasPermission() async {
    try {
      final result = await _plugin.hasPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      return false;
    }
  }

  // ── Calendrier dédié "Mob-Clinic" ─────────────────────────────────────────

  /// Trouve ou crée le calendrier "Mob-Clinic" dans l'agenda du téléphone.
  /// L'ID est mis en cache dans SharedPreferences pour éviter les doublons.
  Future<String?> _getOrCreateCalendar() async {
    try {
      _initTimezones();

      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_calendarIdKey);

      // Vérifier que le calendrier en cache existe toujours
      if (cached != null) {
        final cals = await _plugin.retrieveCalendars();
        if (cals.isSuccess) {
          final exists = cals.data?.any((c) => c.id == cached) ?? false;
          if (exists) return cached;
        }
      }

      // Créer un nouveau calendrier local dédié
      final result = await _plugin.createCalendar(
        _calendarName,
        calendarColor: const Color(0xFF107ACA),
        localAccountName: _calendarName,
      );

      if (result.isSuccess && result.data != null) {
        await prefs.setString(_calendarIdKey, result.data!);
        debugPrint('[CalendarSync] Calendrier créé : ${result.data}');
        return result.data;
      }
      debugPrint('[CalendarSync] Impossible de créer le calendrier');
      return null;
    } catch (e) {
      debugPrint('[CalendarSync] _getOrCreateCalendar error: $e');
      return null;
    }
  }

  // ── API publique ───────────────────────────────────────────────────────────

  /// [DOCTOR] Ajoute un créneau de disponibilité dans l'agenda.
  ///
  /// Exemple : "Disponibilité Mob-Clinic 09:00–10:00"
  /// Retourne l'eventId créé, ou null en cas d'échec.
  Future<String?> addCreneauToCalendar(Creneau creneau, {String? doctorName}) async {
    if (!await _ensurePermission()) return null;
    final calId = await _getOrCreateCalendar();
    if (calId == null) return null;

    try {
      final start = _toTZDateTime(creneau.date, creneau.heureDebut);
      final end   = _toTZDateTime(creneau.date, creneau.heureFin);

      final event = Event(
        calId,
        title: '🏥 Disponibilité Mob-Clinic',
        description: doctorName != null
            ? 'Créneau de disponibilité — Dr. $doctorName\nID: ${creneau.id}'
            : 'Créneau de disponibilité Mob-Clinic\nID: ${creneau.id}',
        start: start,
        end: end,
        reminders: [
          Reminder(minutes: 30), // Rappel 30 min avant
        ],
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess ?? false) {
        debugPrint('[CalendarSync] Créneau #${creneau.id} ajouté → ${result?.data}');
        return result?.data;
      }
      return null;
    } catch (e) {
      debugPrint('[CalendarSync] addCreneauToCalendar error: $e');
      return null;
    }
  }

  /// [DOCTOR] Supprime un créneau de l'agenda à partir de son eventId.
  Future<bool> removeCreneauFromCalendar(String eventId) async {
    if (!await hasPermission()) return false;
    final calId = await _getOrCreateCalendar();
    if (calId == null) return false;

    try {
      final result = await _plugin.deleteEvent(calId, eventId);
      return result.isSuccess ? (result.data ?? false) : false;
    } catch (e) {
      debugPrint('[CalendarSync] removeCreneauFromCalendar error: $e');
      return false;
    }
  }

  /// [PATIENT] Ajoute un RDV confirmé dans l'agenda du patient.
  ///
  /// Exemple : "RDV Dr. Dupont — Cardiologie"
  /// Retourne l'eventId créé, ou null en cas d'échec.
  Future<String?> addAppointmentToCalendar({
    required int appointmentId,
    required DateTime dateRdv,
    required String doctorName,
    required String serviceName,
    required String motif,
    String? meetingUrl,
    bool isTeleconsultation = false,
  }) async {
    if (!await _ensurePermission()) return null;
    final calId = await _getOrCreateCalendar();
    if (calId == null) return null;

    try {
      final start = tz.TZDateTime.from(dateRdv.toLocal(), tz.local);
      final end   = start.add(const Duration(minutes: 30));

      final description = StringBuffer()
        ..writeln('📋 Motif : $motif')
        ..writeln('🏥 Service : $serviceName')
        ..writeln(isTeleconsultation ? '💻 Téléconsultation' : '🏢 Présentiel');
      if (isTeleconsultation && meetingUrl != null) {
        description.writeln('🔗 Lien : $meetingUrl');
      }
      description.write('ID RDV : $appointmentId');

      final event = Event(
        calId,
        title: isTeleconsultation
            ? '💻 Téléconsultation — Dr. $doctorName'
            : '🏥 RDV — Dr. $doctorName',
        description: description.toString(),
        start: start,
        end: end,
        reminders: [
          Reminder(minutes: 1440), // J-1 (24h avant)
          Reminder(minutes: 60),   // H-1
          Reminder(minutes: 15),   // 15 min avant
        ],
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess ?? false) {
        debugPrint('[CalendarSync] RDV #$appointmentId ajouté → ${result?.data}');
        return result?.data;
      }
      return null;
    } catch (e) {
      debugPrint('[CalendarSync] addAppointmentToCalendar error: $e');
      return null;
    }
  }

  /// [PATIENT] Met à jour un RDV existant dans l'agenda (ex: après reschedule).
  Future<String?> updateAppointmentInCalendar({
    required String existingEventId,
    required int appointmentId,
    required DateTime dateRdv,
    required String doctorName,
    required String serviceName,
    required String motif,
    String? meetingUrl,
    bool isTeleconsultation = false,
  }) async {
    // device_calendar met à jour via le même createOrUpdateEvent si on passe l'eventId
    if (!await hasPermission()) return null;
    final calId = await _getOrCreateCalendar();
    if (calId == null) return null;

    try {
      final start = tz.TZDateTime.from(dateRdv.toLocal(), tz.local);
      final end   = start.add(const Duration(minutes: 30));

      final event = Event(
        calId,
        eventId: existingEventId,
        title: isTeleconsultation
            ? '💻 Téléconsultation — Dr. $doctorName'
            : '🏥 RDV — Dr. $doctorName',
        description: 'Motif : $motif\nService : $serviceName\nID : $appointmentId',
        start: start,
        end: end,
        reminders: [
          Reminder(minutes: 1440),
          Reminder(minutes: 60),
          Reminder(minutes: 15),
        ],
      );

      final result = await _plugin.createOrUpdateEvent(event);
      return (result?.isSuccess ?? false) ? result?.data : null;
    } catch (e) {
      debugPrint('[CalendarSync] updateAppointmentInCalendar error: $e');
      return null;
    }
  }

  /// [PATIENT/DOCTOR] Supprime un événement agenda par son eventId.
  Future<bool> removeEventFromCalendar(String eventId) async {
    return removeCreneauFromCalendar(eventId); // même logique
  }

  /// Liste tous les événements Mob-Clinic entre deux dates.
  /// Utile pour afficher un aperçu "ce que l'agenda connaît".
  Future<List<Event>> getEventsInRange(DateTime from, DateTime to) async {
    if (!await hasPermission()) return [];
    final calId = await _getOrCreateCalendar();
    if (calId == null) return [];

    try {
      final params = RetrieveEventsParams(
        startDate: tz.TZDateTime.from(from, tz.local),
        endDate: tz.TZDateTime.from(to, tz.local),
      );
      final result = await _plugin.retrieveEvents(calId, params);
      return result.data ?? [];
    } catch (e) {
      debugPrint('[CalendarSync] getEventsInRange error: $e');
      return [];
    }
  }

  // ── Helpers privés ────────────────────────────────────────────────────────

  Future<bool> _ensurePermission() async {
    if (await hasPermission()) return true;
    return requestPermission();
  }

  /// Convertit une DateTime + string heure "HH:mm" en TZDateTime.
  tz.TZDateTime _toTZDateTime(DateTime date, String heure) {
    final parts = heure.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return tz.TZDateTime(
      tz.local,
      date.year, date.month, date.day, h, m,
    );
  }

  void _initTimezones() {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Bujumbura'));
    } catch (_) {
      try { tzdata.initializeTimeZones(); } catch (_) {}
    }
  }
}
