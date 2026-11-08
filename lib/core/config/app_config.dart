import 'dart:convert';

/// Build-time configuration, supplied with --dart-define.
///
/// Only the Supabase project URL and the public (publishable / anon) key
/// belong here. Secret or service-role keys are rejected on purpose.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Returns human-readable problems with the given values.
  /// An empty list means the configuration is usable.
  /// Messages never include the key itself.
  static List<String> problems(String url, String key) {
    final issues = <String>[];

    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      issues.add('SUPABASE_URL is missing.');
    } else {
      final uri = Uri.tryParse(trimmedUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        issues.add('SUPABASE_URL must be a full https:// address.');
      }
    }

    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty) {
      issues.add('SUPABASE_ANON_KEY is missing.');
    } else if (trimmedKey.startsWith('sb_secret_') ||
        _isServiceRoleJwt(trimmedKey)) {
      issues.add(
        'SUPABASE_ANON_KEY is a secret key. Use the publishable or anon key '
        'instead, and rotate the secret key in Supabase now.',
      );
    }

    return issues;
  }

  static bool _isServiceRoleJwt(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = jsonDecode(payload);
      return json is Map && json['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
