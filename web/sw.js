// CycleSync service worker: displays reminder notifications sent by web push.
// It does not cache or read any personal data.

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {};
  }
  var title = data.title || 'CycleSync';
  var options = {
    body: data.body || 'You have a CycleSync reminder',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: data.tag || 'cyclesync',
    renotify: true,
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (clients) {
        for (var i = 0; i < clients.length; i++) {
          if ('focus' in clients[i]) return clients[i].focus();
        }
        return self.clients.openWindow(self.registration.scope);
      })
  );
});
