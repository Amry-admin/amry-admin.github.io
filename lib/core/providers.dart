import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/services/backend_status_service.dart';

/// Result of the one-off connection check shown on the home screen.
final backendStatusProvider = FutureProvider<BackendStatus>((ref) {
  return BackendStatusService(Supabase.instance.client).check();
});

/// Whether a user session exists on this device. Sign-in arrives in Phase 2.
final isSignedInProvider = Provider<bool>((ref) {
  return Supabase.instance.client.auth.currentSession != null;
});
