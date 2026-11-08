{{flutter_js}}
{{flutter_build_config}}

// Start the app. Flutter's own offline service worker is not used; CycleSync
// registers sw.js instead, which shows reminder notifications (web push).
_flutter.loader.load();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('sw.js').catch(function () {});
  });
}
