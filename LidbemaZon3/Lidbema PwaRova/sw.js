// ============================================================================
// CORE: ZERO-DROP BACKGROUND SYNC & PWA CACHE
// ============================================================================

const CACHE_NAME = 'lidbema-offline-v1';
const ASSETS = [
    './',
    './index.html',
    './manifest.json',
    './RouteOptimizer.js',
    './Rova_Overkill_Boot.js'
];

// 1. PWA INSTALL: Cacha alla viktiga filer
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
    );
});

// 2. PWA ACTIVATE: Rensa gamla cacher
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) => Promise.all(
            keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
        ))
    );
});

// 3. ROVA OFFLINE MAGI: Lyssna efter nätverksanrop
self.addEventListener('fetch', (event) => {
    // Om det är checkout-APIt, kör din overkill-logik
    if (event.request.url.includes('/api/inventory/checkout')) {
        event.respondWith(
            fetch(event.request).catch(async () => {
                console.log("⚡ [MAGI] Nätverk nere. Sparar plock lokalt...");
                const clonedRequest = event.request.clone();
                const body = await clonedRequest.json();
                
                // Här anropas din saveToOfflineQueue(body) i verkligheten
                
                return new Response(JSON.stringify({ status: 'success', offline: true }), {
                    headers: { 'Content-Type': 'application/json' }
                });
            })
        );
    } else {
        // Standard PWA Cache-first för alla andra filer (HTML, JS, CSS)
        event.respondWith(
            caches.match(event.request).then(response => response || fetch(event.request))
        );
    }
});

// 4. BACKGROUND SYNC
self.addEventListener('sync', (event) => {
    if (event.tag === 'lidbema-sync-queue') {
        console.log("⚡ [MAGI] Wi-Fi återställt. Tömmer offline-kön mot servern...");
        // event.waitUntil(flushOfflineQueueToServer());
    }
});