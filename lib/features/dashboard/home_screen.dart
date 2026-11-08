import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_text.dart';
import '../../core/providers.dart';
import '../../data/services/backend_status_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(backendStatusProvider);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppText.appName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next period', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Add period dates to start receiving estimates.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Period logging arrives in a coming update.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App status', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  status.when(
                    loading: () => const _StatusRow(
                      icon: Icons.sync,
                      label: 'Checking connection…',
                    ),
                    error: (error, stackTrace) => const _StatusRow(
                      icon: Icons.cloud_off,
                      label: 'Could not reach CycleSync servers',
                    ),
                    data: (s) => s == BackendStatus.connected
                        ? const _StatusRow(
                            icon: Icons.cloud_done,
                            label: 'Connected securely',
                          )
                        : const _StatusRow(
                            icon: Icons.cloud_off,
                            label: 'Could not reach CycleSync servers',
                          ),
                  ),
                  const SizedBox(height: 4),
                  _StatusRow(
                    icon: signedIn ? Icons.lock_open : Icons.lock_outline,
                    label: signedIn ? 'Signed in' : 'Not signed in',
                  ),
                  if (status.hasValue &&
                      status.value == BackendStatus.couldNotConnect)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(backendStatusProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About estimates', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    AppText.healthDisclaimer,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
