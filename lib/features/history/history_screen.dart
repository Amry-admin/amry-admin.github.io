import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../routing/app_router.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    return GradientScaffold(
      title: 'Period History',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push(AppRoutes.newPeriodFrom(ref.read(todayProvider))),
        icon: const Icon(Icons.add),
        label: const Text('Add period'),
      ),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(onRetry: () => refreshCycleData(ref)),
        data: (s) {
          if (s.periods.isEmpty) {
            return PageBody(children: [
              EmptyState(
                icon: Icons.water_drop_outlined,
                title: 'No periods yet',
                message: 'Add your past periods to see your history and '
                    'get estimates.',
                actionLabel: 'Add a period',
                onAction: () =>
                    context.push(AppRoutes.newPeriodFrom(s.today)),
              ),
            ]);
          }
          final fmtShort = DateFormat('d MMM');
          final fmtLong = DateFormat('d MMM yyyy');
          // newest first; cycle length = days to the following (newer) start.
          final ps = s.periods;
          return PageBody(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < ps.length; i++) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      _PeriodRow(
                        period: ps[i],
                        today: s.today,
                        cycleLength: i == 0
                            ? null
                            : daysBetween(ps[i].start, ps[i - 1].start),
                        label: ps[i].end == null
                            ? 'From ${fmtLong.format(ps[i].start)}'
                            : ps[i].start.year == ps[i].end!.year
                                ? '${fmtShort.format(ps[i].start)} – ${fmtLong.format(ps[i].end!)}'
                                : '${fmtLong.format(ps[i].start)} – ${fmtLong.format(ps[i].end!)}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SoftCard(
                tint: context.cycle.softLavenderCard,
                child: Row(
                  children: [
                    const IconBubble(icon: Icons.bar_chart_rounded, size: 52),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Average cycle length',
                              style: context.text.bodyMedium),
                          Text(
                            s.stats.averageCycle == null
                                ? 'Not enough data yet'
                                : '${s.stats.averageCycle!.round()} days',
                            style: context.text.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text('Average period length',
                              style: context.text.bodyMedium),
                          Text(
                            s.stats.averagePeriod == null
                                ? 'Not enough data yet'
                                : '${s.stats.averagePeriod!.round()} days',
                            style: context.text.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Averages appear after 3 cycles (or 3 periods with an end date). '
                'Cycle length runs from one period start to the next.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.cycle.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.today,
    required this.cycleLength,
    required this.label,
  });

  final Period period;
  final DateTime today;
  final int? cycleLength;
  final String label;

  @override
  Widget build(BuildContext context) {
    final duration = period.durationDays;
    final trailing = duration != null
        ? '$duration day${duration == 1 ? '' : 's'}'
        : period.isOngoingOn(today)
            ? 'Ongoing'
            : 'End not set';
    return ListTile(
      leading: Icon(Icons.water_drop, color: context.cycle.period),
      title: Text(label),
      subtitle: cycleLength == null ? null : Text('Cycle: $cycleLength days'),
      trailing: Text(
        trailing,
        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      onTap: () => context.push(AppRoutes.periodEdit(period.id)),
    );
  }
}
