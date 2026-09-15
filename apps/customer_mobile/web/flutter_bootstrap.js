{{flutter_js}}
{{flutter_build_config}}

window.__SHIK_BUILD_ID__ = '__SHIK_BUILD_ID__';
async function retireFlutterCache() {
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const registration of registrations) {
      const workers = [registration.active, registration.waiting, registration.installing];
      if (workers.some(worker => worker &&
          new URL(worker.scriptURL).pathname.endsWith('/flutter_service_worker.js'))) {
        await registration.unregister();
      }
    }
  }
  if ('caches' in window) {
    const names = ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'];
    await Promise.all(names.map(name => caches.delete(name)));
  }
}

(async () => {
  try {
    await retireFlutterCache();
    // No serviceWorkerSettings: never register a worker for new clients.
    await _flutter.loader.load();
  } catch (error) {
    console.error('SHIK web startup failed', error);
    document.body.textContent = 'Не удалось загрузить приложение. Перезагрузите страницу или откройте /web-reset.html';
  }
})();
