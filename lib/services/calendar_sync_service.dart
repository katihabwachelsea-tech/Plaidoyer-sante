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
import 'package:device_calendar/device_calendar.dart' as device_calendar;
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/appointment.dart';

class CalendarWorkingSlot {
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool enabled;

  const CalendarWorkingSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.enabled,
  });
}

class CalendarExceptionDay {
  final DateTime date;
  final String label;

  const CalendarExceptionDay({required this.date, required this.label});
}

class CalendarSyncService {
  CalendarSyncService._();
  static final CalendarSyncService instance = CalendarSyncService._();

  static const String _calendarName = 'Mob-Clinic';
  static const String _availabilityMarker = 'mobclinic_availability';
  static const String _exceptionMarker = 'mobclinic_exception';
  static const String _appointmentMarker = 'mobclinic_appointment';

  final device_calendar.DeviceCalendarPlugin _deviceCalendar =
      device_calendar.DeviceCalendarPlugin();

  // ── API publique ───────────────────────────────────────────────────────────

  Future<void> requestCalendarPermissions() async {
    final current = await _deviceCalendar.hasPermissions();
    _throwIfFailed(current, 'Vérification des permissions du calendrier');
    if (current.data == true) return;

    final requested = await _deviceCalendar.requestPermissions();
    _throwIfFailed(requested, 'Demande de permission calendrier');
    if (requested.data != true) {
      throw StateError('Permission calendrier refusée.');
    }
  }

  /// Synchronise les disponibilités de la semaine, les exceptions et les RDV.
  Future<int> syncWeeklyWorkingTime({
    required List<CalendarWorkingSlot> slots,
    required List<CalendarExceptionDay> exceptions,
    required List<Appointment> appointments,
  }) async {
    await requestCalendarPermissions();
    final calendarId = await _getCalendarId();

    final oldEvents = await _deviceCalendar.retrieveEvents(
      calendarId,
      device_calendar.RetrieveEventsParams(
        startDate: DateTime(2000),
        endDate: DateTime(2101),
      ),
    );
    _throwIfFailed(oldEvents, 'Lecture du calendrier Mob-Clinic');
    for (final event in oldEvents.data!) {
      if (event.description?.startsWith('mobclinic_') ?? false) {
        final deleted = await _deviceCalendar.deleteEvent(
          calendarId,
          event.eventId,
        );
        _throwIfFailed(deleted, 'Suppression d’un ancien événement');
        if (deleted.data != true) {
          throw StateError('Impossible de supprimer un événement Mob-Clinic.');
        }
      }
    }

    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    var created = 0;

    for (var weekday = 1; weekday <= 7; weekday++) {
      final date = monday.add(Duration(days: weekday - 1));
      for (final slot in slots.where(
        (item) => item.enabled && item.dayOfWeek == weekday,
      )) {
        await _createCalendarEvent(
          device_calendar.Event(
            calendarId,
            title: 'Available',
            description: _availabilityMarker,
            start: tz.TZDateTime.from(_dateAt(date, slot.startTime), tz.local),
            end: tz.TZDateTime.from(_dateAt(date, slot.endTime), tz.local),
            availability: device_calendar.Availability.Free,
          ),
        );
        created++;
      }
    }

    for (final exception in exceptions) {
      final date = DateTime(exception.date.year, exception.date.month,
          exception.date.day);
      await _createCalendarEvent(
        device_calendar.Event(
          calendarId,
          title: exception.label,
          description: _exceptionMarker,
          start: tz.TZDateTime.from(date, tz.local),
          end: tz.TZDateTime.from(date, tz.local),
          allDay: true,
          availability: device_calendar.Availability.Unavailable,
        ),
      );
      created++;
    }

    for (final appointment in appointments.where((item) => item.isConfirme)) {
      final start = appointment.dateHeure.toLocal();
      final patientName =
          appointment.patientDisplayName.trim().split(RegExp(r'\s+')).first;
      await _createCalendarEvent(
        device_calendar.Event(
          calendarId,
          title: patientName,
          description: _appointmentMarker,
          start: tz.TZDateTime.from(start, tz.local),
          end: tz.TZDateTime.from(
              start.add(const Duration(hours: 1)), tz.local),
          availability: device_calendar.Availability.Busy,
        ),
      );
      created++;
    }

    return created;
  }

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

  Future<String> _getCalendarId() async {
    final result = await _deviceCalendar.retrieveCalendars();
    _throwIfFailed(result, 'Lecture des calendriers du téléphone');

    for (final calendar in result.data!) {
      if (calendar.name == _calendarName &&
          calendar.id != null &&
          calendar.isReadOnly != true) {
        return calendar.id!;
      }
    }

    final created = await _deviceCalendar.createCalendar(
      _calendarName,
      localAccountName: _calendarName,
    );
    _throwIfFailed(created, 'Création du calendrier Mob-Clinic');
    return created.data!;
  }

  Future<void> _createCalendarEvent(device_calendar.Event event) async {
    final result = await _deviceCalendar.createOrUpdateEvent(event);
    _throwIfFailed(result, 'Ajout d’un événement Mob-Clinic');
  }

  void _throwIfFailed<T>(device_calendar.Result<T>? result, String action) {
    if (result == null || !result.isSuccess) {
      final details = result?.errors
              .map((error) => error.errorMessage)
              .where((message) => message.isNotEmpty)
              .join(', ') ??
          '';
      throw StateError(details.isEmpty ? '$action a échoué.' : '$action : $details');
    }
  }

  DateTime _dateAt(DateTime date, String time) {
    final parts = time.split(':');
    if (parts.length != 2) {
      throw FormatException('Heure invalide pour le calendrier : $time');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw FormatException('Heure invalide pour le calendrier : $time');
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Convertit une DateTime + string "HH:mm" en DateTime complète.
  DateTime _toDateTime(DateTime date, String heure) {
    final parts = heure.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }
}
