import 'dart:math' as math;

import 'cycle_calculator.dart';
import 'dates.dart';
import 'models.dart';

/// Cycle-day ranges used to group logs. Deliberately plain day ranges,
/// not named "phases", so nothing implies ovulation is known.
class DayBucket {
  const DayBucket(this.label, this.from, this.to);
  final String label;
  final int from;
  final int? to; // null = and later

  bool contains(int day) => day >= from && (to == null || day <= to!);
}

const dayBuckets = <DayBucket>[
  DayBucket('1–5', 1, 5),
  DayBucket('6–10', 6, 10),
  DayBucket('11–15', 11, 15),
  DayBucket('16–20', 16, 20),
  DayBucket('21–25', 21, 25),
  DayBucket('26+', 26, null),
];

/// Counts per item (symptom or mood) per cycle-day bucket.
class PatternGrid<T> {
  const PatternGrid(this.rows);

  /// item -> counts per bucket (same order as [dayBuckets]).
  final Map<T, List<int>> rows;

  int get maxCount =>
      rows.values.expand((r) => r).fold(0, (a, b) => math.max(a, b));

  int total(T item) => (rows[item] ?? const []).fold(0, (a, b) => a + b);

  /// Bucket where [item] was logged most, with its share of that item's logs.
  ({DayBucket bucket, int count, int total})? peak(T item) {
    final r = rows[item];
    if (r == null) return null;
    final t = total(item);
    if (t == 0) return null;
    var best = 0;
    for (var i = 1; i < r.length; i++) {
      if (r[i] > r[best]) best = i;
    }
    return (bucket: dayBuckets[best], count: r[best], total: t);
  }
}

enum SuggestionKind { pattern, planning, logging, health }

class Suggestion {
  const Suggestion(this.kind, this.title, this.body);
  final SuggestionKind kind;
  final String title;
  final String body;
}

class Insights {
  const Insights({
    required this.symptomGrid,
    required this.moodGrid,
    required this.flowByPeriodDay,
    required this.loggedDaysLast30,
    required this.loggingStreak,
    required this.periodsWithoutEnd,
    required this.suggestions,
    this.nextWindow,
  });

  final PatternGrid<Symptom> symptomGrid;
  final PatternGrid<Mood> moodGrid;

  /// Average flow (0 none … 4 heavy) for period day 1, 2, … (up to 8).
  final List<double?> flowByPeriodDay;

  /// Likely range for the next period, from the shortest and longest of the
  /// recent cycles. Null without enough history.
  final ({DateTime earliest, DateTime latest})? nextWindow;

  final int loggedDaysLast30;
  final int loggingStreak;
  final int periodsWithoutEnd;
  final List<Suggestion> suggestions;
}

/// Turns the user's own records into patterns and gentle, non-medical
/// suggestions. Pure and deterministic, so it can be unit-tested.
class InsightsEngine {
  const InsightsEngine._();

  static const int minLogsForPattern = 3;

  /// Cycle day for [date]: days since the latest period start on or before it.
  /// Null when there is no such start or it is implausibly long ago.
  static int? cycleDayOf(DateTime date, List<Period> oldestFirst) {
    Period? start;
    for (final p in oldestFirst) {
      if (p.start.isAfter(date)) break;
      start = p;
    }
    if (start == null) return null;
    final d = daysBetween(start.start, date) + 1;
    return d > CycleCalculator.maxValidCycle ? null : d;
  }

  static int _flowScore(FlowLevel f) => switch (f) {
        FlowLevel.none => 0,
        FlowLevel.spotting => 1,
        FlowLevel.light => 2,
        FlowLevel.medium => 3,
        FlowLevel.heavy => 4,
      };

  static Insights analyze({
    required CycleSummary summary,
    required List<DailyLog> logs,
  }) {
    final today = summary.today;
    final oldestFirst = CycleCalculator.sortedByStart(summary.periods);

    // ---- Patterns by cycle day ----
    final symptomRows = <Symptom, List<int>>{};
    final moodRows = <Mood, List<int>>{};
    for (final log in logs) {
      final day = cycleDayOf(log.date, oldestFirst);
      if (day == null) continue;
      final b = dayBuckets.indexWhere((x) => x.contains(day));
      for (final s in log.symptoms) {
        (symptomRows[s] ??= List.filled(dayBuckets.length, 0))[b]++;
      }
      for (final m in log.moods) {
        (moodRows[m] ??= List.filled(dayBuckets.length, 0))[b]++;
      }
    }

    // ---- Flow by period day ----
    final sums = List<int>.filled(8, 0);
    final counts = List<int>.filled(8, 0);
    final logByDate = {for (final l in logs) l.date: l};
    for (final p in oldestFirst) {
      final end = p.effectiveEnd(today);
      for (var i = 0; i < 8; i++) {
        final d = addDays(p.start, i);
        if (d.isAfter(end)) break;
        final l = logByDate[d];
        if (l == null) continue;
        sums[i] += _flowScore(l.flow);
        counts[i]++;
      }
    }
    final flowByDay = [
      for (var i = 0; i < 8; i++) counts[i] == 0 ? null : sums[i] / counts[i],
    ];
    while (flowByDay.isNotEmpty && flowByDay.last == null) {
      flowByDay.removeLast();
    }

    // ---- Next period likely window ----
    ({DateTime earliest, DateTime latest})? window;
    final st = summary.stats;
    if (summary.lastPeriod != null &&
        summary.cycleSource == EstimateSource.history &&
        st.shortestCycle != null &&
        st.longestCycle != null) {
      window = (
        earliest: addDays(summary.lastPeriod!.start, st.shortestCycle!),
        latest: addDays(summary.lastPeriod!.start, st.longestCycle!),
      );
    }

    // ---- Logging consistency ----
    final logged = logByDate.keys.toSet();
    var last30 = 0;
    for (var i = 0; i < 30; i++) {
      if (logged.contains(addDays(today, -i))) last30++;
    }
    var streak = 0;
    var cursor = logged.contains(today) ? today : addDays(today, -1);
    while (logged.contains(cursor)) {
      streak++;
      cursor = addDays(cursor, -1);
    }
    final withoutEnd = summary.periods
        .where((p) => p.end == null && !p.isOngoingOn(today))
        .length;

    final symptomGrid = PatternGrid<Symptom>(symptomRows);
    final moodGrid = PatternGrid<Mood>(moodRows);

    return Insights(
      symptomGrid: symptomGrid,
      moodGrid: moodGrid,
      flowByPeriodDay: flowByDay,
      nextWindow: window,
      loggedDaysLast30: last30,
      loggingStreak: streak,
      periodsWithoutEnd: withoutEnd,
      suggestions: _suggest(
        summary: summary,
        logs: logs,
        symptomGrid: symptomGrid,
        moodGrid: moodGrid,
        flowByDay: flowByDay,
        window: window,
        loggedLast30: last30,
        withoutEnd: withoutEnd,
      ),
    );
  }

  static String _days(DayBucket b) =>
      b.to == null ? 'cycle day ${b.from} onwards' : 'cycle days ${b.label}';

  static List<Suggestion> _suggest({
    required CycleSummary summary,
    required List<DailyLog> logs,
    required PatternGrid<Symptom> symptomGrid,
    required PatternGrid<Mood> moodGrid,
    required List<double?> flowByDay,
    required ({DateTime earliest, DateTime latest})? window,
    required int loggedLast30,
    required int withoutEnd,
  }) {
    final out = <Suggestion>[];
    final st = summary.stats;
    final today = summary.today;

    // --- Health: commonly cited reasons to talk to a professional. ---
    final avg = st.averageCycle;
    if (avg != null && (avg < 21 || avg > 35)) {
      out.add(Suggestion(
        SuggestionKind.health,
        'Your typical cycle is ${avg.round()} days',
        'Cycles that are usually shorter than 21 or longer than 35 days are '
            'worth mentioning to a healthcare professional, especially if this '
            'is new for you.',
      ));
    }
    final avgPeriod = st.averagePeriod;
    if (avgPeriod != null && avgPeriod > 7) {
      out.add(const Suggestion(
        SuggestionKind.health,
        'Your periods often last more than 7 days',
        'Periods that regularly last longer than 7 days are worth discussing '
            'with a healthcare professional.',
      ));
    }
    final heavyDays = logs.where((l) => l.flow == FlowLevel.heavy).length;
    final bleedDays = logs.where((l) => l.flow.isBleeding).length;
    if (bleedDays >= 6 && heavyDays / bleedDays >= 0.5) {
      out.add(const Suggestion(
        SuggestionKind.health,
        'You often log heavy flow',
        'If heavy bleeding means changing protection every 1–2 hours, passing '
            'large clots, or feeling tired or dizzy, please speak to a '
            'healthcare professional.',
      ));
    }
    final variation = st.variation;
    if (variation != null && variation > 7) {
      out.add(Suggestion(
        SuggestionKind.health,
        'Your cycle length varies by $variation days',
        'Some variation is common, so estimates are given as a range. Stress, '
            'illness, travel and other changes can affect your cycle. If the '
            'variation is new or worries you, a healthcare professional can help.',
      ));
    }
    final daysUntil = summary.daysUntilNext;
    if (daysUntil != null && daysUntil < -7 && summary.ongoingPeriod == null) {
      out.add(Suggestion(
        SuggestionKind.health,
        'Your period is later than estimated',
        'The estimated start was ${-daysUntil} days ago. Cycles can shift for '
            'many reasons. If you are concerned, speak to a healthcare '
            'professional. Log your period when it starts to update estimates.',
      ));
    }

    // --- Patterns from symptoms and moods. ---
    for (final s in Symptom.values) {
      if (s == Symptom.other) continue;
      final p = symptomGrid.peak(s);
      if (p == null || p.total < minLogsForPattern) continue;
      if (p.count / p.total < 0.5) continue;
      out.add(Suggestion(
        SuggestionKind.pattern,
        '${s.label} tends to show up on ${_days(p.bucket)}',
        '${p.count} of your ${p.total} ${s.label.toLowerCase()} logs were on '
            '${_days(p.bucket)}.${_planTip(s, p.bucket, summary)}',
      ));
      if (out.where((x) => x.kind == SuggestionKind.pattern).length >= 3) break;
    }
    for (final m in const [Mood.lowEnergy, Mood.sad, Mood.anxious, Mood.irritable]) {
      final p = moodGrid.peak(m);
      if (p == null || p.total < minLogsForPattern) continue;
      if (p.count / p.total < 0.5) continue;
      out.add(Suggestion(
        SuggestionKind.pattern,
        'Feeling ${m.label.toLowerCase()} often on ${_days(p.bucket)}',
        'You logged "${m.label.toLowerCase()}" ${p.count} times on '
            '${_days(p.bucket)}. Knowing this can help you plan lighter days '
            'and extra rest. If low mood is affecting daily life, consider '
            'talking to someone you trust or a professional.',
      ));
      break;
    }

    // --- Planning ahead. ---
    if (window != null && window.latest.isAfter(today)) {
      final span = daysBetween(window.earliest, window.latest);
      out.add(Suggestion(
        SuggestionKind.planning,
        'Next period likely within a $span-day window',
        span == 0
            ? 'Your recent cycles have been the same length.'
            : 'Based on your shortest and longest recent cycles. Keep supplies '
                'with you a few days before the earliest date.',
      ));
    }
    if (flowByDay.length >= 2) {
      var peakDay = 0;
      for (var i = 1; i < flowByDay.length; i++) {
        if ((flowByDay[i] ?? 0) > (flowByDay[peakDay] ?? 0)) peakDay = i;
      }
      if ((flowByDay[peakDay] ?? 0) >= 2.5) {
        out.add(Suggestion(
          SuggestionKind.planning,
          'Your heaviest flow is usually on day ${peakDay + 1}',
          'Plan extra supplies and breaks for period day ${peakDay + 1}.',
        ));
      }
    }

    // --- Better data. ---
    if (withoutEnd > 0) {
      out.add(Suggestion(
        SuggestionKind.logging,
        'Add end dates to $withoutEnd period${withoutEnd == 1 ? '' : 's'}',
        'End dates let CycleSync show your period length and spot changes.',
      ));
    }
    if (summary.periods.length < 4) {
      out.add(const Suggestion(
        SuggestionKind.logging,
        'Add past periods for better estimates',
        'Estimates use your own history after 3 complete cycles. Adding '
            'earlier periods from memory or another app helps.',
      ));
    } else if (loggedLast30 < 8) {
      out.add(Suggestion(
        SuggestionKind.logging,
        'You logged $loggedLast30 of the last 30 days',
        'Quick daily check-ins (even "no symptoms") make patterns clearer. '
            'A daily reminder can help.',
      ));
    }

    // Already in order: health, patterns, planning, logging.
    return out;
  }

  static String _planTip(Symptom s, DayBucket b, CycleSummary summary) {
    if (b.from != 1 || summary.nextPeriodStart == null) return '';
    final days = summary.daysUntilNext!;
    if (days < 0 || days > 10) return '';
    final general = switch (s) {
      Symptom.cramps =>
        ' Your next period is estimated in $days days, so you could plan '
            'rest, warmth or the pain relief that usually works for you.',
      Symptom.headache || Symptom.fatigue =>
        ' Your next period is estimated in $days days; extra water, sleep '
            'and lighter plans may help.',
      _ => ' Your next period is estimated in $days days.',
    };
    return general;
  }
}
