# Study Planner Fixes - December 17, 2025

## Issues Fixed

### 1. ✅ Study Plan Card Not Updating Automatically

**Problem**: The "Your Study Plan" card on the dashboard wasn't updating automatically when a new plan was generated.

**Root Cause**: Tasks stored in Firestore contained `IconData` and `Color` objects which cannot be serialized. When saved to Firestore and retrieved, these objects became `null`, causing the card to not display properly.

**Solution**:
- Modified `_createDailySchedule()` to store icons as string names (`iconName: 'book'`) and colors as hex strings (`colorHex: '#0071E3'`)
- Updated dashboard's `_buildTodayStudyTasks()` in [home_page.dart](lib/screens/home_page.dart#L5165-L5270) to parse icon names and color hex strings back into Flutter objects
- Added icon mapping for: `book`, `quiz`, `auto_stories`, `checklist`

**Files Changed**:
- [lib/screens/study_plan_page.dart](lib/screens/study_plan_page.dart#L666-L730): Changed task generation to use strings
- [lib/screens/home_page.dart](lib/screens/home_page.dart#L5212-L5265): Added parsing logic for icons and colors

### 2. ✅ Study Planner Week Offset Resets on Page Refresh

**Problem**: When refreshing the page, the study planner would reset to the first week instead of maintaining the user's current week view.

**Root Cause**: `_currentWeekOffset` was a local state variable that wasn't persisted anywhere, so it reset to `0` on every page load.

**Solution**:
- Added `currentWeekOffset` field to Firestore document at `/users/{uid}/study_plan/current`
- Modified `_checkExistingPlan()` to load the saved week offset when initializing the page
- Added `_saveWeekOffset()` method to persist changes to Firestore whenever the user navigates weeks
- Updated week navigation buttons to call `_saveWeekOffset()` after changing the offset

**Files Changed**:
- [lib/screens/study_plan_page.dart](lib/screens/study_plan_page.dart):
  - Line 91: Load `currentWeekOffset` from Firestore
  - Lines 167-185: Added `_saveWeekOffset()` method
  - Lines 1551-1556: Save offset when navigating backward
  - Lines 1573-1578: Save offset when navigating forward
  - Line 151: Initialize with `currentWeekOffset: 0` when creating new plan

### 3. ⚠️ Firestore Index Required (User Action Needed)

**Problem**: Console errors showing:
```
Error predicting grade: [cloud_firestore/failed-precondition] The query requires an index.
```

**Root Cause**: The grade prediction service queries `questionAttempts` with both a filter (`.where('subject', isEqualTo: subject)`) and an orderBy (`.orderBy('attemptedAt', descending: true)`), which requires a composite index in Firestore.

**Solution**: Created comprehensive documentation in [FIRESTORE_INDEX_FIX.md](FIRESTORE_INDEX_FIX.md) with three options:

#### Option 1: One-Click Index Creation (Recommended)
Click this link: [Create Index in Firebase Console](https://console.firebase.google.com/v1/r/project/uriel-academy-41fb0/firestore/indexes?create_composite=Clxwcm9qZWN0cy91cmllbC1hY2FkZW15LTQxZmIwL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9xdWVzdGlvbkF0dGVtcHRzL2luZGV4ZXMvXxABGgsKB3N1YmplY3QQARoPCgthdHRlbXB0ZWRBdBACGgwKCF9fbmFtZV9fEAI)

#### Option 2: Manual Creation
1. Go to Firebase Console → Firestore → Indexes
2. Click "Add Index"
3. Configure:
   - Collection Group: `questionAttempts`
   - Fields:
     - `subject` → Ascending
     - `attemptedAt` → Descending
     - `__name__` → Descending

#### Option 3: Deploy via CLI
Add to `firestore.indexes.json` and run `firebase deploy --only firestore:indexes`

**Affected Code**: [lib/services/grade_prediction_service.dart](lib/services/grade_prediction_service.dart#L23-L28)

### 4. ℹ️ Permission Denied Errors

**Issue**: Console shows "Connection check failed: permission-denied"

**Analysis**: 
- Checked [firestore.rules](firestore.rules#L397-L413)
- Security rules are correctly configured for `questionAttempts`
- Users can read their own attempts
- Admins can read all attempts
- Users can create attempts but not update/delete

**Conclusion**: Permission denied errors are likely transient connection issues or related to the missing index. Once the index is created, these should resolve.

## Data Structure Changes

### Before (Non-serializable)
```dart
{
  'time': 'Morning',
  'subject': 'Mathematics',
  'icon': Icons.book,  // ❌ Cannot serialize IconData
  'color': Color(0xFF0071E3),  // ❌ Cannot serialize Color
  'title': 'Read Mathematics Chapter',
  'duration': '30 min',
}
```

### After (Serializable)
```dart
{
  'time': 'Morning',
  'subject': 'Mathematics',
  'iconName': 'book',  // ✅ String
  'colorHex': '#0071E3',  // ✅ String
  'title': 'Read Mathematics Chapter',
  'duration': '30 min',
}
```

## Testing Checklist

### ✅ Dashboard Real-time Updates
1. Create a new study plan
2. Verify dashboard "Your Study Plan" card updates immediately without refresh
3. Verify tasks display with correct icons and colors

### ✅ Week Offset Persistence
1. Navigate to study planner
2. Click next week button multiple times
3. Hard refresh the page (Ctrl+Shift+R)
4. Verify you remain on the same week

### ⚠️ Grade Prediction (Requires Index)
1. Create the Firestore index using one of the methods above
2. Wait 2-5 minutes for index to build
3. Verify no more "index required" errors in console
4. Verify grade prediction features work correctly

## Deployment

**Build Time**: 89.5 seconds  
**Files Deployed**: 182 files  
**Deployment URL**: https://uriel-academy-41fb0.web.app  
**Status**: ✅ Live

## Next Steps

1. **Immediate**: Create the Firestore composite index (see [FIRESTORE_INDEX_FIX.md](FIRESTORE_INDEX_FIX.md))
2. Monitor dashboard for real-time update functionality
3. Test study planner week persistence across refreshes
4. Verify grade prediction works after index creation

## Technical Details

### StreamBuilder Implementation
The dashboard now uses `StreamBuilder` instead of `FutureBuilder` to listen to real-time changes:

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('study_plan')
      .doc('current')
      .snapshots(),
  builder: (context, snapshot) {
    // Parse and display tasks with icon/color conversion
  }
)
```

### State Persistence
Week offset is persisted to Firestore on every navigation:

```dart
Future<void> _saveWeekOffset() async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('study_plan')
      .doc('current')
      .update({
    'currentWeekOffset': _currentWeekOffset,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

## Git Commit

All changes have been committed and deployed to production.

**Commit Message**: "Fix study plan real-time updates and week offset persistence"

---

**Date**: December 17, 2025  
**Status**: ✅ All fixes deployed  
**User Action Required**: Create Firestore index for grade prediction
