# Firestore Index Fix for Grade Prediction

## Issue
The grade prediction feature requires a composite index for the `questionAttempts` collection. The error occurs because the query filters by `subject` and orders by `attemptedAt`.

## Error Message
```
Error predicting grade: [cloud_firestore/failed-precondition] The query requires an index.
```

## Solution

### Option 1: Automatic Index Creation (Recommended)
1. Click this link (from the error message):
   ```
   https://console.firebase.google.com/v1/r/project/uriel-academy-41fb0/firestore/indexes?create_composite=Clxwcm9qZWN0cy91cmllbC1hY2FkZW15LTQxZmIwL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9xdWVzdGlvbkF0dGVtcHRzL2luZGV4ZXMvXxABGgsKB3N1YmplY3QQARoPCgthdHRlbXB0ZWRBdBACGgwKCF9fbmFtZV9fEAI
   ```
2. This will open Firebase Console with the index pre-configured
3. Click "Create Index"
4. Wait 2-5 minutes for the index to build

### Option 2: Manual Index Creation
1. Go to [Firebase Console](https://console.firebase.google.com/project/uriel-academy-41fb0/firestore/indexes)
2. Click "Add Index"
3. Configure the index:
   - **Collection Group ID**: `questionAttempts`
   - **Fields to index**:
     1. `subject` → Ascending
     2. `attemptedAt` → Descending
     3. `__name__` → Descending
   - **Query scope**: Collection group
4. Click "Create"

### Option 3: Add to firestore.indexes.json
Add this to your `firestore.indexes.json` file:

```json
{
  "indexes": [
    {
      "collectionGroup": "questionAttempts",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {
          "fieldPath": "subject",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "attemptedAt",
          "order": "DESCENDING"
        },
        {
          "fieldPath": "__name__",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

Then deploy:
```bash
firebase deploy --only firestore:indexes
```

## Affected Code
**File**: `lib/services/grade_prediction_service.dart`  
**Lines**: 23-28

```dart
final attemptsSnapshot = await _firestore
    .collection('users')
    .doc(userId)
    .collection('questionAttempts')
    .where('subject', isEqualTo: subject)
    .orderBy('attemptedAt', descending: true)
    .limit(500)
    .get();
```

## Why This Index is Needed
Firestore requires a composite index when:
1. You filter by one or more fields (`.where()`)
2. AND order by a different field (`.orderBy()`)

This is because Firestore needs to efficiently look up documents matching the filter criteria AND return them in the specified order.

## Alternative Solution (If Index Creation Fails)
If you cannot create the index, you can modify the query to remove the orderBy and sort in memory:

```dart
// Fetch without orderBy
final attemptsSnapshot = await _firestore
    .collection('users')
    .doc(userId)
    .collection('questionAttempts')
    .where('subject', isEqualTo: subject)
    .limit(500)
    .get();

// Sort in memory
final attempts = attemptsSnapshot.docs
    .map((doc) => QuestionAttempt.fromMap(doc.data()))
    .toList()
  ..sort((a, b) => b.attemptedAt.compareTo(a.attemptedAt)); // Sort descending
```

However, this is less efficient for large datasets, so creating the index is preferred.

## Status
⚠️ **Action Required**: Create the composite index using one of the methods above.

Once the index is created, the grade prediction feature will work without errors.
