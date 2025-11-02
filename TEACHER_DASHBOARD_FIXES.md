# Teacher Dashboard & Data Model Fixes

## Summary of Changes

### 1. ✅ Student Data Sync Service (COMPLETED)
Created `StudentDataSyncService` that automatically syncs student performance data to `studentSummaries` collection for real-time teacher dashboard updates.

**Features:**
- Auto-sync after quiz completion
- Auto-sync after XP updates
- Bulk sync for all students of a teacher
- Tracks: totalXP, totalQuestions, subjectsCount, avgPercent, rank, rankName

**Files Modified:**
- ✅ `lib/services/student_data_sync_service.dart` (new)
- ✅ `lib/services/xp_service.dart` (added sync call after XP update)
- ✅ `lib/screens/quiz_results_page.dart` (added sync call after quiz save)

**Testing:**
- Add new student to teacher's class
- Have student complete quizzes
- Verify teacher dashboard shows updated XP, questions, rank, subjects immediately

---

### 2. ⚠️ Schema Standardization (IN PROGRESS)

#### A. Notes: `uploaderName` → `authorName` + `authorId`

**Current Issues:**
- `notes_page.dart` uses `authorName` to display
- `note_viewer_page.dart` uses `authorName` to display
- `upload_note_page.dart` sends `uploaderName` (OLD) ❌
- `note_service.dart` uses both `uploaderName` (OLD) and `authorName/authorId` ❌
- `functions/src/index.ts` uploadNote endpoint doesn't store author info ❌

**Required Changes:**

1. ✅ **lib/services/note_service.dart**
   ```dart
   // CHANGED: Line 49
   'authorName': noteData['authorName'] ?? noteData['uploaderName'] ?? '',
   // Backwards compatible with old 'uploaderName' field
   ```

2. ✅ **lib/screens/upload_note_page.dart**
   ```dart
   // CHANGED: Line 105-106
   'authorName': user.displayName ?? 'Anonymous User',
   'authorId': user.uid,
   ```

3. ❌ **functions/src/index.ts** (NEEDS UPDATE)
   ```typescript
   // Line ~1350 in uploadNote function
   // ADD these lines after line 1357:
   const authorName = (body.authorName || '').toString();
   const authorId = uid; // Already available
   
   // ADD to docData (line ~1359):
   docData.authorName = authorName || null;
   docData.authorId = authorId;
   ```

#### B. Users: `schoolName` → `school` (primary) + `schoolName` (deprecated)

**Current Issues:**
- Some code uses `school`, some uses `schoolName`
- Inconsistent field lookups cause mismatches
- Teacher-student matching fails when fields don't align

**Status:** ✅ **ALREADY IMPLEMENTED** in `user_service.dart`
- Lines 238-239: Writes both `school` (primary) and `schoolName` (backwards compat)
- Lines 480-481: Same for student creation
- Normalization functions exist and work correctly

**Recommendation:** No changes needed. System already handles this correctly.

#### C. Message Status Flow

**Current Issues:**
- No status tracking for messages
- Can't tell if message is pending, processing, or completed
- Users don't know if their message was received/processed

**Required Implementation:**

1. ❌ Create enum in `lib/models/enums.dart`:
   ```dart
   enum MessageStatus {
     pending,
     processing,
     completed,
     failed
   }
   ```

2. ❌ Update message creation in Cloud Functions:
   ```typescript
   // functions/src/index.ts - wherever messages are created
   messageData.status = 'pending';
   messageData.createdAt = admin.firestore.FieldValue.serverTimestamp();
   ```

3. ❌ Add Cloud Function trigger to update status:
   ```typescript
   export const updateMessageStatus = functions.firestore
     .document('messages/{messageId}')
     .onCreate(async (snap, context) => {
       // Mark as processing
       await snap.ref.update({ status: 'processing', processingStartedAt: admin.firestore.FieldValue.serverTimestamp() });
       
       try {
         // Do message processing here
         
         // Mark as completed
         await snap.ref.update({ status: 'completed', completedAt: admin.firestore.FieldValue.serverTimestamp() });
       } catch (error) {
         // Mark as failed
         await snap.ref.update({ status: 'failed', failedAt: admin.firestore.FieldValue.serverTimestamp(), error: error.message });
       }
     });
   ```

---

## Migration Plan

### Phase 1: Backend Fixes (Cloud Functions)

1. **Update `functions/src/index.ts`**
   - Add `authorName` and `authorId` to uploadNote endpoint
   - Ensure backwards compatibility for old notes

2. **Deploy functions:**
   ```bash
   cd functions
   npm install
   npm run build
   firebase deploy --only functions:uploadNote
   ```

### Phase 2: Flutter App Build

1. **Build and deploy updated Flutter app:**
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

### Phase 3: Data Migration (Optional)

If you want to backfill `authorName` for old notes that have `uploaderName`:

```javascript
// migration_script.js
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateNoteAuthorship() {
  console.log('🔄 Migrating note authorship fields...\n');

  const notesSnapshot = await db.collection('notes')
    .where('uploaderName', '!=', null)
    .get();

  console.log(`Found ${notesSnapshot.size} notes with uploaderName field`);

  let migratedCount = 0;
  const batch = db.batch();

  for (const doc of notesSnapshot.docs) {
    const data = doc.data();
    
    // Only migrate if authorName doesn't exist
    if (!data.authorName && data.uploaderName) {
      batch.update(doc.ref, {
        authorName: data.uploaderName,
        // Keep userId as authorId (already exists)
        authorId: data.userId || null
      });
      migratedCount++;
    }

    // Commit in batches of 500
    if (migratedCount > 0 && migratedCount % 500 === 0) {
      await batch.commit();
      console.log(`Migrated ${migratedCount} notes...`);
    }
  }

  // Commit remaining
  if (migratedCount % 500 !== 0) {
    await batch.commit();
  }

  console.log(`\n✅ Migration complete: ${migratedCount} notes migrated`);
  process.exit(0);
}

migrateNoteAuthorship();
```

Run with:
```bash
node migration_script.js
```

---

## Testing Checklist

### Teacher Dashboard Sync
- [ ] Add a new student to Ave Maria School, JHS 1
- [ ] Have student complete 3 quizzes
- [ ] Verify teacher dashboard shows:
  - [ ] Correct XP
  - [ ] Correct question count
  - [ ] Correct rank (calculated from XP)
  - [ ] Correct subjects count
- [ ] Have student complete another quiz
- [ ] Refresh teacher dashboard - verify data updates automatically

### Notes Schema
- [ ] Upload a new note as a student
- [ ] Verify note has `authorName` and `authorId` in Firestore
- [ ] View note in notes page - verify author name displays
- [ ] Like note - verify `authorName` appears in My Notes
- [ ] Check old notes (with `uploaderName`) still display correctly

### School Name Consistency
- [ ] Create teacher with "Ave Maria School"
- [ ] Create student with "Ave Maria School" (exact match)
- [ ] Verify teacher can see student in dashboard
- [ ] Create student with "Ave Maria" (variant)
- [ ] Verify normalization still matches them correctly

---

## Deployment Commands

```bash
# 1. Deploy Cloud Functions (if updated)
cd functions
npm run build
firebase deploy --only functions

# 2. Build and deploy Flutter web app
cd ..
flutter build web --release
firebase deploy --only hosting

# 3. Run data migration (optional)
node migration_script.js

# 4. Verify deployment
# Visit https://uriel-academy-41fb0.web.app
# Test teacher dashboard
# Test student quiz → verify teacher sees update
```

---

## Remaining Tasks

### High Priority
1. ❌ Update `functions/src/index.ts` uploadNote to store `authorName` and `authorId`
2. ❌ Deploy Cloud Functions
3. ✅ Test student data sync with new quizzes (already integrated)

### Medium Priority
4. ❌ Implement message status flow (pending → processing → completed/failed)
5. ❌ Run data migration script for old notes (optional)

### Low Priority
6. ❌ Create admin panel to manually trigger bulk student sync
7. ❌ Add monitoring for sync failures
8. ❌ Add retry logic for failed syncs

---

## Architecture Notes

### Student Data Flow
```
Student Completes Quiz
    ↓
quiz_results_page.dart (_saveQuizResult)
    ↓
XPService.calculateAndSaveQuizXP()
    ↓
XPService._updateUserTotalXP()
    ↓
StudentDataSyncService.syncStudentData()
    ↓
Update studentSummaries/{studentId}
    ↓
Teacher Dashboard Reads studentSummaries via getClassAggregates API
```

### Key Collections
- `users` - Source of truth for user XP, rank, profile
- `quizzes` - All completed quizzes
- `studentSummaries` - Aggregated student data for teachers (updated by sync service)
- `leaderboardRanks` - XP → Rank mapping
- `notes` - Uploaded study notes

### Indexing Requirements
Ensure these Firestore indexes exist:
- `studentSummaries`: `teacherId` ASC + `totalXP` DESC
- `studentSummaries`: `normalizedSchool` ASC + `normalizedClass` ASC
- `quizzes`: `userId` ASC + `timestamp` DESC

---

## Support & Troubleshooting

### Student Not Appearing in Teacher Dashboard
1. Check student has `teacherId` field set
2. Check `school` and `grade` match teacher's `school` and `teachingGrade`
3. Check `studentSummaries` collection has entry for student
4. Run manual sync: `StudentDataSyncService().syncStudentData(studentId)`

### XP Not Updating
1. Check student completed quiz successfully
2. Check `xp_transactions` collection for XP award
3. Check `users/{studentId}.totalXP` updated
4. Check `studentSummaries/{studentId}.totalXP` updated
5. Manually trigger sync if needed

### Notes Not Showing Author
1. Check note document has `authorName` or `uploaderName` field
2. Check `authorId` or `userId` field exists
3. Run migration script if old notes missing `authorName`
