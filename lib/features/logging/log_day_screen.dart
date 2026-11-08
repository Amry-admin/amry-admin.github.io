import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/cycle_visuals.dart';
import '../../core/widgets/inputs.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../routing/app_router.dart';

/// Daily check-in: flow, symptoms, mood and a note for one date.
class LogDayScreen extends ConsumerStatefulWidget {
  const LogDayScreen({super.key, this.date});

  final DateTime? date;

  @override
  ConsumerState<LogDayScreen> createState() => _LogDayScreenState();
}

class _LogDayScreenState extends ConsumerState<LogDayScreen> {
  late DateTime _date;
  Flow _flow = Flow.none;
  final Set<Symptom> _symptoms = {};
  final Set<Mood> _moods = {};
  final _notes = TextEditingController();
  String? _existingId;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    final d = widget.date;
    _date = (d == null || d.isAfter(today)) ? today : d;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _loadFrom(DailyLog? log) {
    _existingId = log?.id;
    _flow = log?.flow ?? Flow.none;
    _symptoms
      ..clear()
      ..addAll(log?.symptoms ?? const []);
    _moods
      ..clear()
      ..addAll(log?.moods ?? const []);
    _notes.text = log?.notes ?? '';
    _loaded = true;
  }

  Future<void> _changeDate(DateTime d) async {
    final logs = await ref.read(logsByDateProvider.future);
    if (!mounted) return;
    setState(() {
      _date = d;
      _loadFrom(logs[d]);
    });
  }

  Future<void> _save() async {
    final log = DailyLog(
      id: _existingId,
      date: _date,
      flow: _flow,
      symptoms: Symptom.values.where(_symptoms.contains).toList(),
      moods: Mood.values.where(_moods.contains).toList(),
      notes: _notes.text,
    );
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    try {
      if (log.isEmpty) {
        if (_existingId != null) await repo.deleteLog(_existingId!);
      } else {
        await repo.saveLog(log);
      }
      ref.invalidate(logsProvider);
      if (!mounted) return;

      // Bleeding logged outside a recorded period: offer to record one.
      final summary = ref.read(summaryProvider).value;
      final inPeriod = summary?.periodOn(_date) != null;
      if (_flow.isBleeding && !inPeriod) {
        final start = await confirmDialog(
          context,
          title: 'Record a period?',
          message:
              'You logged ${_flow.label.toLowerCase()} flow. Did your period start on '
              '${DateFormat('d MMMM').format(_date)}?',
          confirmLabel: 'Yes, record it',
        );
        if (!mounted) return;
        if (start) {
          context.pushReplacement(AppRoutes.newPeriodFrom(_date));
          return;
        }
      }
      showMessage(context, 'Saved');
      context.pop();
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this log?',
      message: 'Flow, symptoms, mood and note for this day will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || _existingId == null) return;
    try {
      await ref.read(repositoryProvider).deleteLog(_existingId!);
      ref.invalidate(logsProvider);
      if (mounted) {
        showMessage(context, 'Log deleted');
        context.pop();
      }
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(logsByDateProvider);
    final today = ref.watch(todayProvider);

    if (!_loaded && logs.hasValue) _loadFrom(logs.value![_date]);

    return GradientScaffold(
      title: 'Log Symptoms',
      actions: [
        if (_existingId != null)
          IconButton(
            tooltip: 'Delete log',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
      body: !_loaded
          ? (logs.hasError
              ? ErrorView(onRetry: () => ref.invalidate(logsProvider))
              : const LoadingView())
          : PageBody(
              children: [
                _DateSwitcher(
                  date: _date,
                  today: today,
                  onChanged: _changeDate,
                ),
                const SectionTitle('Flow level'),
                _grid(
                  columns: 5,
                  children: [
                    for (final f in Flow.values)
                      ChoiceTile(
                        label: f.label,
                        icon: flowIcon(f),
                        selected: _flow == f,
                        color: f == Flow.none
                            ? context.cycle.muted
                            : context.cycle.period,
                        onTap: () => setState(() => _flow = f),
                      ),
                  ],
                ),
                const SectionTitle('How are you feeling?'),
                _grid(
                  columns: 4,
                  children: [
                    for (final m in Mood.values)
                      ChoiceTile(
                        label: m.label,
                        icon: moodIcon(m),
                        selected: _moods.contains(m),
                        color: context.colors.secondary,
                        onTap: () => setState(() => _moods.contains(m)
                            ? _moods.remove(m)
                            : _moods.add(m)),
                      ),
                  ],
                ),
                const SectionTitle('Symptoms (optional)'),
                _grid(
                  columns: 3,
                  children: [
                    for (final s in Symptom.values)
                      ChoiceTile(
                        label: s.label,
                        icon: symptomIcon(s),
                        selected: _symptoms.contains(s),
                        onTap: () => setState(() => _symptoms.contains(s)
                            ? _symptoms.remove(s)
                            : _symptoms.add(s)),
                      ),
                  ],
                ),
                const SectionTitle('Note (optional)'),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Anything else worth remembering?',
                  ),
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Save Entry',
                  loading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 12),
                Text(
                  'Logging symptoms helps you spot patterns. It is not a diagnosis.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.cycle.muted),
                ),
              ],
            ),
    );
  }

  Widget _grid({required int columns, required List<Widget> children}) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final c in children) SizedBox(width: width, height: 92, child: c),
        ],
      );
    });
  }
}

class _DateSwitcher extends StatelessWidget {
  const _DateSwitcher({
    required this.date,
    required this.today,
    required this.onChanged,
  });

  final DateTime date;
  final DateTime today;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final isToday = sameDate(date, today);
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: () => onChanged(addDays(date, -1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: addDays(today, -730),
                  lastDate: today,
                );
                if (picked != null) onChanged(dateOnly(picked));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      isToday ? 'Today' : DateFormat('EEEE').format(date),
                      style: context.text.titleMedium,
                    ),
                    Text(
                      DateFormat('d MMMM yyyy').format(date),
                      style: context.text.bodySmall
                          ?.copyWith(color: context.cycle.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: isToday ? null : () => onChanged(addDays(date, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
