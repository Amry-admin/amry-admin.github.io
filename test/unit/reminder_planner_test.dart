import 'package:cyclesync/domain/cycle_calculator.dart';
import 'package:cyclesync/domain/models.dart';
import 'package:cyclesync/domain/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.utc(2026, 11, 8);
  final summary = CycleCalculator.summarize(
    periods: [
      Period(
          id: 'a',
          start: DateTime.utc(2026, 11, 1),
          end: DateTime.utc(2026, 11, 5)),
    ],
    today: today,
    typicalCycleLength: 28,
    typicalPeriodLength: 5,
    includeFertileWindow: true,
  );
  final now = DateTime(2026, 11, 8, 10, 0);

  test('nothing planned when all reminders are off', () {
    expect(
      ReminderPlanner.plan(
          prefs: const ReminderPrefs(), summary: summary, now: now),
      isEmpty,
    );
  });

  test('period reminder N days before at 09:00, neutral by default', () {
    final plan = ReminderPlanner.plan(
      prefs: const ReminderPrefs(
          periodReminderEnabled: true, reminderDaysBefore: 3),
      summary: summary,
      now: now,
    );
    expect(plan, hasLength(1));
    expect(plan.first.at, DateTime(2026, 11, 26, 9));
    expect(plan.first.body, ReminderPlanner.neutralBody);
  });

  test('detailed text only when neutral text is off', () {
    final plan = ReminderPlanner.plan(
      prefs: const ReminderPrefs(
        periodReminderEnabled: true,
        reminderDaysBefore: 1,
        neutralText: false,
      ),
      summary: summary,
      now: now,
    );
    expect(plan.first.body, contains('1 day'));
  });

  test('daily reminder rolls to tomorrow if the time has passed', () {
    final plan = ReminderPlanner.plan(
      prefs: const ReminderPrefs(
          dailyReminderEnabled: true, dailyHour: 8, dailyMinute: 0),
      summary: summary,
      now: now,
    );
    expect(plan.single.at, DateTime(2026, 11, 9, 8));
    expect(plan.single.repeatsDaily, isTrue);
  });

  test('fertile reminder on the first estimated day', () {
    final plan = ReminderPlanner.plan(
      prefs: const ReminderPrefs(fertileReminderEnabled: true),
      summary: summary,
      now: now,
    );
    expect(plan.single.at, DateTime(2026, 11, 10, 9));
  });

  test('in-app notices', () {
    final soon = CycleCalculator.summarize(
      periods: [
        Period(
            id: 'a',
            start: DateTime.utc(2026, 10, 13),
            end: DateTime.utc(2026, 10, 17)),
      ],
      today: today,
      typicalCycleLength: 28,
    );
    final notices = ReminderPlanner.inAppNotices(
      prefs: const ReminderPrefs(
        periodReminderEnabled: true,
        reminderDaysBefore: 3,
        dailyReminderEnabled: true,
        dailyHour: 9,
      ),
      summary: soon,
      loggedToday: false,
      now: now,
    );
    expect(notices, hasLength(2));
    expect(notices.first, contains('2 days'));
    expect(notices.last, contains("haven't checked in"));
  });
}
