import 'package:cyclesync/domain/cycle_calculator.dart';
import 'package:cyclesync/domain/dates.dart';
import 'package:cyclesync/domain/insights_engine.dart';
import 'package:cyclesync/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

List<Period> history(DateTime first, List<int> cycles, {int length = 5}) {
  final out = <Period>[];
  var start = first;
  out.add(Period(id: 'p0', start: start, end: addDays(start, length - 1)));
  for (var i = 0; i < cycles.length; i++) {
    start = addDays(start, cycles[i]);
    out.add(Period(id: 'p${i + 1}', start: start, end: addDays(start, length - 1)));
  }
  return out;
}

Insights run(List<Period> periods, List<DailyLog> logs, DateTime today,
    {int? typical}) {
  final s = CycleCalculator.summarize(
    periods: periods,
    today: today,
    typicalCycleLength: typical,
  );
  return InsightsEngine.analyze(summary: s, logs: logs);
}

void main() {
  final periods = history(d(2026, 6, 1), [28, 30, 27, 29]);
  // starts: 1 Jun, 29 Jun, 29 Jul, 25 Aug, 23 Sep
  final today = d(2026, 10, 10);

  test('cycle day of a log uses the latest earlier start', () {
    final sorted = CycleCalculator.sortedByStart(periods);
    expect(InsightsEngine.cycleDayOf(d(2026, 6, 1), sorted), 1);
    expect(InsightsEngine.cycleDayOf(d(2026, 7, 1), sorted), 3);
    expect(InsightsEngine.cycleDayOf(d(2026, 5, 1), sorted), isNull);
  });

  test('symptoms are grouped by cycle-day range and a pattern is suggested',
      () {
    final logs = [
      for (final p in periods)
        DailyLog(date: addDays(p.start, 1), symptoms: const [Symptom.cramps]),
      DailyLog(date: d(2026, 7, 15), symptoms: const [Symptom.cramps]),
    ];
    final r = run(periods, logs, today);
    expect(r.symptomGrid.rows[Symptom.cramps], [5, 0, 0, 1, 0, 0]);
    final peak = r.symptomGrid.peak(Symptom.cramps)!;
    expect(peak.bucket.label, '1–5');
    expect(peak.count, 5);
    expect(
      r.suggestions.any((s) =>
          s.kind == SuggestionKind.pattern && s.title.startsWith('Cramps')),
      isTrue,
    );
  });

  test('too few logs make no pattern claim', () {
    final logs = [
      DailyLog(date: d(2026, 6, 2), symptoms: const [Symptom.headache]),
      DailyLog(date: d(2026, 6, 3), symptoms: const [Symptom.headache]),
    ];
    final r = run(periods, logs, today);
    expect(r.suggestions.where((s) => s.kind == SuggestionKind.pattern),
        isEmpty);
  });

  test('flow by period day averages logged flow', () {
    final logs = [
      DailyLog(date: d(2026, 6, 1), flow: FlowLevel.medium),
      DailyLog(date: d(2026, 6, 2), flow: FlowLevel.heavy),
      DailyLog(date: d(2026, 6, 29), flow: FlowLevel.light),
      DailyLog(date: d(2026, 6, 30), flow: FlowLevel.heavy),
    ];
    final r = run(periods, logs, today);
    expect(r.flowByPeriodDay, [2.5, 4.0]);
    expect(
      r.suggestions.any((s) => s.title.contains('heaviest flow is usually on day 2')),
      isTrue,
    );
  });

  test('likely window spans shortest to longest recent cycle', () {
    final r = run(periods, const [], today);
    // last start 23 Sep; cycles 27..30
    expect(r.nextWindow!.earliest, d(2026, 10, 20));
    expect(r.nextWindow!.latest, d(2026, 10, 23));
  });

  test('no window when estimate comes from the setting', () {
    final r = run(history(d(2026, 9, 1), [28]), const [], today, typical: 28);
    expect(r.nextWindow, isNull);
  });

  test('health notes for long cycles and long periods', () {
    final long = history(d(2025, 1, 1), [40, 42, 41], length: 9);
    final r = run(long, const [], d(2025, 5, 20));
    final titles = r.suggestions
        .where((s) => s.kind == SuggestionKind.health)
        .map((s) => s.title)
        .toList();
    expect(titles.any((t) => t.contains('41 days')), isTrue);
    expect(titles.any((t) => t.contains('more than 7 days')), isTrue);
    // Health notes come first.
    expect(r.suggestions.first.kind, SuggestionKind.health);
  });

  test('no health notes for typical cycles', () {
    final r = run(periods, const [], today);
    expect(r.suggestions.where((s) => s.kind == SuggestionKind.health), isEmpty);
  });

  test('logging streak and last-30 count', () {
    final logs = [
      for (var i = 0; i < 5; i++) DailyLog(date: addDays(today, -i)),
      DailyLog(date: addDays(today, -10)),
    ];
    final r = run(periods, logs, today);
    expect(r.loggingStreak, 5);
    expect(r.loggedDaysLast30, 6);
  });

  test('suggests adding end dates for open old periods', () {
    final ps = [
      Period(id: 'a', start: d(2026, 8, 1)),
      Period(id: 'b', start: d(2026, 8, 29), end: d(2026, 9, 2)),
    ];
    final r = run(ps, const [], today);
    expect(r.periodsWithoutEnd, 1);
    expect(r.suggestions.any((s) => s.title.startsWith('Add end dates')), isTrue);
  });
}
