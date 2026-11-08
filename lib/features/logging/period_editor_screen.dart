import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../domain/cycle_calculator.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../routing/app_router.dart';

/// Add or edit one period (start, end or still going, notes).
class PeriodEditorScreen extends ConsumerStatefulWidget {
  const PeriodEditorScreen({super.key, this.periodId, this.initialStart});

  final String? periodId;
  final DateTime? initialStart;

  @override
  ConsumerState<PeriodEditorScreen> createState() =>
      _PeriodEditorScreenState();
}

class _PeriodEditorScreenState extends ConsumerState<PeriodEditorScreen> {
  DateTime? _start;
  DateTime? _end;
  bool _ongoing = false;
  final _notes = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.periodId == null;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _load(List<Period> periods, DateTime today) {
    _loaded = true;
    if (_isNew) {
      final s = widget.initialStart;
      _start = (s == null || s.isAfter(today)) ? today : s;
      _ongoing = daysBetween(_start!, today) < 7;
      return;
    }
    for (final p in periods) {
      if (p.id == widget.periodId) {
        _start = p.start;
        _end = p.end;
        _ongoing = p.end == null;
        _notes.text = p.notes ?? '';
        return;
      }
    }
  }

  Future<void> _save(List<Period> periods, DateTime today) async {
    setState(() => _error = null);
    final start = _start;
    final end = _ongoing ? null : _end;
    if (start == null) {
      setState(() => _error = 'Choose the first day of your period.');
      return;
    }
    if (end != null && end.isBefore(start)) {
      setState(() => _error = 'The last day cannot be before the first day.');
      return;
    }

    final repo = ref.read(repositoryProvider);
    final fmt = DateFormat('d MMM yyyy');

    // An earlier period left open would block this one: offer to close it.
    var others = periods;
    final open = periods.where((p) =>
        p.id != widget.periodId &&
        p.end == null &&
        p.start.isBefore(start)).toList();
    for (final p in open) {
      if (!mounted) return;
      final dayBefore = addDays(start, -1);
      if (!p.effectiveEnd(today).isBefore(start)) {
        final ok = await confirmDialog(
          context,
          title: 'End your previous period?',
          message: 'Your period from ${fmt.format(p.start)} has no end date. '
              'Set it to end on ${fmt.format(dayBefore)}?',
          confirmLabel: 'Yes, end it',
        );
        if (!ok) return;
        try {
          await repo.savePeriod(
            id: p.id,
            start: p.start,
            end: dayBefore.isBefore(p.start) ? p.start : dayBefore,
            notes: p.notes,
          );
          others = await repo.fetchPeriods();
        } on AppException catch (e) {
          if (mounted) setState(() => _error = e.message);
          return;
        } on PeriodOverlapException {
          if (mounted) {
            setState(() => _error = 'Could not update the previous period.');
          }
          return;
        }
      }
    }

    final overlap = CycleCalculator.findOverlap(
      existing: others,
      start: start,
      end: end,
      excludeId: widget.periodId,
      today: today,
    );
    if (overlap != null) {
      if (!mounted) return;
      final range = overlap.end == null
          ? 'from ${fmt.format(overlap.start)}'
          : '${fmt.format(overlap.start)} – ${fmt.format(overlap.end!)}';
      final edit = await confirmDialog(
        context,
        title: 'Overlaps another period',
        message: 'These dates overlap your period $range. '
            'Would you like to edit that period instead?',
        confirmLabel: 'Edit that period',
      );
      if (edit && mounted) {
        context.pushReplacement(AppRoutes.periodEdit(overlap.id));
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await repo.savePeriod(
        id: widget.periodId,
        start: start,
        end: end,
        notes: _notes.text,
      );
      refreshCycleData(ref);
      if (mounted) {
        showMessage(context, 'Period saved');
        context.pop();
      }
    } on PeriodOverlapException {
      if (mounted) {
        setState(() => _error = 'These dates overlap another recorded period.');
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this period?',
      message: 'This removes the period dates. Your estimates will be '
          'recalculated. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(repositoryProvider).deletePeriod(widget.periodId!);
      refreshCycleData(ref);
      if (mounted) {
        showMessage(context, 'Period deleted');
        context.pop();
      }
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodsAsync = ref.watch(periodsProvider);
    final today = ref.watch(todayProvider);

    if (!_loaded && periodsAsync.hasValue) _load(periodsAsync.value!, today);

    final notFound = _loaded && !_isNew && _start == null;
    return GradientScaffold(
      title: _isNew ? 'Log Period' : 'Edit Period',
      actions: [
        if (!_isNew && !notFound)
          IconButton(
            tooltip: 'Delete period',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
      body: !_loaded
          ? (periodsAsync.hasError
              ? ErrorView(onRetry: () => ref.invalidate(periodsProvider))
              : const LoadingView())
          : notFound
              ? const Center(child: Text('This period no longer exists.'))
              : PageBody(
                  children: [
                    const SizedBox(height: 8),
                    DateField(
                      label: 'First day of bleeding',
                      value: _start,
                      allowClear: false,
                      firstDate: addDays(today, -3650),
                      lastDate: today,
                      onChanged: (d) => setState(() {
                        _start = d;
                        if (_end != null && d != null && _end!.isBefore(d)) {
                          _end = null;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _ongoing,
                      onChanged: (v) => setState(() => _ongoing = v),
                      title: const Text('Still going'),
                      subtitle: const Text('Add the last day when it ends'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (!_ongoing) ...[
                      DateField(
                        label: 'Last day',
                        value: _end,
                        firstDate: _start ?? addDays(today, -3650),
                        lastDate: today,
                        onChanged: (d) => setState(() => _end = d),
                      ),
                      if (_end == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'Optional. Without it, period length is not counted.',
                            style: context.text.bodySmall
                                ?.copyWith(color: context.cycle.muted),
                          ),
                        ),
                    ],
                    if (_start != null && _end != null && !_ongoing)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Pill(
                          '${daysBetween(_start!, _end!) + 1} days',
                          icon: Icons.water_drop,
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notes,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: context.colors.error),
                        ),
                      ),
                    GradientButton(
                      label: 'Save Period',
                      loading: _saving,
                      onPressed: periodsAsync.hasValue
                          ? () => _save(periodsAsync.value!, today)
                          : null,
                    ),
                  ],
                ),
    );
  }
}
