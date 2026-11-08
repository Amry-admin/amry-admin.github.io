import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown instead of the app when build-time configuration is missing or unsafe.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.problems});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CycleSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'CycleSync is not configured',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              for (final p in problems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $p'),
                ),
              const SizedBox(height: 16),
              const Text(
                'Developers: build with\n'
                '--dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co\n'
                '--dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
