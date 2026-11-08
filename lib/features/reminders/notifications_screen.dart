import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/services/notification_service.dart';
import '../../domain/models.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  ReminderPrefs? _prefs;
  bool _saving = false;
  bool _dirty = false;

  void _update(ReminderPrefs p) => setState(() {
        _prefs = p;
        _dirty = true;
      });

  Future<void> _pickTime() async {
    final p = _prefs!;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: p.dailyHour, minute: p.dailyMinute),
    );
    if (t != null && mounted) {
      _update(p.copyWith(dailyHour: t.hour, dailyMinute: t.minute));
    }
  }

  Future<void> _save() async {
    final p = _prefs!;
    setState(() => _saving = true);
    try {
      if (p.anyEnabled && NotificationService.supported) {
        final allowed =
            await ref.read(notificationServiceProvider).requestPermission();
        if (!allowed && mounted) {
          showMessage(context,
              'Notifications are blocked. Allow them for CycleSync in your phone settings.');
        }
      }
      await ref.read(repositoryProvider).saveReminders(p);
      ref.invalidate(remindersProvider); // reschedules on Android
      if (mounted) {
        setState(() => _dirty = false);
        showMessage(context, 'Reminder settings saved');
      }
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(remindersProvider);
    final fertileOn =
        ref.watch(profileProvider).value?.showFertileWindow ?? false;
    _prefs ??= async.value;
    final p = _prefs;

    return GradientScaffold(
      title: 'Notifications',
      body: p == null
          ? (async.hasError
              ? ErrorView(onRetry: () => ref.invalidate(remindersProvider))
              : const LoadingView())
          : PageBody(
              children: [
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SwitchListTile(
                    value: p.anyEnabled,
                    onChanged: (on) => _update(on
                        ? p.copyWith(periodReminderEnabled: true)
                        : p.copyWith(
                            periodReminderEnabled: false,
                            fertileReminderEnabled: false,
                            dailyReminderEnabled: false,
                          )),
                    title: const Text('Enable reminders'),
                  ),
                ),
                const SectionTitle('Reminders'),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: p.periodReminderEnabled,
                        onChanged: (v) =>
                            _update(p.copyWith(periodReminderEnabled: v)),
                        secondary: Icon(Icons.water_drop_outlined,
                            color: context.cycle.period),
                        title: const Text('Next period reminder'),
                        subtitle: Text(
                            '${p.reminderDaysBefore} day${p.reminderDaysBefore == 1 ? '' : 's'} before the estimate'),
                      ),
                      if (p.periodReminderEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SegmentedButton<int>(
                            segments: [
                              for (var d = 1; d <= 5; d++)
                                ButtonSegment(value: d, label: Text('$d')),
                            ],
                            selected: {p.reminderDaysBefore},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => _update(
                                p.copyWith(reminderDaysBefore: s.first)),
                          ),
                        ),
                      const Divider(indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: p.fertileReminderEnabled && fertileOn,
                        onChanged: fertileOn
                            ? (v) =>
                                _update(p.copyWith(fertileReminderEnabled: v))
                            : null,
                        secondary: Icon(Icons.spa_outlined,
                            color: context.cycle.fertile),
                        title: const Text('Fertile window reminder (optional)'),
                        subtitle: Text(fertileOn
                            ? 'On the first estimated day'
                            : 'Turn on the fertile window in Cycle Settings first'),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: p.dailyReminderEnabled,
                        onChanged: (v) =>
                            _update(p.copyWith(dailyReminderEnabled: v)),
                        secondary: Icon(Icons.edit_note,
                            color: context.colors.primary),
                        title: const Text('Daily check-in'),
                        subtitle: Text(
                          'At ${TimeOfDay(hour: p.dailyHour, minute: p.dailyMinute).format(context)}',
                        ),
                      ),
                      if (p.dailyReminderEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule),
                            label: const Text('Change time'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SectionTitle('Privacy'),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SwitchListTile(
                    value: p.neutralText,
                    onChanged: (v) => _update(p.copyWith(neutralText: v)),
                    title: const Text('Discreet notification text'),
                    subtitle: Text(p.neutralText
                        ? 'Shows "You have a CycleSync reminder"'
                        : 'Shows details, e.g. "Your period may start in 2 days"'),
                  ),
                ),
                const SizedBox(height: 16),
                NoticeCard(
                  icon: Icons.info_outline,
                  tint: context.cycle.softLavenderCard,
                  text: NotificationService.supported
                      ? 'Reminders arrive as phone notifications. Estimates can change, so reminders update when you log.'
                      : 'In the web app, reminders show on the Home screen when you open CycleSync. Phone notifications need the Android app.',
                ),
                const SizedBox(height: 12),
                const NoticeCard(
                  icon: Icons.lock_outline,
                  text: 'Your data is private and secure with Supabase.',
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: _dirty ? 'Save Changes' : 'Saved',
                  loading: _saving,
                  onPressed: _dirty ? _save : null,
                ),
              ],
            ),
    );
  }
}
