# Firestore Cache Corruption Fix

## Problem
Users experiencing critical errors like:
```
FIRESTORE (11.9.1) INTERNAL ASSERTION FAILED: Unexpected state (ID: ca9)
FIRESTORE (11.9.1) INTERNAL ASSERTION FAILED: Unexpected state (ID: b815)
```

These errors indicate Firestore client cache corruption, preventing normal database operations.

## Root Cause
- Firestore uses IndexedDB in the browser to cache data offline
- Cache can become corrupted during:
  - Security rules updates
  - App deployments while user is active
  - Network interruptions during synchronization
  - Browser crashes or forced closures

## Solution: Clear Browser Cache

### For Students/Users (Chrome/Edge):

1. **Option A: Hard Refresh (Quick Fix)**
   - Windows: `Ctrl + Shift + Delete`
   - Mac: `Cmd + Shift + Delete`
   - Select "Cached images and files" and "Site settings"
   - Click "Clear data"

2. **Option B: Developer Tools (Complete Fix)**
   - Press `F12` to open Developer Tools
   - Go to **Application** tab
   - In left sidebar, expand **Storage**
   - Right-click **IndexedDB** → Select **Clear**
   - Right-click **Cache Storage** → Select **Clear**
   - Close Developer Tools
   - **Hard refresh**: `Ctrl + Shift + R` (Windows) or `Cmd + Shift + R` (Mac)

3. **Option C: Clear Site Data (Most Thorough)**
   - Click lock icon (🔒) in address bar
   - Click **Site settings**
   - Scroll down and click **Clear data**
   - Confirm
   - Reload the page

### For Developers:

1. **Clear Firestore Persistence**
   ```javascript
   // In browser console
   await firebase.firestore().clearPersistence();
   location.reload();
   ```

2. **Disable Offline Persistence (Temporary Testing)**
   ```dart
   // In Flutter initialization
   FirebaseFirestore.instance.settings = Settings(
     persistenceEnabled: false,
   );
   ```

3. **Check for Rules Changes**
   - Run: `firebase deploy --only firestore:rules`
   - Verify no conflicts between cached data and new rules

## Prevention

1. **For Users:**
   - Close app before major updates
   - Use "Sign Out" instead of closing browser tab
   - Enable browser auto-updates

2. **For Developers:**
   - Test rule changes in staging first
   - Use versioning for breaking changes
   - Implement graceful cache invalidation:
     ```dart
     try {
       // Firestore operation
     } catch (e) {
       if (e.toString().contains('INTERNAL ASSERTION FAILED')) {
         // Show user-friendly message to clear cache
         showCacheClearDialog();
       }
     }
     ```

## What Happens After Clearing Cache?

- ✅ Fresh data loaded from Firestore servers
- ✅ Cache rebuilt with current security rules
- ✅ Normal operations resume
- ⚠️ First load may be slower (rebuilding cache)
- ⚠️ Offline functionality temporarily unavailable until cache rebuilds

## Still Having Issues?

1. **Try Incognito/Private Mode**
   - Tests if issue is cache-related
   - Won't affect your saved cache

2. **Update Browser**
   - Outdated browsers may have Firebase SDK bugs
   - Chrome/Edge recommended (best Firebase support)

3. **Check Console Logs**
   - Look for specific collection names in permission-denied errors
   - May indicate Firestore rules issues (not cache)

4. **Contact Support**
   - Provide browser version
   - Include console error logs
   - Specify actions that trigger errors

## Recent Fixes Applied

### December 6, 2025
- ✅ Added Firestore rules for `studyPlans` collection
- ✅ Added Firestore rules for `categoryStats` collection
- ✅ Added Firestore rules for `telemetry` collection
- ✅ Fixed permission-denied errors for students
- ✅ Deployed updated security rules

If you're seeing permission errors after these fixes, clear your cache to sync with new rules.
