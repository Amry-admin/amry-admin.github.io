import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/widgets/config_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final problems = AppConfig.problems(
    AppConfig.supabaseUrl,
    AppConfig.supabaseAnonKey,
  );
  if (problems.isNotEmpty) {
    runApp(ConfigErrorApp(problems: problems));
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl.trim(),
    // Accepts the publishable key or the legacy anon key; both are public.
    publishableKey: AppConfig.supabaseAnonKey.trim(),
  );

  runApp(const ProviderScope(child: CycleSyncApp()));
}
