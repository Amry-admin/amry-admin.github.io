/// Whether this browser can receive CycleSync notifications.
enum WebPushState {
  /// Not a browser, or the browser has no web push.
  unsupported,

  /// iPhone/iPad: works only after adding to the Home Screen.
  needsInstall,

  /// Supported, not turned on yet.
  notAsked,

  /// The user blocked notifications in the browser.
  denied,

  /// Turned on for this browser.
  enabled,
}

class WebPushSubscriptionData {
  const WebPushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}
