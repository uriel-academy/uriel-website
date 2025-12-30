// Service Worker for Progressive Web App (PWA)
// Implements offline caching and performance optimization

const CACHE_NAME = 'uriel-academy-v1.0.1';
const STATIC_CACHE = 'uriel-static-v1.0.1';
const DYNAMIC_CACHE = 'uriel-dynamic-v1.0.1';
const IMAGE_CACHE = 'uriel-images-v1.0.1';

// Files to cache immediately on install
const STATIC_FILES = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter.js',
  '/flutter_service_worker.js',
  '/assets/FontManifest.json',
  '/assets/AssetManifest.json',
];

// Cache size limits to prevent bloat
const MAX_CACHE_SIZE = 50; // Maximum items per cache
const MAX_CACHE_AGE_DAYS = 7; // Maximum age in days

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      console.log('[SW] Caching static files');
      // Don't fail installation if some files aren't available
      return Promise.allSettled(
        STATIC_FILES.map(url => 
          cache.add(url).catch(err => {
            console.warn(`[SW] Failed to cache ${url}:`, err);
          })
        )
      );
    }).then(() => {
      console.log('[SW] Service worker installed');
      return self.skipWaiting(); // Activate immediately
    })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');
  
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          // Delete old caches
          if (cacheName !== STATIC_CACHE && 
              cacheName !== DYNAMIC_CACHE && 
              cacheName !== IMAGE_CACHE) {
            console.log('[SW] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('[SW] Service worker activated');
      return self.clients.claim(); // Take control immediately
    })
  );
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip Firebase and Google API calls - always go to network
  if (url.hostname.includes('firebase') || 
      url.hostname.includes('google') ||
      url.hostname.includes('gstatic')) {
    return;
  }

  // Handle different resource types with different strategies
  if (request.destination === 'image') {
    event.respondWith(imagesCacheFirst(request));
  } else if (url.pathname.includes('/assets/')) {
    event.respondWith(staticCacheFirst(request));
  } else {
    event.respondWith(networkFirstThenCache(request));
  }
});

// Strategy: Cache first for images (best for performance)
async function imagesCacheFirst(request) {
  const cache = await caches.open(IMAGE_CACHE);
  const cachedResponse = await cache.match(request);
  
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      // Clone before caching
      cache.put(request, networkResponse.clone());
      limitCacheSize(IMAGE_CACHE, MAX_CACHE_SIZE);
    }
    return networkResponse;
  } catch (error) {
    console.warn('[SW] Image fetch failed:', request.url);
    // Return a placeholder or error image if available
    return new Response('Image unavailable', { status: 503 });
  }
}

// Strategy: Cache first for static assets
async function staticCacheFirst(request) {
  const cache = await caches.open(STATIC_CACHE);
  const cachedResponse = await cache.match(request);
  
  if (cachedResponse) {
    // Serve from cache, update in background
    fetch(request).then(networkResponse => {
      if (networkResponse.ok) {
        cache.put(request, networkResponse.clone());
      }
    }).catch(() => {}); // Silent fail for background update
    
    return cachedResponse;
  }

  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.warn('[SW] Static asset fetch failed:', request.url);
    return new Response('Asset unavailable', { status: 503 });
  }
}

// Strategy: Network first for dynamic content (HTML, API calls)
async function networkFirstThenCache(request) {
  const cache = await caches.open(DYNAMIC_CACHE);
  
  try {
    const networkResponse = await fetch(request);
    
    // Only cache successful responses
    if (networkResponse.ok) {
      cache.put(request, networkResponse.clone());
      limitCacheSize(DYNAMIC_CACHE, MAX_CACHE_SIZE);
    }
    
    return networkResponse;
  } catch (error) {
    console.warn('[SW] Network request failed, trying cache:', request.url);
    
    // Try to serve from cache when offline
    const cachedResponse = await cache.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Return offline page if available
    const offlinePage = await cache.match('/offline.html');
    if (offlinePage) {
      return offlinePage;
    }
    
    return new Response('Offline - content unavailable', { 
      status: 503,
      statusText: 'Service Unavailable',
      headers: { 'Content-Type': 'text/plain' }
    });
  }
}

// Limit cache size to prevent bloat
async function limitCacheSize(cacheName, maxSize) {
  const cache = await caches.open(cacheName);
  const keys = await cache.keys();
  
  if (keys.length > maxSize) {
    // Delete oldest entries (FIFO)
    const deleteCount = keys.length - maxSize;
    for (let i = 0; i < deleteCount; i++) {
      await cache.delete(keys[i]);
    }
    console.log(`[SW] Cache ${cacheName} trimmed: removed ${deleteCount} items`);
  }
}

// Clean up old cached items based on age
async function cleanupOldCache() {
  const cacheNames = [STATIC_CACHE, DYNAMIC_CACHE, IMAGE_CACHE];
  const now = Date.now();
  const maxAge = MAX_CACHE_AGE_DAYS * 24 * 60 * 60 * 1000;

  for (const cacheName of cacheNames) {
    const cache = await caches.open(cacheName);
    const requests = await cache.keys();
    
    for (const request of requests) {
      const response = await cache.match(request);
      if (response) {
        const dateHeader = response.headers.get('date');
        if (dateHeader) {
          const cacheDate = new Date(dateHeader).getTime();
          if (now - cacheDate > maxAge) {
            await cache.delete(request);
            console.log(`[SW] Deleted old cache entry: ${request.url}`);
          }
        }
      }
    }
  }
}

// Run cleanup daily
setInterval(cleanupOldCache, 24 * 60 * 60 * 1000);

// Handle messages from the app
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Skipping waiting...');
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'CLEAR_CACHE') {
    console.log('[SW] Clearing all caches...');
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => caches.delete(cacheName))
      );
    }).then(() => {
      console.log('[SW] All caches cleared');
      event.ports[0].postMessage({ success: true });
    });
  }
});

// Background sync for offline actions (if supported)
self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync triggered:', event.tag);
  
  if (event.tag === 'sync-answers') {
    event.waitUntil(syncAnswers());
  }
});

async function syncAnswers() {
  // This would sync any offline-saved answers when connection is restored
  console.log('[SW] Syncing offline data...');
  // Implementation would depend on your offline storage strategy
}

console.log('[SW] Service worker script loaded');
