// SHIK retirement worker: keep this URL for clients with an old registration.
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    await Promise.all(['flutter-app-cache', 'flutter-temp-cache',
      'flutter-app-manifest'].map(name => caches.delete(name)));
    await self.clients.claim();
    await self.registration.unregister();
  })());
});
// Previously controlled tabs use the network until they are closed/reloaded.
self.addEventListener('fetch', event => {
  if (event.request.method === 'GET' &&
      new URL(event.request.url).origin === self.location.origin) {
    event.respondWith(fetch(event.request, { cache: 'reload' }));
  }
});
