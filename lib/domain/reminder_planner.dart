import 'cycle_calculator.dart';
import 'dates.dart';
import 'models.dart';

enum ReminderKind { period, fertile, daily }

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.repeatsDaily = false,
  });

  final int id;
  final ReminderKind kind;

  /// Local wall-clock time on this device.
  final DateTime at;
  final String title;
  final String body;
  final bool repeatsDaily;
}

/// Decides which reminders to schedule. Pure, so it can be unit-tested.
class ReminderPlanner {
  const ReminderPlanner._();

  static const neutralTitle = 'CycleSync';
  static const neutralBody = 'You have a CycleSync reminder';
  static const int morningHour = 9;

  static List<PlannedReminder> plan({
    required ReminderPrefs prefs,
    required CycleSummary summary,
    required DateTime now,
  }) {
    final out = <PlannedReminder>[];
    String body(String detail) => prefs.neutralText ? neutralBody : detail;

    final next = summary.nextPeriodStart;
    if (prefs.periodReminderEnabled && next != null) {
      final day = addDays(next, -prefs.reminderDaysBefore);
      final at = DateTime(day.year, day.month, day.day, morningHour);
      if (at.isAfter(now)) {
        final n = prefs.reminderDaysBefore;
        out.add(PlannedReminder(
          id: 1,
          kind: ReminderKind.period,
          at: at,
          title: neutralTitle,
          body: body(
            'Your period may start in about $n day${n == 1 ? '' : 's'} '
            '(estimate).',
          ),
        ));
      }
    }

    final window = summary.upcomingFertileWindow;
    if (prefs.fertileReminderEnabled && window != null) {
      final d = window.start;
      final at = DateTime(d.year, d.month, d.day, morningHour);
      if (at.isAfter(now)) {
        out.add(PlannedReminder(
          id: 2,
          kind: ReminderKind.fertile,
          at: at,
          title: neutralTitle,
          body: body('Your estimated fertile window starts today.'),
        ));
      }
    }

    if (prefs.dailyReminderEnabled) {
      var at = DateTime(
          now.year, now.month, now.day, prefs.dailyHour, prefs.dailyMinute);
      if (!at.isAfter(now)) {
        at = DateTime(now.year, now.month, now.day + 1, prefs.dailyHour,
            prefs.dailyMinute);
      }
      out.add(PlannedReminder(
        id: 3,
        kind: ReminderKind.daily,
        at: at,
        title: neutralTitle,
        body: body('Time for your daily check-in.'),
        repeatsDaily: true,
      ));
    }
    return out;
  }

  /// Reminders shown inside the app (used on the web, where the app can't
  /// notify while closed). Returns short messages.
  static List<String> inAppNotices({
    required ReminderPrefs prefs,
    required CycleSummary summary,
    required bool loggedToday,
    required DateTime now,
  }) {
    final notices = <String>[];
    final days = summary.daysUntilNext;
    if (prefs.periodReminderEnabled &&
        days != null &&
        days >= 0 &&
        days <= prefs.reminderDaysBefore &&
        summary.ongoingPeriod == null) {
      notices.add(days == 0
          ? 'Your period may start today (estimate).'
          : 'Your period may start in about $days day${days == 1 ? '' : 's'} '
              '(estimate).');
    }
    final window = summary.upcomingFertileWindow;
    if (prefs.fertileReminderEnabled &&
        window != null &&
        sameDate(window.start, summary.today)) {
      notices.add('Your estimated fertile window starts today.');
    }
    if (prefs.dailyReminderEnabled && !loggedToday) {
      final due = DateTime(
          now.year, now.month, now.day, prefs.dailyHour, prefs.dailyMinute);
      if (!now.isBefore(due)) notices.add("You haven't checked in today.");
    }
    return notices;
  }
}
