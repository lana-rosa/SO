// Service Worker del Sistema Operativo Lana Rosa.
// Estrategia "network-first": siempre intenta traer la versión más
// reciente de internet primero, y solo usa la copia guardada si no hay
// conexión. Así se evita el problema que tuvimos con el ERP, donde una
// copia vieja se quedó sirviendo contenido desactualizado.
const CACHE_NAME = 'lr-os-v1';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((claves) =>
      Promise.all(claves.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    fetch(event.request)
      .then((respuesta) => {
        const copia = respuesta.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copia));
        return respuesta;
      })
      .catch(() => caches.match(event.request))
  );
});
