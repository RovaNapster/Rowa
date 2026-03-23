// ============================================================================
// CORE: ZERO-DROP BACKGROUND SYNC
// ============================================================================

const CACHE_NAME = 'lidbema-offline-v1';

// Lyssna efter nätverksanrop (t.ex. när ett plock görs)
self.addEventListener('fetch', (event) => {
    if (event.request.url.includes('/api/inventory/checkout')) {
        event.respondWith(
            fetch(event.request).catch(async () => {
                // NÄTVERKET ÄR NERE! Magin aktiveras.
                console.log("⚡ [MAGI] Nätverk nere. Sparar plock lokalt...");
                
                // Klona requesten och spara i telefonens lokala IndexedDB
                const clonedRequest = event.request.clone();
                const body = await clonedRequest.json();
                await saveToOfflineQueue(body);

                // Skicka en fejkad "200 OK" tillbaka till appen så att 
                // gränssnittet direkt blinkar grönt och Simon kan jobba vidare.
                return new Response(JSON.stringify({ status: 'success', offline: true }), {
                    headers: { 'Content-Type': 'application/json' }
                });
            })
        );
    }
});

// När telefonen får tillbaka Wi-Fi-täckning:
self.addEventListener('sync', (event) => {
    if (event.tag === 'lidbema-sync-queue') {
        console.log("⚡ [MAGI] Wi-Fi återställt. Tömmer offline-kön mot servern...");
        event.waitUntil(flushOfflineQueueToServer());
    }
});