// Service worker "kill-switch": reemplaza al de Flutter para deshacer cachés
// atascadas. El SW viejo re-descarga este archivo al navegar, ve que cambió,
// instala este, que limpia todo, se desregistra y recarga la página.
self.addEventListener('install', function (e) {
  self.skipWaiting();
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    (async function () {
      try {
        var keys = await caches.keys();
        await Promise.all(keys.map(function (k) { return caches.delete(k); }));
      } catch (_) {}
      try {
        await self.registration.unregister();
      } catch (_) {}
      var clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach(function (c) { c.navigate(c.url); });
    })()
  );
});
