import 'package:supabase_flutter/supabase_flutter.dart';

enum BackendStatus { connected, couldNotConnect }

/// Confirms the app can reach Supabase with the configured public key.
///
/// It asks for at most one profile id. Without a signed-in user, Row Level
/// Security returns no rows, so a successful empty answer proves the URL,
/// key and network work without exposing any data.
class BackendStatusService {
  BackendStatusService(this._client);

  final SupabaseClient _client;

  Future<BackendStatus> check() async {
    try {
      await _client
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));
      return BackendStatus.connected;
    } catch (_) {
      // Deliberately not logged: errors can contain request details.
      return BackendStatus.couldNotConnect;
    }
  }
}
