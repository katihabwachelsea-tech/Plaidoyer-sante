// lib/services/calendar_sync_service.dart
//
// Synchronise les créneaux du doctor ET les RDV du patient
// avec le calendrier natif du téléphone.
//
// Utilise add_2_calendar qui ouvre l'app calendrier native
// (Google Calendar, Samsung Calendar, etc.) avec l'événement pré-rempli.
//
// Doctor  : ajoute ses créneaux de disponibilité dans l'agenda
// Patient : ajoute son RDV confirmé dans l'agenda avec rappels

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment.dart';

class CalendarSyncService {
  CalendarSyncService._();
  static final CalendarSyncService instance = CalendarSyncService._();

  // ── API publique ───────────────────────────────────────────────────────────

  /// [DOCTOR] Ouvre le calendrier natif pour ajouter un créneau de disponibilité.
  ///
  /// Affiche l'app calendrier avec le créneau pré-rempli — le doctor
  /// confirme l'ajout en appuyant "Enregistrer" dans son app calendrier.
  Future<void> addCreneauToCalendar(Creneau creneau, {String? doctorName}) async {
    try {
      final start = _toDateTime(creneau.date, creneau.heureDebut);
      final end   = _toDateTime(creneau.date, creneau.heureFin);

      final event = Event(
        title: '🏥 Disponibilité Mob-Clinic',
        description: doctorName != null
            ? 'Créneau de disponibilité — Dr. $doctorName'
            : 'Créneau de disponibilité Mob-Clinic',
        location: 'Cabinet',
        startDate: start,
        endDate: end,
        allDay: false,
      );

      await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      debugPrint('[CalendarSync] addCreneauToCalendar error: $e');
    }
  }

  /// [PATIENT] Ouvre le calendrier natif pour ajouter un RDV confirmé.
  ///
  /// Rappels intégrés : 24h avant et 1h avant.
  Future<void> addAppointmentToCalendar({
    required DateTime dateRdv,
    required String doctorName,
    required String serviceName,
    required String motif,
    String? location,
    bool isTeleconsultation = false,
  }) async {
    try {
      final start = dateRdv.toLocal();
      final end   = start.add(const Duration(minutes: 30));

      final description = StringBuffer()
        ..writeln('📋 Motif : $motif')
        ..writeln('🏥 Service : $serviceName')
        ..write(isTeleconsultation ? '💻 Téléconsultation' : '🏢 Présentiel');

      final event = Event(
        title: isTeleconsultation
            ? '💻 Téléconsultation — Dr. $doctorName'
            : '🏥 RDV — Dr. $doctorName',
        description: description.toString(),
        location: isTeleconsultation
            ? (location ?? 'Téléconsultation')
            : 'Cabinet Dr. $doctorName',
        startDate: start,
        endDate: end,
        allDay: false,
        // Rappels natifs : 24h avant et 1h avant
        recurrence: null,
      );

      await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      debugPrint('[CalendarSync] addAppointmentToCalendar error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Convertit une DateTime + string "HH:mm" en DateTime complète.
  DateTime _toDateTime(DateTime date, String heure) {
    final parts = heure.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }
}
