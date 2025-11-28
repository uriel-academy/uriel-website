# Flutter Web Optimization Guide

## Immediate Optimizations (No Code Changes)

### 1. Enable Deferred Loading for Heavy Routes
Split the app into smaller chunks that load on-demand.

**Benefits:**
- Initial load: 5.91 MB → ~2 MB (65% reduction)
- Faster Time to Interactive
- Better Core Web Vitals scores

**Implementation:**
Add to routes that are not immediately needed:
```dart
// Instead of:
import 'package:uriel_mainapp/screens/epub_reader_page.dart';

// Use deferred import:
import 'package:uriel_mainapp/screens/epub_reader_page.dart' deferred as epub_reader;

// Then load when needed:
await epub_reader.loadLibrary();
Navigator.push(context, MaterialPageRoute(builder: (_) => epub_reader.EpubReaderPage()));
```

**Best candidates for deferred loading:**
- EPUB Reader (rarely used, heavy)
- Admin Dashboard (only for admins)
- Analytics Pages (admin only)
- Storybooks Page (secondary feature)
- Study Planner (secondary feature)

---

### 2. Compress Remaining PNGs to WebP
**Current:** 9.4 MB of PNGs remaining
**Target:** ~2 MB

Files to convert:
- `landing_illustration.png` (2.19 MB) → ~200 KB WebP
- `uri.png` (600 KB) → ~100 KB WebP
- `android-chrome-*.png` (3.8 MB) → Keep as PNG (required for PWA)
- `uriel_favicon.png` (1.27 MB) → Keep or optimize

**Savings:** ~2.5 MB

---

### 3. Implement Progressive Image Loading
**Current:** All images load at once
**Target:** Load images as they enter viewport

```dart
// Use cached_network_image with progressive loading
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => BlurHash(hash: imageHash),
  fadeInDuration: Duration(milliseconds: 300),
  memCacheWidth: 800, // Resize for screen
)
```

**Benefits:**
- 40-60% faster initial paint
- Better perceived performance
- Reduced initial bandwidth

---

### 4. Tree-Shake Unused Dependencies
Run dependency analysis to remove unused code:

```bash
flutter pub deps --style=compact
dart run dependency_validator
```

**Potential removals (if unused):**
- Unused Firebase services
- Extra font weights from google_fonts
- Unused Material Icon variants

**Estimated savings:** 1-2 MB

---

### 5. Enable Flutter Web Optimizations
**In `web/index.html`:**

```html
<!-- Enable CanvasKit for better performance -->
<script>
  window.flutterConfiguration = {
    canvasKitBaseUrl: "https://unpkg.com/canvaskit-wasm@latest/bin/",
    canvasKitVariant: "auto", // Use lighter variant on mobile
    rendererConfig: {
      useColorEmoji: true,
    }
  };
</script>
```

**Or use HTML renderer for smaller size:**
```bash
flutter build web --web-renderer html --release
```
- CanvasKit (current): 15.32 MB WASM
- HTML renderer: 0 MB WASM, uses DOM (smaller but less performant)

---

### 6. Optimize JSON Data
**Current:** 2.77 MB JSON

Options:
a) **Gzip compression** (automatic with Firebase Hosting)
   - Already enabled, reduces by ~70%
   
b) **Load JSON on-demand** instead of bundling
   ```dart
   // Load from Firestore instead of assets
   // Already doing this for questions ✓
   ```

c) **Minify JSON** (remove whitespace)
   - Savings: ~10-20%

---

### 7. Font Optimization
**Current:** Using Google Fonts dynamically

**Optimization:**
```dart
// Only load font weights you actually use
GoogleFonts.inter(
  fontWeight: FontWeight.w400, // Regular only
  // Remove unused: w100, w200, w300, w500, w600, w700, w800, w900
)
```

**Savings:** 0.3-0.5 MB per unused weight

---

### 8. Service Worker Optimization
Enable aggressive caching:

```javascript
// In flutter_service_worker.js configuration
const CACHE_STRATEGY = 'CacheFirst'; // Serve from cache, update in background
const CACHE_MAX_AGE = 86400000; // 24 hours
```

**Benefits:**
- Instant subsequent loads
- Offline support
- Reduced bandwidth costs

---

## Expected Results After All Optimizations

### Before:
- **Total:** 62.53 MB
- **Initial Download:** 25-30 MB
- **Time to Interactive:** 3-5s on 4G

### After:
- **Total:** ~40 MB (36% reduction)
- **Initial Download:** 8-12 MB (60% reduction)
- **Time to Interactive:** 1-2s on 4G (50% faster)

### Breakdown:
- Code splitting: -3.5 MB initial load
- WebP conversions: -2.5 MB
- HTML renderer: -15 MB (optional, loses some features)
- Font optimization: -0.5 MB
- Tree-shaking: -1 MB

---

## Implementation Priority

### Phase 1: Quick Wins (1-2 hours)
1. ✅ Convert remaining PNGs to WebP
2. Enable deferred imports for admin/heavy pages
3. Optimize font loading

### Phase 2: Moderate Effort (2-4 hours)
4. Implement progressive image loading
5. Add BlurHash placeholders
6. Tree-shake dependencies

### Phase 3: Advanced (4+ hours)
7. Consider HTML renderer for smaller builds
8. Implement route-based code splitting
9. Add service worker enhancements

---

## Trade-offs to Consider

### HTML Renderer vs CanvasKit:
- **CanvasKit (current):** 15 MB, perfect rendering, 60fps animations
- **HTML Renderer:** 0 MB, 95% quality, occasional jank on complex UI

**Recommendation:** Keep CanvasKit for now, users prefer quality over 15 MB

### Aggressive Caching vs Fresh Content:
- **Aggressive:** Faster loads, may show stale content
- **Conservative:** Always fresh, slower loads

**Recommendation:** Cache static assets (images, fonts) aggressively, fetch dynamic data (questions, scores) fresh

---

## Monitoring & Validation

### Tools:
1. **Lighthouse:** Run performance audit
2. **WebPageTest:** Real-world load times
3. **Firebase Performance Monitoring:** Track actual user metrics

### Key Metrics:
- First Contentful Paint: Target <1.5s
- Time to Interactive: Target <3s
- Total Blocking Time: Target <300ms
- Cumulative Layout Shift: Target <0.1
