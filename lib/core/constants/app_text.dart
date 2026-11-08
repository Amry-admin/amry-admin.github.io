import 'package:flutter/foundation.dart';

/// Fixed user-facing text. Have legal wording reviewed before launch.
class AppText {
  const AppText._();

  static const String appName = 'CycleSync';
  static const String tagline = 'Know your cycle,\ncare for yourself';

  /// Public contact for privacy and security concerns. Set before launch.
  static const String supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL');

  static const String healthDisclaimer =
      'CycleSync is a period and cycle tracking tool. Its dates and insights '
      'are estimates based on information you enter and are not medical '
      'advice. CycleSync cannot diagnose a health condition, confirm '
      'ovulation, or prevent pregnancy. Menstrual cycles can vary. If you '
      'have concerns about your cycle, symptoms or health, speak with a '
      'qualified healthcare professional.';

  static const String estimatesShort =
      'Predictions are estimates and can change as you log more.';

  static const String fertileWarning =
      'Fertile-window and ovulation dates are rough calendar estimates. They '
      'cannot confirm ovulation and must not be used as contraception or to '
      'decide that unprotected sex is safe.';

  static const List<(String, String)> howEstimatesWork = [
    (
      'Cycle length',
      'The number of days from the first day of one period to the first day '
          'of the next.',
    ),
    (
      'Next period',
      'Once you have logged at least 3 cycles, CycleSync uses the middle '
          'value (median) of your latest 6 cycle lengths. Before that, it uses '
          'the typical cycle length you entered, if any. It never assumes a '
          'default.',
    ),
    (
      'Unusual gaps',
      'Gaps shorter than 15 or longer than 60 days (for example a missed '
          'log) are left out of estimates, so one gap does not skew them.',
    ),
    (
      'Period length',
      'Once you have logged 3 periods with end dates, CycleSync uses the '
          'median of your recent period lengths; before that, your setting.',
    ),
    (
      'Fertile window (optional)',
      'If you turn it on, it is estimated as the 5 days before and 1 day '
          'after a date 14 days before your next estimated period. This is '
          'a calendar estimate only.',
    ),
  ];

  static String get privacyNotice => '''
CycleSync privacy notice (draft)

What we collect
• Your email address and a securely hashed password, to run your account.
• What you choose to log: period dates, flow, symptoms, mood, notes, and optional settings such as typical cycle length, display name and reminder times.
• Your device's time zone, so dates and reminders are correct.

We do not collect your date of birth, location, contacts, photos or advertising identifiers, and we do not use analytics or advertising tools.

Why
Only to provide the tracking, estimates, reminders and export features you use. We never sell or share your health information for advertising.

Where it is stored
Your data is stored with our database provider, Supabase, in a data centre in Europe. This is a transfer of information outside South Africa. Each account's records are isolated by database security rules, and all connections use HTTPS.

Notifications
Reminders are created on your phone. By default their text is neutral ("You have a CycleSync reminder") so nothing sensitive shows on your lock screen.

Your choices and rights
You can view and correct your records at any time, export them as a CSV file, and permanently delete your account and all records from Settings → Privacy & Security. You may also ask about, object to, or complain about how your information is handled, including to the Information Regulator (South Africa).

Age
CycleSync is intended for adults (18+).

Contact
${supportEmail.isEmpty ? 'A contact address for privacy and security concerns will be published here before launch.' : supportEmail}

This notice is a draft and will be reviewed before public launch.
''';

  /// Shown in About. Set by the build.
  static String get buildMode => kReleaseMode ? 'Release' : 'Debug';
}

/// Links used across the app.
class AppLinks {
  const AppLinks._();

  /// Public address of the web app, set by the build workflow.
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://cyclesyncapp.github.io/',
  );

  /// Where Supabase sends people back to from Android emails.
  static const String androidAuthCallback =
      'io.github.ebrahimomar0729.cyclesync://login-callback';

  /// Where sign-up and password-reset emails should send the user back to.
  static String authRedirect() {
    if (kIsWeb) {
      final base = Uri.base;
      return '${base.origin}${base.path}';
    }
    return androidAuthCallback;
  }

  static String shareMessage() =>
      'Track your cycle privately with CycleSync: $webAppUrl';
}
