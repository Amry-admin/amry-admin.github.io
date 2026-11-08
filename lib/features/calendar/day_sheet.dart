import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/cycle_visuals.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../routing/app_router.dart';

/// Bottom sheet with what is known about [day] and actions for it.
Future<void> showDaySheet(BuildContext context, WidgetRef ref, DateTime day) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _DaySheet(day: day, parentContext: context),
  );
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.day, required this.parentContext});

  final DateTime day;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider).value;
    final log = ref.watch(logsByDateProvider).value?[day];
    if (summary == null) return const SizedBox(height: 200, child: LoadingView());

    final today = summary.today;
    final isFuture = day.isAfter(today);
    final mark = markFor(summary, day);
    final period = summary.periodOn(day);

    void go(String route) {
      Navigator.of(context).pop();
      parentContext.push(route);
    }

    final status = switch (mark) {
      DayMark.period => 'Logged period day',
      DayMark.predictedPeriod => 'Estimated period day',
      DayMark.fertile => 'Estimated fertile window',
      DayMark.ovulation => 'Estimated ovulation day',
      DayMark.none => null,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(day),
              style: context.text.titleLarge,
            ),
            if (sameDate(day, today))
              Text('Today', style: TextStyle(color: context.colors.primary)),
            if (status != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    mark == DayMark.period || mark == DayMark.predictedPeriod
                        ? Icons.water_drop
                        : Icons.spa_outlined,
                    color: mark == DayMark.period ||
                            mark == DayMark.predictedPeriod
                        ? context.cycle.period
                        : context.cycle.fertile,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(status, style: context.text.bodyLarge),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (log != null && !log.isEmpty)
              _LogSummary(log: log)
            else if (!isFuture)
              Text(
                'Nothing logged for this day yet.',
                style: context.text.bodyMedium
                    ?.copyWith(color: context.cycle.muted),
              ),
            const SizedBox(height: 20),
            if (!isFuture) ...[
              GradientButton(
                label: log == null ? 'Log this day' : 'Edit daily log',
                icon: Icons.edit_note,
                onPressed: () => go(AppRoutes.logFor(day)),
              ),
              const SizedBox(height: 10),
              if (period != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Edit this period'),
                  onPressed: () => go(AppRoutes.periodEdit(period.id)),
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text('Period started this day'),
                  onPressed: () => go(AppRoutes.newPeriodFrom(day)),
                ),
            ] else
              Text(
                'Estimates for future days can change as you log more.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.cycle.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogSummary extends StatelessWidget {
  const _LogSummary({required this.log});
  final DailyLog log;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (log.flow != Flow.none)
        _chip(context, flowIcon(log.flow), 'Flow: ${log.flow.label}'),
      for (final s in log.symptoms) _chip(context, symptomIcon(s), s.label),
      for (final m in log.moods) _chip(context, moodIcon(m), m.label),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: chips),
        if (log.notes != null && log.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('“${log.notes!.trim()}”', style: context.text.bodyMedium),
        ],
      ],
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) => Chip(
        avatar: Icon(icon, size: 18, color: context.colors.primary),
        label: Text(label),
      );
}
