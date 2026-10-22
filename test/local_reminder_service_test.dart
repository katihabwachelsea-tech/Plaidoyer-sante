import 'package:examen/services/local_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalReminderService.doctorReminderPlan', () {
    final now = DateTime(2026, 10, 18, 10);

    test('plans 24 h, 1 h, 15 min and post-appointment reminders', () {
      final plan = LocalReminderService.doctorReminderPlan(
        dateRdv: DateTime(2026, 10, 20, 12),
        patientName: 'Patient',
        now: now,
        testMode: false,
      );

      expect(plan.map((reminder) => reminder.slot), [20, 21, 23, 24]);
      expect(plan.map((reminder) => reminder.when), [
        DateTime(2026, 10, 19, 12),
        DateTime(2026, 10, 20, 11),
        DateTime(2026, 10, 20, 11, 45),
        DateTime(2026, 10, 20, 12, 30),
      ]);
    });

    test('omits reminders whose scheduled time has passed', () {
      final plan = LocalReminderService.doctorReminderPlan(
        dateRdv: DateTime(2026, 10, 18, 10, 10),
        patientName: 'Patient',
        now: now,
        testMode: false,
      );

      expect(plan.map((reminder) => reminder.slot), [24]);
      expect(plan.single.when, DateTime(2026, 10, 18, 10, 40));
    });

    test('uses short delays only when test mode is enabled', () {
      final plan = LocalReminderService.doctorReminderPlan(
        dateRdv: DateTime(2026, 10, 20, 12),
        patientName: 'Patient',
        now: now,
        testMode: true,
      );

      expect(plan.map((reminder) => reminder.slot), [20, 21, 23, 24]);
      expect(plan.map((reminder) => reminder.when.difference(now).inSeconds), [
        30,
        20,
        10,
        40,
      ]);
    });

    test('does not schedule compressed reminders for past appointments', () {
      final plan = LocalReminderService.doctorReminderPlan(
        dateRdv: DateTime(2026, 10, 18, 9),
        patientName: 'Patient',
        now: now,
        testMode: true,
      );

      expect(plan, isEmpty);
    });
  });
}
