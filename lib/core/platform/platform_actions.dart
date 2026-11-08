import 'platform_actions_io.dart'
    if (dart.library.js_interop) 'platform_actions_web.dart' as impl;

/// True when the web app is running from the home screen (installed PWA).
bool isInstalledWebApp() => impl.isInstalledWebApp();

/// True on iPhone / iPad browsers (for install instructions).
bool isAppleMobileBrowser() => impl.isAppleMobileBrowser();

/// Saves a text file: browser download on web, share sheet on Android.
Future<void> saveTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) =>
    impl.saveTextFile(fileName: fileName, content: content, mimeType: mimeType);
