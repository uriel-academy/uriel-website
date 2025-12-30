# Performance & PWA Implementation Guide

## Overview
This document outlines the performance monitoring and Progressive Web App (PWA) features implemented to optimize Uriel Academy's web application.

## 🚀 Performance Monitoring

### PerformanceService
Location: `lib/services/performance_service.dart`

**Features:**
- Screen view tracking
- Operation timing with automatic bottleneck detection
- Firestore query performance monitoring
- Network request tracking
- Error and exception logging
- Memory warning detection
- Custom event tracking

**Usage Example:**
```dart
final perf = PerformanceService();

// Track screen views
await perf.trackScreen('QuizPage');

// Measure operation performance
perf.startTimer('quiz_generation');
// ... perform operation
await perf.endTimer('quiz_generation');

// Track Firestore queries
final startTime = DateTime.now();
final snapshot = await FirebaseFirestore.instance.collection('questions').get();
final duration = DateTime.now().difference(startTime);
await perf.trackFirestoreQuery('questions', snapshot.docs.length, duration.inMilliseconds);

// Track user actions
await perf.trackAction('quiz_completed', parameters: {
  'score': 85,
  'questions': 20,
});

// Track errors
await perf.trackError('ApiError', 'Failed to fetch questions', stackTrace: stackTrace);
```

### TrackedRoute Widget
Location: `lib/widgets/tracked_route.dart`

Automatically tracks screen views and user engagement time.

**Usage:**
```dart
// Method 1: Wrap widget directly
TrackedRoute(
  screenName: 'HomePage',
  child: HomePage(),
)

// Method 2: Use extension
HomePage().tracked('HomePage')
```

### Automatic Bottleneck Detection
- Operations taking >3 seconds trigger automatic bottleneck alerts
- Firestore queries taking >2 seconds are logged as warnings
- Network requests taking >5 seconds are flagged

## 📱 Progressive Web App (PWA)

### Service Worker
Location: `web/sw.js`

**Caching Strategies:**

1. **Images (Cache First)**
   - Images cached immediately on first load
   - Subsequent loads served from cache
   - Dramatically improves performance

2. **Static Assets (Cache First with Background Update)**
   - Fonts, icons, CSS served from cache
   - Updated in background when available
   - Best of both worlds: speed + freshness

3. **Dynamic Content (Network First)**
   - HTML, API responses prioritize network
   - Falls back to cache when offline
   - Ensures latest data when online

**Cache Management:**
- Maximum 50 items per cache category
- Automatic cleanup of items older than 7 days
- Manual cache clearing supported

### Offline Support
- Custom offline page at `web/offline.html`
- Graceful degradation when network unavailable
- User-friendly offline messaging

### Service Worker Registration
Automatically registered in `web/index.html`:
```javascript
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js')
    .then(registration => console.log('SW registered'))
    .catch(error => console.log('SW registration failed'));
}
```

## 🎯 Build Optimizations

### Optimized Build Script
Location: `build_optimized.ps1`

Run with: `.\build_optimized.ps1`

**Optimizations Applied:**
- HTML renderer (smaller than CanvasKit)
- Tree shaking for icons (97-99% size reduction)
- No source maps in production
- Dart2JS optimization level O4
- Deferred loading for admin/teacher modules

**Expected Results:**
- Build time: 60-90 seconds (down from 170s)
- Bundle size: Reduced by 30-40%
- Initial load: Faster due to code splitting

### Manual Build Command
```powershell
flutter build web --release \
  --web-renderer html \
  --tree-shake-icons \
  --no-source-maps \
  --dart2js-optimization O4 \
  --pwa-strategy none
```

## 📊 Analytics Dashboard

View performance data in Firebase Console:
1. Go to Firebase Console → Analytics → Events
2. Custom events to monitor:
   - `performance_timing` - Operation durations
   - `bottleneck_detected` - Slow operations
   - `firestore_query` - Database performance
   - `network_request` - API performance
   - `app_error` - Error tracking
   - `screen_duration` - User engagement

## 🔍 Monitoring Bottlenecks

### Critical Metrics to Watch

**App Startup:**
- Target: <2 seconds
- Alert if: >3 seconds
- Event: `app_startup`

**Screen Load Times:**
- Target: <1 second
- Alert if: >2 seconds
- Event: `performance_timing` with `timer_name: screen_load_*`

**Firestore Queries:**
- Target: <500ms
- Alert if: >2 seconds
- Event: `firestore_query` with `is_slow: true`

**Network Requests:**
- Target: <2 seconds
- Alert if: >5 seconds
- Event: `network_request` with `is_slow: true`

## 💡 Best Practices

### When to Use Performance Tracking

**DO track:**
- Screen navigation
- Heavy computations
- Database queries
- Network requests
- User actions (quiz completion, answer submission)
- Error conditions

**DON'T track:**
- Simple UI state changes
- Rapid-fire events (typing, scrolling)
- Sensitive user data
- Every single widget build

### PWA Best Practices

**Cache Aggressively:**
- Images and fonts (rarely change)
- Static assets
- Question banks (large, infrequent updates)

**Network Aggressively:**
- User data
- Leaderboards
- Real-time features
- Authentication

**Don't Cache:**
- Firebase API calls
- Google Sign-In
- Dynamic user content

## 🚦 Deployment Checklist

Before deploying to production:

1. ✅ Run optimized build: `.\build_optimized.ps1`
2. ✅ Verify service worker registered (check browser console)
3. ✅ Test offline functionality (disconnect network)
4. ✅ Check bundle size is reasonable (<15MB)
5. ✅ Verify analytics tracking (Firebase Console)
6. ✅ Test on mobile devices
7. ✅ Run Lighthouse audit (target: 90+ performance score)

## 📈 Expected Improvements

### Before Optimization:
- Build time: 170 seconds
- Bundle size: ~20MB
- No offline support
- No performance monitoring
- Limited PWA features

### After Optimization:
- Build time: **60-90 seconds (47% faster)**
- Bundle size: **12-14MB (30% smaller)**
- Full offline support: **✅**
- Performance monitoring: **✅**
- Installable PWA: **✅**

### Scalability Improvements:
- Concurrent users: **100-300** (from 50-100)
- Lighthouse Performance: **90+** (from 70-80)
- First Contentful Paint: **<2s** (from 3-4s)
- Time to Interactive: **<3s** (from 5-6s)

## 🛠️ Troubleshooting

### Service Worker Not Registering
- Check browser console for errors
- Ensure HTTPS or localhost
- Clear browser cache
- Verify `sw.js` is accessible at root

### Performance Data Not Showing
- Check Firebase Analytics dashboard (24hr delay for some events)
- Verify Firebase Analytics initialized in `main.dart`
- Check browser console for errors

### Build Taking Too Long
- Run `flutter clean` first
- Ensure using optimized build script
- Check for large assets that could be optimized
- Consider upgrading machine RAM

## 📚 Additional Resources

- [Flutter Web Performance Best Practices](https://docs.flutter.dev/perf/web-performance)
- [Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [PWA Checklist](https://web.dev/pwa-checklist/)

## 🎓 Next Steps

1. Monitor analytics for 1 week to establish baseline
2. Identify top 3 bottlenecks from data
3. Optimize those specific areas
4. Implement lazy loading for images
5. Consider CDN for static assets
6. Set up performance budgets in CI/CD

---

**Last Updated:** December 30, 2025  
**Maintainer:** Development Team
