import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/theme/app_theme.dart';
import '../../domain/insights_engine.dart';

/// Line chart of cycle lengths with the user's own range shaded, their
/// average dashed, and the commonly cited 21–35 day adult range for context.
class CycleRangeChart extends StatelessWidget {
  const CycleRangeChart({super.key, required this.points});

  final List<(DateTime, int)> points;

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.$2).toList();
    final lo = math.min(values.reduce(math.min), 21) - 2;
    final hi = math.max(values.reduce(math.max), 35) + 2;
    final avg = values.reduce((a, b) => a + b) / values.length;
    final c = context.cycle;
    final desc = points
        .map((p) => '${DateFormat('MMM yyyy').format(p.$1)} ${p.$2} days')
        .join(', ');
    return Semantics(
      label: 'Cycle lengths: $desc. Average ${avg.round()} days.',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RangePainter(
                values: values,
                lo: lo.toDouble(),
                hi: hi.toDouble(),
                avg: avg,
                line: c.period,
                yourRange: c.periodSoft,
                typicalRange: c.fertileSoft,
                grid: c.cardBorder,
                label: c.muted,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 30),
              for (final p in points)
                Expanded(
                  child: Text(
                    DateFormat('MMM').format(p.$1),
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: c.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Key(color: c.period, label: 'Your cycles'),
              _Key(color: c.periodSoft, label: 'Your range', square: true),
              _Key(color: c.fertileSoft, label: 'Typical 21–35 days', square: true),
              _Key(color: c.heading, label: 'Your average', dashed: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.color,
    required this.label,
    this.square = false,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool square;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          SizedBox(
            width: 18,
            height: 10,
            child: CustomPaint(painter: _DashPainter(color)),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: square ? BorderRadius.circular(3) : null,
            ),
          ),
        const SizedBox(width: 6),
        Text(label, style: context.text.bodySmall),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height / 2),
          Offset(math.min(x + 3, size.width), size.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

class _RangePainter extends CustomPainter {
  _RangePainter({
    required this.values,
    required this.lo,
    required this.hi,
    required this.avg,
    required this.line,
    required this.yourRange,
    required this.typicalRange,
    required this.grid,
    required this.label,
  });

  final List<int> values;
  final double lo;
  final double hi;
  final double avg;
  final Color line;
  final Color yourRange;
  final Color typicalRange;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    final w = size.width - left;
    final h = size.height - 10;
    double x(int i) => left + (w / values.length) * (i + 0.5);
    double y(num v) => 5 + h - (v - lo) / (hi - lo) * h;

    // Typical adult range (context only).
    canvas.drawRect(
      Rect.fromLTRB(left, y(35), size.width, y(21)),
      Paint()..color = typicalRange.withValues(alpha: 0.6),
    );
    // The user's own range.
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    canvas.drawRect(
      Rect.fromLTRB(left, y(maxV) - 2, size.width, y(minV) + 2),
      Paint()..color = yourRange.withValues(alpha: 0.85),
    );

    // Grid and labels.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [lo + 2, (lo + hi) / 2, hi - 2]) {
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

    // Average (dashed).
    final avgPaint = Paint()
      ..color = label
      ..strokeWidth = 1.5;
    for (double xx = left; xx < size.width; xx += 8) {
      canvas.drawLine(Offset(xx, y(avg)),
          Offset(math.min(xx + 4, size.width), y(avg)), avgPaint);
    }

    // Line + points.
    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final o = Offset(x(i), y(values[i]));
      canvas.drawCircle(o, 5.5, Paint()..color = line);
      canvas.drawCircle(o, 2.5, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: TextSpan(
          text: '${values[i]}',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: line,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - 20));
    }
  }

  @override
  bool shouldRepaint(_RangePainter old) =>
      old.values != values || old.line != line;
}

/// Simple vertical bar chart with labels under each bar and an optional
/// dashed reference line.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    required this.semanticsLabel,
    this.max,
    this.valueLabel,
    this.reference,
    this.height = 150,
  });

  final List<double?> values;
  final List<String> labels;
  final Color color;
  final String semanticsLabel;
  final double? max;
  final String Function(double v)? valueLabel;
  final double? reference;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = max ??
        values.whereType<double>().fold<double>(0, (a, b) => math.max(a, b));
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final v in values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (v != null)
                                  Text(
                                    valueLabel?.call(v) ?? v.round().toString(),
                                    style: context.text.labelSmall?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  height: v == null || top == 0
                                      ? 3
                                      : math.max(
                                          4.0,
                                          (v / top).clamp(0.0, 1.0) *
                                              (constraints.maxHeight - 22),
                                        ),
                                  decoration: BoxDecoration(
                                    color: v == null
                                        ? context.cycle.cardBorder
                                        : color,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (reference != null && top > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: (reference! / top).clamp(0.0, 1.0) *
                          (constraints.maxHeight - 22),
                      child: CustomPaint(
                        size: const Size(double.infinity, 2),
                        painter: _DashPainter(context.cycle.heading),
                      ),
                    ),
                ],
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final l in labels)
                Expanded(
                  child: Text(
                    l,
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

/// Grid of counts: items (rows) × cycle-day ranges (columns).
class PatternHeatmap<T> extends StatelessWidget {
  const PatternHeatmap({
    super.key,
    required this.grid,
    required this.items,
    required this.labelOf,
    required this.iconOf,
    required this.color,
  });

  final PatternGrid<T> grid;
  final List<T> items;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final max = math.max(1, grid.maxCount);
    final muted = context.cycle.muted;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 112),
            for (final b in dayBuckets)
              Expanded(
                child: Text(
                  b.label,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(color: muted),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 112, top: 2, bottom: 6),
          child: Text(
            'Cycle day',
            style: context.text.labelSmall?.copyWith(color: muted),
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  child: Row(
                    children: [
                      Icon(iconOf(item), size: 18, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          labelOf(item),
                          style: context.text.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < dayBuckets.length; i++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final n = grid.rows[item]?[i] ?? 0;
                      return Semantics(
                        label: '${labelOf(item)}, cycle days '
                            '${dayBuckets[i].label}: $n',
                        excludeSemantics: true,
                        child: Container(
                          height: 30,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: n == 0
                                ? context.cycle.cardBorder.withValues(alpha: 0.5)
                                : color.withValues(
                                    alpha: 0.18 + 0.82 * (n / max)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: n == 0
                              ? null
                              : Text(
                                  '$n',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: n / max > 0.55
                                        ? Colors.white
                                        : context.cycle.heading,
                                  ),
                                ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 30 small squares, filled for each logged day (oldest left).
class LoggingStrip extends StatelessWidget {
  const LoggingStrip({super.key, required this.logged});

  /// 30 booleans, oldest first.
  final List<bool> logged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final l in logged)
          Expanded(
            child: Container(
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: l
                    ? context.colors.primary
                    : context.cycle.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}

/// Horizontal timeline showing the likely window for the next period.
class WindowTimeline extends StatelessWidget {
  const WindowTimeline({
    super.key,
    required this.today,
    required this.earliest,
    required this.latest,
    required this.estimate,
  });

  final DateTime today;
  final DateTime earliest;
  final DateTime latest;
  final DateTime? estimate;

  @override
  Widget build(BuildContext context) {
    final start = today;
    final end = latest.add(const Duration(days: 4));
    final total = end.difference(start).inDays.clamp(1, 1000);
    double pos(DateTime d) =>
        (d.difference(start).inDays / total).clamp(0.0, 1.0);
    final fmt = DateFormat('d MMM');
    final c = context.cycle;
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 64,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 22,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: c.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: w * pos(earliest),
              width: math.max(10.0, w * (pos(latest) - pos(earliest))),
              top: 18,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  gradient: c.buttonGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Text('Today', style: context.text.labelSmall),
            ),
            Positioned(
              left: 0,
              top: 40,
              child: Text(fmt.format(today),
                  style: context.text.labelSmall?.copyWith(color: c.muted)),
            ),
            Positioned(
              left: math.min(w * pos(earliest), w - 90),
              top: 40,
              child: Text(
                '${fmt.format(earliest)} – ${fmt.format(latest)}',
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
