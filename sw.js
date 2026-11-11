// Offline cache: network first for the game page (so updates arrive), cache fallback when offline.
const CACHE = 'throttle-v1.32.0';
const ASSETS = ['./', './index.html', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(n => n !== CACHE).map(n => caches.delete(n)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  const fresh = e.request.mode === 'navigate' || /index\.html$|\/$|version\.json/.test(new URL(e.request.url).pathname);
  e.respondWith((fresh ? fetch(new Request(e.request.url, { cache: 'no-cache', credentials: 'same-origin' })) : fetch(e.request)).then(r => { if (r.ok && new URL(e.request.url).origin === location.origin) { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); } return r; })
    .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html'))));
});
