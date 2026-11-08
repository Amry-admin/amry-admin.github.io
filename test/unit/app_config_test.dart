import 'dart:convert';

import 'package:cyclesync/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt(Map<String, Object> payload) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(payload)}.signature';
}

void main() {
  const url = 'https://abcdefgh.supabase.co';

  group('AppConfig.problems', () {
    test('accepts a publishable key', () {
      expect(AppConfig.problems(url, 'sb_publishable_abc123'), isEmpty);
    });

    test('accepts a legacy anon JWT', () {
      expect(AppConfig.problems(url, _fakeJwt({'role': 'anon'})), isEmpty);
    });

    test('reports missing values', () {
      final issues = AppConfig.problems('', '');
      expect(issues, hasLength(2));
      expect(issues.first, contains('SUPABASE_URL'));
      expect(issues.last, contains('SUPABASE_ANON_KEY'));
    });

    test('rejects a non-https URL', () {
      expect(
        AppConfig.problems('http://abcdefgh.supabase.co', 'sb_publishable_x'),
        [contains('https')],
      );
    });

    test('rejects a new-style secret key', () {
      expect(
        AppConfig.problems(url, 'sb_secret_abc123'),
        [contains('secret key')],
      );
    });

    test('rejects a legacy service_role JWT', () {
      expect(
        AppConfig.problems(url, _fakeJwt({'role': 'service_role'})),
        [contains('secret key')],
      );
    });

    test('never echoes the key in messages', () {
      const key = 'sb_secret_DO_NOT_SHOW';
      for (final msg in AppConfig.problems(url, key)) {
        expect(msg, isNot(contains(key)));
      }
    });
  });
}
