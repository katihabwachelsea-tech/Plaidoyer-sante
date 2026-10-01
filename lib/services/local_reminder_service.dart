// lib/services/local_reminder_service.dart
//
// Rappels locaux intelligents (inspiré Zocdoc) :
//   • J-1 à 18h    — "Votre RDV est demain"
//   • H-2          — "Dans 2 heures"
//   • H-1          — "Dans 1 heure" + action Confirmer présence
//   • H-0h15       — "Dans 15 minutes"
//
// Actions depuis la notification (Android) :
//   • ✅ Je confirme ma présence  → dismiss
//   • ⏰ Snooze 10 min           → replanifie H-10min
//
// Chaque slot utilise un ID déterministe :
//   appointmentId * 10 + index  (index 1=J-1, 2=H-2, 3=H-1, 4=H-15min, 5=snooze)

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class LocalReminderService {
  LocalReminderService._();
  static final LocalReminderService instance = LocalReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // ── Canaux Android ────────────────────────────────────────────────────────
  static const String _channelId   = 'rdv_reminders';
  static const String _channelName = 'Rappels rendez-vous';
  static const String _channelDesc = 'Rappels J-1, H-2, H-1 et 15 min avant RDV';

  // ── Actions Android ───────────────────────────────────────────────────────
  static const String _actionConfirm = 'ACTION_CONFIRM';
  static const String _actionSnooze  = 'ACTION_SNOOZE';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;
    _initTimezones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onAction,
      onDidReceiveBackgroundNotificationResponse: _onActionBackground,
    );

    // Demander permission Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;
  }

  // ── API publique ──────────────────────────────────────────────────────────

  /// Planifie les 4 rappels pour un RDV.
  /// À appeler juste après le paiement côté patient.
  Future<void> scheduleForAppointment({
    required int    appointmentId,
    required DateTime dateRdv,
    required String title,       // ex: "Dr. Dupont"
    required String body,        // ex: "Cardiologie · Ven 26 Sep 09:00"
  }) async {
    await init();
    final local = dateRdv.toLocal();
    final now   = DateTime.now();

    // 1 — J-1 à 18h
    final dayBefore = DateTime(local.year, local.month, local.day - 1, 18, 0);
    if (dayBefore.isAfter(now)) {
      await _schedule(
        id:    appointmentId * 10 + 1,
        when:  dayBefore,
        title: '📅 Rappel demain — $title',
        body:  body,
        withActions: false,
      );
    }

    // 2 — H-2
    final twoHours = local.subtract(const Duration(hours: 2));
    if (twoHours.isAfter(now)) {
      await _schedule(
        id:    appointmentId * 10 + 2,
        when:  twoHours,
        title: '⏰ Dans 2 heures — $title',
        body:  body,
        withActions: false,
      );
    }

    // 3 — H-1 (avec boutons Confirmer + Snooze)
    final oneHour = local.subtract(const Duration(hours: 1));
    if (oneHour.isAfter(now)) {
      await _schedule(
        id:    appointmentId * 10 + 3,
        when:  oneHour,
        title: '🏥 Dans 1 heure — $title',
        body:  body,
        withActions: true,
        appointmentId: appointmentId,
        rdvDateTime: local,
        rdvTitle: title,
        rdvBody: body,
      );
    }

    // 4 — H-15min
    final fifteenMin = local.subtract(const Duration(minutes: 15));
    if (fifteenMin.isAfter(now)) {
      await _schedule(
        id:    appointmentId * 10 + 4,
        when:  fifteenMin,
        title: '🚨 Dans 15 minutes — $title',
        body:  body,
        withActions: true,
        appointmentId: appointmentId,
        rdvDateTime: local,
        rdvTitle: title,
        rdvBody: body,
      );
    }
  }

  /// Annule tous les rappels d'un RDV (ex: annulation).
  Future<void> cancelForAppointment(int appointmentId) async {
    await init();
    for (var i = 1; i <= 5; i++) {
      await _plugin.cancel(appointmentId * 10 + i);
    }
  }

  /// Snooze manuel : replanifie une notif dans X minutes.
  Future<void> snooze({
    required int    appointmentId,
    required String title,
    required String body,
    int minutes = 10,
  }) async {
    await init();
    final when = DateTime.now().add(Duration(minutes: minutes));
    await _schedule(
      id:    appointmentId * 10 + 5,
      when:  when,
      title: '⏰ Rappel reporté — $title',
      body:  body,
      withActions: false,
    );
  }

  // ── Scheduling interne ────────────────────────────────────────────────────

  Future<void> _schedule({
    required int      id,
    required DateTime when,
    required String   title,
    required String   body,
    required bool     withActions,
    int?      appointmentId,
    DateTime? rdvDateTime,
    String?   rdvTitle,
    String?   rdvBody,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);

    AndroidNotificationDetails androidDetails;

    if (withActions && appointmentId != null) {
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority:   Priority.high,
        styleInformation: const BigTextStyleInformation(''),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            _actionConfirm,
            '✅ Je confirme ma présence',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            _actionSnooze,
            '⏰ Rappel dans 10 min',
            cancelNotification: true,
          ),
        ],
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority:   Priority.high,
      );
    }

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    // Payload pour le handler de snooze
    final payload = withActions && appointmentId != null
        ? '$appointmentId|${rdvDateTime?.toIso8601String()}|$rdvTitle|$rdvBody'
        : null;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[Reminder] Planifié id=$id à $when');
    } catch (e) {
      // Fallback si exact alarm non autorisée
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (e2) {
        debugPrint('[Reminder] Impossible de planifier id=$id : $e2');
      }
    }
  }

  // ── Handlers d'action ─────────────────────────────────────────────────────

  void _onAction(NotificationResponse response) {
    final actionId = response.actionId;
    final payload  = response.payload;

    if (actionId == _actionSnooze && payload != null) {
      _handleSnooze(payload);
    }
    // _actionConfirm : juste dismiss (cancelNotification: true ci-dessus)
  }

  void _handleSnooze(String payload) {
    try {
      final parts = payload.split('|');
      if (parts.length < 4) return;

      final appointmentId = int.parse(parts[0]);
      final title = parts[2];
      final body  = parts[3];

      snooze(
        appointmentId: appointmentId,
        title: title,
        body:  body,
        minutes: 10,
      );
    } catch (e) {
      debugPrint('[Reminder] Snooze error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _initTimezones() {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Bujumbura'));
    } catch (_) {
      try { tzdata.initializeTimeZones(); } catch (_) {}
    }
  }
}

// Top-level pour le background handler (requis par flutter_local_notifications)
@pragma('vm:entry-point')
void _onActionBackground(NotificationResponse response) {
  if (response.actionId == 'ACTION_SNOOZE' && response.payload != null) {
    LocalReminderService.instance._handleSnooze(response.payload!);
  }
}
