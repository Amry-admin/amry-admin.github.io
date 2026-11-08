import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_text.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/cycle_visuals.dart';
import '../../domain/cycle_calculator.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../routing/app_router.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(summaryProvider);
    final logs = ref.watch(logsProvider).value ?? const [];
    final showFertile =
        ref.watch(profileProvider).value?.showFertileWindow ?? false;

    return GradientScaffold(
      title: 'Insights',
      automaticallyImplyLeading: false,
      body: summary.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(onRetry: () => refreshCycleData(ref)),
        data: (s) => PageBody(
          children: [
            Center(
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Overview')),
                  ButtonSegment(value: 1, label: Text('Trends')),
                  ButtonSegment(value: 2, label: Text('How it works')),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
            ),
            const SizedBox(height: 16),
            ...switch (_tab) {
              0 => _overview(context, s, logs, showFertile),
              1 => _trends(context, s, logs),
              _ => _howItWorks(context),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _overview(BuildContext context, CycleSummary s,
      List<DailyLog> logs, bool showFertile) {
    final avg = s.stats.averageCycle?.round();
    final avgPeriod = s.stats.averagePeriod?.round();
    final variation = s.stats.variation;
    return [
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your cycle overview', style: context.text.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                _CycleRing(
                  cycle: avg,
                  period: avgPeriod,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendLine(
                        color: context.cycle.period,
                        title: 'Period',
                        value: avgPeriod == null ? 'Not enough data' : '$avgPeriod days',
                      ),
                      const SizedBox(height: 12),
                      if (showFertile)
                        _LegendLine(
                          color: context.cycle.fertile,
                          title: 'Fertile window',
                          value: s.cycleLength == null
                              ? 'Needs a cycle estimate'
                              : '7 days (estimate)',
                        )
                      else
                        _LegendLine(
                          color: context.colors.secondary,
                          title: 'Cycles logged',
                          value: '${s.stats.validIntervals.length}',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (variation != null)
        NoticeCard(
          icon: Icons.lightbulb_outline,
          tint: context.cycle.softPinkCard,
          text: variation <= 7
              ? 'Your recent cycle lengths have stayed within $variation days of each other.'
              : 'Your recent cycle lengths varied by $variation days. Some variation is common; '
                  'speak to a healthcare professional if you are concerned.',
        )
      else
        NoticeCard(
          icon: Icons.lightbulb_outline,
          tint: context.cycle.softPinkCard,
          text: 'Log at least 3 cycles to see averages and patterns.',
        ),
      if (s.stats.excludedIntervals > 0) ...[
        const SizedBox(height: 10),
        NoticeCard(
          icon: Icons.info_outline,
          tint: context.cycle.softLavenderCard,
          text: '${s.stats.excludedIntervals} unusual gap'
              '${s.stats.excludedIntervals == 1 ? ' was' : 's were'} left out '
              'of estimates (shorter than 15 or longer than 60 days).',
        ),
      ],
      const SectionTitle('Common symptoms (last 90 days)'),
      _FrequencyCard(
        items: _countRecent<Symptom>(s.today, logs, (l) => l.symptoms)
            .map((e) => (symptomIcon(e.$1), e.$1.label, e.$2))
            .toList(),
        empty: 'No symptoms logged in the last 90 days.',
      ),
      const SectionTitle('Mood (last 90 days)'),
      _FrequencyCard(
        items: _countRecent<Mood>(s.today, logs, (l) => l.moods)
            .map((e) => (moodIcon(e.$1), e.$1.label, e.$2))
            .toList(),
        empty: 'No moods logged in the last 90 days.',
        color: context.colors.secondary,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => context.push(AppRoutes.history),
        icon: const Icon(Icons.history),
        label: const Text('View Period History'),
      ),
    ];
  }

  List<(T, int)> _countRecent<T>(
      DateTime today, List<DailyLog> logs, List<T> Function(DailyLog) pick) {
    final since = addDays(today, -89);
    final counts = <T, int>{};
    for (final l in logs) {
      if (l.date.isBefore(since) || l.date.isAfter(today)) continue;
      for (final v in pick(l)) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(6).toList();
  }

  List<Widget> _trends(
      BuildContext context, CycleSummary s, List<DailyLog> logs) {
    // Pair each interval with the month its cycle started.
    final oldestFirst = CycleCalculator.sortedByStart(s.periods);
    final points = <(DateTime, int)>[];
    for (var i = 1; i < oldestFirst.length; i++) {
      final len = daysBetween(oldestFirst[i - 1].start, oldestFirst[i].start);
      if (CycleCalculator.isValidInterval(len)) {
        points.add((oldestFirst[i - 1].start, len));
      }
    }
    final recent =
        points.length > 8 ? points.sublist(points.length - 8) : points;
    final durations = [
      for (final p in oldestFirst)
        if (p.durationDays != null) (p.start, p.durationDays!),
    ];
    final recentDur = durations.length > 8
        ? durations.sublist(durations.length - 8)
        : durations;

    return [
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cycle length trend', style: context.text.titleMedium),
            const SizedBox(height: 4),
            Text('Days from one period start to the next',
                style: context.text.bodySmall
                    ?.copyWith(color: context.cycle.muted)),
            const SizedBox(height: 16),
            if (recent.length < 2)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Log at least 3 periods to see a trend.')),
              )
            else
              _TrendChart(points: recent),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Period length', style: context.text.titleMedium),
            const SizedBox(height: 12),
            if (recentDur.isEmpty)
              const Text('Add end dates to your periods to see their length.')
            else
              for (final d in recentDur.reversed)
                _BarRow(
                  label: DateFormat('d MMM yy').format(d.$1),
                  value: d.$2,
                  max: 10,
                  suffix: 'days',
                  color: context.cycle.period,
                ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Charts use only what you have logged. Unusual gaps are left out.',
        style: context.text.bodySmall?.copyWith(color: context.cycle.muted),
      ),
    ];
  }

  List<Widget> _howItWorks(BuildContext context) {
    return [
      for (final (title, body) in AppText.howEstimatesWork) ...[
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: 6),
              Text(body, style: context.text.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
      const NoticeCard(
        icon: Icons.health_and_safety_outlined,
        text: AppText.healthDisclaimer,
      ),
    ];
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.title,
    required this.value,
  });

  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.bodyMedium),
              Text(value, style: context.text.titleSmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Donut showing the share of an average cycle spent on the period.
class _CycleRing extends StatelessWidget {
  const _CycleRing({required this.cycle, required this.period});

  final int? cycle;
  final int? period;

  @override
  Widget build(BuildContext context) {
    final c = context.cycle;
    return Semantics(
      label: cycle == null
          ? 'Average cycle: not enough data'
          : 'Average cycle: $cycle days',
      excludeSemantics: true,
      child: SizedBox(
        width: 130,
        height: 130,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: (cycle != null && period != null)
                ? (period! / cycle!).clamp(0.0, 1.0)
                : 0,
            track: c.fertileSoft,
            arc: c.period,
            rest: c.fertile.withValues(alpha: 0.55),
            hasData: cycle != null,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cycle == null ? '—' : '$cycle',
                    style: context.text.headlineMedium),
                Text(cycle == null ? 'no average' : 'days (avg)',
                    style: context.text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.track,
    required this.arc,
    required this.rest,
    required this.hasData,
  });

  final double fraction;
  final Color track;
  final Color arc;
  final Color rest;
  final bool hasData;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, p(track));
    if (!hasData) return;
    const startAngle = -math.pi / 2;
    if (fraction > 0) {
      canvas.drawArc(rect, startAngle, 2 * math.pi * fraction, false, p(arc));
    }
    final restStart = startAngle + 2 * math.pi * fraction + 0.18;
    final restSweep = 2 * math.pi * (1 - fraction) - 0.36;
    if (restSweep > 0) canvas.drawArc(rect, restStart, restSweep, false, p(rest));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.hasData != hasData || old.arc != arc;
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<(DateTime, int)> points;

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.$2).toList();
    final lo = (values.reduce(math.min) - 3).clamp(0, 100);
    final hi = values.reduce(math.max) + 3;
    final desc = points
        .map((p) => '${DateFormat('MMM yyyy').format(p.$1)}: ${p.$2} days')
        .join('; ');
    return Semantics(
      label: 'Cycle lengths. $desc',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TrendPainter(
                values: values,
                lo: lo.toDouble(),
                hi: hi.toDouble(),
                line: context.cycle.period,
                fill: context.cycle.periodSoft,
                grid: context.cycle.cardBorder,
                label: context.cycle.muted,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 28),
              for (final p in points)
                Expanded(
                  child: Text(
                    DateFormat('MMM').format(p.$1),
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.cycle.muted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.lo,
    required this.hi,
    required this.line,
    required this.fill,
    required this.grid,
    required this.label,
  });

  final List<int> values;
  final double lo;
  final double hi;
  final Color line;
  final Color fill;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    final w = size.width - left;
    final h = size.height - 8;
    double x(int i) => left + (w / values.length) * (i + 0.5);
    double y(num v) => 4 + h - (v - lo) / (hi - lo) * h;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [lo, (lo + hi) / 2, hi]) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: v.round().toString(),
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y(v) - tp.height / 2));
    }

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    final area = Path.from(path)
      ..lineTo(x(values.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill.withValues(alpha: 0.6));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 5, Paint()..color = line);
      canvas.drawCircle(
          Offset(x(i), y(values[i])), 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values;
}

class _FrequencyCard extends StatelessWidget {
  const _FrequencyCard({
    required this.items,
    required this.empty,
    this.color,
  });

  final List<(IconData, String, int)> items;
  final String empty;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SoftCard(
        child: Text(empty,
            style: context.text.bodyMedium
                ?.copyWith(color: context.cycle.muted)),
      );
    }
    final max = items.map((e) => e.$3).reduce(math.max);
    return SoftCard(
      child: Column(
        children: [
          for (final (icon, label, count) in items)
            _BarRow(
              icon: icon,
              label: label,
              value: count,
              max: max,
              suffix: count == 1 ? 'day' : 'days',
              color: color ?? context.colors.primary,
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.suffix,
    required this.color,
    this.icon,
  });

  final IconData? icon;
  final String label;
  final int value;
  final int max;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value $suffix',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 104,
              child: Text(label,
                  style: context.text.bodyMedium,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : (value / max).clamp(0.0, 1.0),
                  minHeight: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 56,
              child: Text('$value $suffix',
                  textAlign: TextAlign.right, style: context.text.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
