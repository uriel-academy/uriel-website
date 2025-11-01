# Student-Teacher Aggregation System Documentation

## Overview
This document describes the complete student-teacher aggregation system that enables teachers to view aggregated performance metrics for all students in their class.

## Architecture

### Database Collections

#### 1. `users` Collection
Stores user profiles with the following key fields:
- `firstName`: string
- `lastName`: string
- `email`: string
- `school`: string (e.g., "Ave Maria School")
- `schoolName`: string (legacy compatibility)
- `class`: string (e.g., "Form 1", "JHS 3")
- `grade`: string (legacy compatibility, same as class)
- `role`: "student" | "teacher"
- `teachingGrade`: string (for teachers only)

#### 2. `studentSummaries` Collection
Document ID: `{uid}`
Materialized per-student aggregates:
```typescript
{
  totalXP: number,
  avgPercent: number,
  questionsSolved: number,
  subjectsCount: number,
  normalizedSchool: string,  // e.g., "ave_maria"
  normalizedClass: string,   // e.g., "form_1"
  lastUpdated: Timestamp
}
```

#### 3. `classAggregates` Collection
Document ID: `{normalizedSchool}_{normalizedClass}` (e.g., "ave_maria_form_1")
Materialized class-level aggregates:
```typescript
{
  totalStudents: number,
  totalXP: number,
  avgScorePercent: number,
  totalQuestions: number,
  totalSubjects: number,
  lastUpdated: Timestamp
}
```

#### 4. `attempts` Collection
Stores individual quiz attempts, triggers aggregation updates

#### 5. `quizzes` Collection
Stores quiz completion records

## School/Class Normalization

The system uses **fuzzy matching** to group students by school and class, even if they enter slightly different spellings.

### Normalization Algorithm
```typescript
function normalizeSchoolClass(text: string): string {
  // 1. Lowercase
  let normalized = text.toLowerCase();
  
  // 2. Strip noise words: school, college, high, senior, basic, the, etc.
  normalized = normalized.replaceAll(/\b(school|college|high|senior|basic|primary|jhs|shs|the)\b/g, ' ');
  
  // 3. Replace non-alphanumeric with spaces
  normalized = normalized.replaceAll(/[^a-z0-9\s]/g, ' ');
  
  // 4. Collapse whitespace
  normalized = normalized.replaceAll(/\s+/g, ' ').trim();
  
  // 5. Use underscore-delimited tokens
  return normalized.replaceAll(' ', '_');
}
```

### Examples
- "Ave Maria School" → "ave_maria"
- "St. John's High School" → "st_john"
- "Form 1" → "form_1"
- "JHS 3" → "3"

## Cloud Functions

### 1. `getClassAggregates` (Callable)
**Purpose**: Retrieves paginated list of students with aggregated metrics

**Parameters**:
```typescript
{
  teacherId?: string,      // Auto-fetch teacher's school/grade
  school?: string,         // Or specify manually
  grade?: string,          // Or specify manually
  pageSize?: number,       // Default: 50
  pageCursor?: string,     // For pagination
  includeCount?: boolean   // Total count (slower)
}
```

**Returns**:
```typescript
{
  ok: true,
  students: Array<{
    uid: string,
    name: string,
    email: string,
    school: string,
    class: string,
    totalXP: number,
    avgScorePercent: number,
    questionsSolved: number,
    subjectsCount: number,
    rank: number
  }>,
  classAggregate: {
    totalStudents: number,
    totalXP: number,
    avgScorePercent: number,
    // ...
  },
  nextCursor?: string,
  totalCount?: number
}
```

### 2. `onAttemptCreate_updateAggregates` (Firestore Trigger)
**Purpose**: Real-time aggregation updates when students complete quizzes

**Trigger**: `attempts/{attemptId}` onCreate
**Actions**:
1. Calculate student's aggregates (XP, avgScore, questionsSolved, subjects)
2. Update `studentSummaries/{uid}`
3. Recalculate class aggregate for the student's school+class
4. Update `classAggregates/{normalizedSchool}_{normalizedClass}`

### 3. `backfillClassAggregates` (Callable, Admin Only)
**Purpose**: Batch process all users to populate aggregates

**Returns**:
```typescript
{
  ok: true,
  processedStudents: number,
  classAggregates: number,
  errors: number
}
```

### 4. `backfillClassPage` (Callable, Admin Only)
**Purpose**: Paginated backfill with progress tracking

**Parameters**:
```typescript
{
  pageSize?: number,  // Default: 500
  lastUid?: string    // For resuming
}
```

**Returns**:
```typescript
{
  ok: true,
  processedCount: number,
  nextCursor?: string,
  hasMore: boolean
}
```

## Flutter Integration

### Service: `ClassAggregatesService`
Location: `lib/services/class_aggregates_service.dart`

#### Key Methods:

```dart
// Get class aggregates with student list
Future<Map<String, dynamic>?> getClassAggregates({
  String? teacherId,
  String? school,
  String? grade,
  int pageSize = 50,
  String? pageCursor,
  bool includeCount = false,
});

// Get class aggregate document directly
Future<Map<String, dynamic>?> getClassAggregateDoc({
  required String school,
  required String grade,
});

// Run backfill (admin only)
Future<Map<String, dynamic>?> backfillClassAggregates();

// Stream class aggregate updates
Stream<Map<String, dynamic>?> streamClassAggregate({
  required String school,
  required String grade,
});

// Calculate performance metrics
Map<String, dynamic> calculatePerformanceMetrics(Map<String, dynamic> classData);
```

### Service: `UserService`
Location: `lib/services/user_service.dart`

#### Updated Method:
```dart
Future<void> storeStudentData({
  required String uid,
  required String name,  // Will be parsed into firstName/lastName
  required String email,
  required String school,
  required String grade,  // Same as class
});
```

**Implementation Details**:
- Parses `name` into `firstName` and `lastName`
- Stores both `school` and `schoolName` (compatibility)
- Stores both `class` and `grade` (compatibility)
- Used during student registration/onboarding

## Teacher Dashboard Metrics

Teachers can view 8 aggregated metrics for their class:

### 1. Progress Overview
- Average XP across all students
- Total questions solved by class

### 2. Subject Mastery
- Number of unique subjects engaged
- Subject-level performance breakdown

### 3. Overall Performance
- Class average score percentage
- Performance distribution (high/medium/low performers)

### 4. BECE Past Questions
- Total BECE questions attempted
- BECE-specific performance metrics

### 5. Performance Analytics
- Trending performance over time
- Strengths and weaknesses by topic

### 6. Weekly Activity
- Active students this week
- Quiz completion rates

### 7. Trivia Performance
- Trivia engagement metrics
- Trivia accuracy rates

### 8. Quick Stats
- Total students
- Average questions per student
- Most improved students

## Student Detail View

When a teacher clicks on a student from the Students page, they should see the student's **personal dashboard** with the same 8 metrics calculated for that individual student.

### Implementation Approach:
- Option A: Navigate to student's actual dashboard (requires permissions)
- Option B: Create a dialog/modal showing student summary from `studentSummaries/{uid}`
- Option C: Create a dedicated "Student Detail" page for teachers

## UI Components to Create

### 1. Teacher Home Page (`lib/pages/teacher/teacher_home_page.dart`)
**Requirements**:
- Replicate student's home page structure
- **Remove**: Questions tab, Revision tab, Leaderboards tab
- **Keep**: Home tab, Students tab, Profile tab
- Display 8 aggregated dashboard metrics
- Fetch data from `ClassAggregatesService.getClassAggregates()`
- Use teacher's `school` and `teachingGrade` to filter

### 2. Students Page (`lib/pages/teacher/students_page.dart`)
**Requirements**:
- List all students in teacher's class
- Columns: Name, Email, XP, Rank, Subjects, Questions Solved
- Click on student → open dialog or navigate to student detail view
- Paginated list (50 students per page)
- Pull-to-refresh to update data

### 3. Student Detail Dialog/Page
**Requirements**:
- Display student's 8 personal metrics
- Fetch from `studentSummaries/{uid}`
- Same visual structure as teacher dashboard but for individual student

## Setup Instructions

### 1. Deploy Cloud Functions
```bash
cd c:\uriel_mainapp\functions
npm run build
firebase deploy --only functions
```

### 2. Run Backfill (One-time)
```bash
firebase functions:call backfillClassAggregates
```

Or use paginated backfill:
```bash
firebase functions:call backfillClassPage
```

### 3. Update Student Registration
Ensure all new students provide:
- Full name (will be parsed into firstName/lastName)
- Email
- School name
- Class/Grade

The `UserService.storeStudentData()` method handles this automatically.

### 4. Test Aggregation
1. Have a student complete a quiz
2. Check `studentSummaries/{uid}` - should update automatically
3. Check `classAggregates/{school}_{class}` - should update automatically
4. Call `getClassAggregates` as a teacher - should see updated metrics

## Troubleshooting

### Students not showing up in teacher's class list
- Verify student's `school` and `class` fields are set
- Check normalization: run `normalizeSchoolClass(school)` and `normalizeSchoolClass(class)` to see expected classId
- Verify classAggregate document exists: `classAggregates/{normalizedSchool}_{normalizedClass}`

### Aggregates not updating
- Check Firestore trigger logs for `onAttemptCreate_updateAggregates`
- Verify `attempts` documents are being created when quizzes complete
- Run backfill to force recalculation

### Teacher can't see any students
- Verify teacher's `school` and `teachingGrade` fields are set
- Check that students exist in the same normalized school+class
- Try calling `getClassAggregates` with explicit `school` and `grade` parameters

## Next Steps

1. ✅ Create `ClassAggregatesService` (completed)
2. ⏳ Deploy updated Cloud Functions (in progress)
3. ⏳ Run backfill to populate aggregates
4. ⏳ Test ICT questions import
5. ⏳ Create teacher home page UI
6. ⏳ Create/update students page UI
7. ⏳ Create student detail dialog
8. ⏳ Update AI system prompt (deferred task)

## Security Considerations

- Only teachers can view class aggregates (enforce in Firestore rules)
- Only admins can run backfill functions
- Students can only see their own `studentSummaries` document
- Teacher can only see aggregates for their own school+class

## Performance Optimization

- Aggregates are materialized (pre-calculated) for fast reads
- Real-time updates via Firestore triggers
- Pagination for large class lists
- Firestore indexes required on:
  - `users`: `normalizedSchool`, `normalizedClass`, `role`
  - `studentSummaries`: `normalizedSchool`, `normalizedClass`
  - `attempts`: `userId`, `createdAt`

## Future Enhancements

- Add filtering by subject, date range
- Export class performance reports (PDF/CSV)
- Send weekly email reports to teachers
- Compare class performance across schools
- Track individual student progress over time
- Add more granular topic-level analytics
