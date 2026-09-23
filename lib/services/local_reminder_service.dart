import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Rappels locaux J-1 et H-2 (sans FCM).
class LocalReminderService {
  LocalReminderService._();
  static final LocalReminderService instance = LocalReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Bujumbura'));
    } catch (_) {
      // Fallback fuseau appareil
      try {
        tzdata.initializeTimeZones();
      } catch (_) {}
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;
  }

  /// Planifie rappel veille (J-1 18h) + 2h avant le RDV.
  Future<void> scheduleForAppointment({
    required int appointmentId,
    required DateTime dateRdv,
    required String title,
    required String body,
  }) async {
    await init();
    final local = dateRdv.toLocal();
    final now = DateTime.now();

    // J-1 à 18h
    final dayBefore = DateTime(local.year, local.month, local.day)
        .subtract(const Duration(days: 1))
        .add(const Duration(hours: 18));
    if (dayBefore.isAfter(now)) {
      await _zoned(
        id: appointmentId * 10 + 1,
        when: dayBefore,
        title: 'Rappel demain — $title',
        body: body,
      );
    }

    // H-2
    final twoHoursBefore = local.subtract(const Duration(hours: 2));
    if (twoHoursBefore.isAfter(now)) {
      await _zoned(
        id: appointmentId * 10 + 2,
        when: twoHoursBefore,
        title: 'Dans 2 heures — $title',
        body: body,
      );
    }
  }

  Future<void> cancelForAppointment(int appointmentId) async {
    await init();
    await _plugin.cancel(appointmentId * 10 + 1);
    await _plugin.cancel(appointmentId * 10 + 2);
  }

  Future<void> _zoned({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rdv_reminders',
          'Rappels rendez-vous',
          channelDescription: 'Rappels locaux J-1 et H-2',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
