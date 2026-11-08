import 'dates.dart';

/// Longest a period with no end date is treated as running (days).
/// Matches the database overlap guard.
const int openPeriodMaxDays = 14;

class Period {
  const Period({
    required this.id,
    required this.start,
    this.end,
    this.notes,
  });

  final String id;
  final DateTime start;
  final DateTime? end;
  final String? notes;

  /// Inclusive length in days, when the end date is recorded.
  int? get durationDays => end == null ? null : daysBetween(start, end!) + 1;

  /// True when no end date is recorded and the start is recent enough that
  /// the period may still be going.
  bool isOngoingOn(DateTime today) =>
      end == null &&
      !start.isAfter(today) &&
      daysBetween(start, today) < openPeriodMaxDays;

  /// Last day this record covers. Open records run to today, capped.
  DateTime effectiveEnd(DateTime today) {
    if (end != null) return end!;
    final cap = addDays(start, openPeriodMaxDays - 1);
    final runTo = today.isBefore(start) ? start : today;
    return runTo.isAfter(cap) ? cap : runTo;
  }

  bool covers(DateTime day, DateTime today) =>
      !day.isBefore(start) && !day.isAfter(effectiveEnd(today));

  factory Period.fromRow(Map<String, dynamic> row) => Period(
        id: row['id'] as String,
        start: parseDbDate(row['start_date'] as String),
        end: row['end_date'] == null
            ? null
            : parseDbDate(row['end_date'] as String),
        notes: row['notes'] as String?,
      );
}

enum FlowLevel {
  none('none', 'None'),
  spotting('spotting', 'Spotting'),
  light('light', 'Light'),
  medium('medium', 'Medium'),
  heavy('heavy', 'Heavy');

  const FlowLevel(this.db, this.label);
  final String db;
  final String label;

  bool get isBleeding => this == light || this == medium || this == heavy;

  static FlowLevel fromDb(String? v) =>
      FlowLevel.values.firstWhere((f) => f.db == v, orElse: () => FlowLevel.none);
}

enum Symptom {
  cramps('cramps', 'Cramps'),
  headache('headache', 'Headache'),
  bloating('bloating', 'Bloating'),
  acne('acne', 'Acne'),
  breastTenderness('breast_tenderness', 'Tender breasts'),
  fatigue('fatigue', 'Fatigue'),
  nausea('nausea', 'Nausea'),
  backPain('back_pain', 'Back pain'),
  other('other', 'Other');

  const Symptom(this.db, this.label);
  final String db;
  final String label;

  static Symptom? fromDb(String v) {
    for (final s in Symptom.values) {
      if (s.db == v) return s;
    }
    return null;
  }
}

enum Mood {
  happy('happy', 'Happy'),
  calm('calm', 'Calm'),
  neutral('neutral', 'Neutral'),
  anxious('anxious', 'Anxious'),
  sad('sad', 'Sad'),
  irritable('irritable', 'Irritable'),
  lowEnergy('low_energy', 'Low energy'),
  other('other', 'Other');

  const Mood(this.db, this.label);
  final String db;
  final String label;

  static Mood? fromDb(String v) {
    for (final m in Mood.values) {
      if (m.db == v) return m;
    }
    return null;
  }
}

class DailyLog {
  const DailyLog({
    this.id,
    required this.date,
    this.flow = FlowLevel.none,
    this.symptoms = const [],
    this.moods = const [],
    this.notes,
  });

  final String? id;
  final DateTime date;
  final FlowLevel flow;
  final List<Symptom> symptoms;
  final List<Mood> moods;
  final String? notes;

  bool get isEmpty =>
      flow == FlowLevel.none &&
      symptoms.isEmpty &&
      moods.isEmpty &&
      (notes == null || notes!.trim().isEmpty);

  factory DailyLog.fromRow(Map<String, dynamic> row) => DailyLog(
        id: row['id'] as String?,
        date: parseDbDate(row['log_date'] as String),
        flow: FlowLevel.fromDb(row['flow'] as String?),
        symptoms: (row['symptoms'] as List? ?? const [])
            .whereType<String>()
            .map(Symptom.fromDb)
            .whereType<Symptom>()
            .toList(),
        moods: (row['mood'] as List? ?? const [])
            .whereType<String>()
            .map(Mood.fromDb)
            .whereType<Mood>()
            .toList(),
        notes: row['notes'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'log_date': toDbDate(date),
        'flow': flow.db,
        'symptoms': [for (final s in symptoms) s.db],
        'mood': [for (final m in moods) m.db],
        'notes': (notes == null || notes!.trim().isEmpty) ? null : notes!.trim(),
      };
}

class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.typicalCycleLength,
    this.typicalPeriodLength,
    this.timezone,
    this.onboardingCompleted = false,
    this.showFertileWindow = false,
  });

  final String id;
  final String? displayName;
  final int? typicalCycleLength;
  final int? typicalPeriodLength;
  final String? timezone;
  final bool onboardingCompleted;
  final bool showFertileWindow;

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        displayName: row['display_name'] as String?,
        typicalCycleLength: (row['average_cycle_length'] as num?)?.toInt(),
        typicalPeriodLength: (row['average_period_length'] as num?)?.toInt(),
        timezone: row['timezone'] as String?,
        onboardingCompleted: row['onboarding_completed'] as bool? ?? false,
        showFertileWindow: row['show_fertile_window'] as bool? ?? false,
      );
}

class ReminderPrefs {
  const ReminderPrefs({
    this.periodReminderEnabled = false,
    this.reminderDaysBefore = 2,
    this.fertileReminderEnabled = false,
    this.dailyReminderEnabled = false,
    this.dailyHour = 20,
    this.dailyMinute = 0,
    this.neutralText = true,
  });

  final bool periodReminderEnabled;
  final int reminderDaysBefore;
  final bool fertileReminderEnabled;
  final bool dailyReminderEnabled;
  final int dailyHour;
  final int dailyMinute;
  final bool neutralText;

  bool get anyEnabled =>
      periodReminderEnabled || fertileReminderEnabled || dailyReminderEnabled;

  ReminderPrefs copyWith({
    bool? periodReminderEnabled,
    int? reminderDaysBefore,
    bool? fertileReminderEnabled,
    bool? dailyReminderEnabled,
    int? dailyHour,
    int? dailyMinute,
    bool? neutralText,
  }) =>
      ReminderPrefs(
        periodReminderEnabled:
            periodReminderEnabled ?? this.periodReminderEnabled,
        reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
        fertileReminderEnabled:
            fertileReminderEnabled ?? this.fertileReminderEnabled,
        dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
        dailyHour: dailyHour ?? this.dailyHour,
        dailyMinute: dailyMinute ?? this.dailyMinute,
        neutralText: neutralText ?? this.neutralText,
      );

  factory ReminderPrefs.fromRow(Map<String, dynamic> row) {
    final time = row['daily_reminder_time'] as String?; // 'HH:MM:SS'
    var hour = 20;
    var minute = 0;
    if (time != null && time.length >= 5) {
      hour = int.tryParse(time.substring(0, 2)) ?? 20;
      minute = int.tryParse(time.substring(3, 5)) ?? 0;
    }
    return ReminderPrefs(
      periodReminderEnabled: row['period_reminder_enabled'] as bool? ?? false,
      reminderDaysBefore: (row['reminder_days_before'] as num?)?.toInt() ?? 2,
      fertileReminderEnabled: row['fertile_reminder_enabled'] as bool? ?? false,
      dailyReminderEnabled: row['daily_reminder_enabled'] as bool? ?? false,
      dailyHour: hour,
      dailyMinute: minute,
      neutralText: row['neutral_notification_text'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toRow() => {
        'period_reminder_enabled': periodReminderEnabled,
        'reminder_days_before': reminderDaysBefore,
        'fertile_reminder_enabled': fertileReminderEnabled,
        'daily_reminder_enabled': dailyReminderEnabled,
        'daily_reminder_time':
            '${dailyHour.toString().padLeft(2, '0')}:${dailyMinute.toString().padLeft(2, '0')}:00',
        'neutral_notification_text': neutralText,
      };
}
