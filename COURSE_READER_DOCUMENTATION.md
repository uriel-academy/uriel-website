# 📚 Uriel Academy Course Reader System

## Overview
Complete Apple-inspired textbook/course reader system with elegant design, progress tracking, and XP integration.

## 📁 File Structure

```
lib/
  models/
    course_models.dart          ✅ Created
  services/
    course_reader_service.dart  ✅ Created
  screens/
    course_library_page.dart    🔄 To create
    course_unit_list_page.dart  🔄 To create
    lesson_reader_page.dart     🔄 To create
  widgets/
    course_card_widget.dart     🔄 To create
    lesson_card_widget.dart     🔄 To create

upload_english_course.js        ✅ Created
```

## 🗄️ Firestore Structure

```
/courses (collection)
  english_b7 (document)
    - title: "Uriel English – Basic 7"
    - description: string
    - version: "1.0.0"
    - total_units: 10
    - subject: "English"
    - level: "JHS 1"
    
    /units (subcollection)
      eng_b7_u1 (document)
        - unit_id: "eng_b7_u1"
        - title: "Communication and You"
        - overview: string
        - estimated_duration_min: 180
        - competencies: []
        - values_morals: []
        - xp_total: 150
        - streak_bonus_xp: 5
        - parent_report_hooks: []
        - lessons: [
            {
              lesson_id: "eng_b7_u1_l1",
              title: "Greetings and Introductions",
              estimated_time_min: 25,
              xp_reward: 25,
              objectives: [],
              vocabulary: [],
              moral_link: string,
              content_blocks: [],
              interactive: {}
            }
          ]

/users (collection)
  {userId} (document)
    /lesson_progress (subcollection)
      english_b7_eng_b7_u1_eng_b7_u1_l1 (document)
        - user_id: string
        - course_id: "english_b7"
        - unit_id: "eng_b7_u1"
        - lesson_id: "eng_b7_u1_l1"
        - completed: boolean
        - xp_earned: number
        - quiz_score: number
        - completed_at: timestamp
        - last_accessed: timestamp
    
    /unit_progress (subcollection)
      english_b7_eng_b7_u1 (document)
        - user_id: string
        - course_id: "english_b7"
        - unit_id: "eng_b7_u1"
        - completion_rate: 0.0-1.0
        - quiz_accuracy: 0-100
        - xp_earned: number
        - lessons_completed: number
        - total_lessons: number
```

## 🎨 Design System (Apple-Inspired)

### Typography
- **Titles**: SF Pro Display / GoogleFonts.inter (28-34px, weight 700)
- **Headings**: SF Pro Text / GoogleFonts.inter (20-24px, weight 600)
- **Body**: SF Pro Text / GoogleFonts.inter (15-17px, weight 400)
- **Captions**: SF Pro Text / GoogleFonts.inter (13px, weight 400)

### Colors
- **Background**: #FAFAFA (light gray)
- **Surface**: #FFFFFF (white cards)
- **Primary**: #007AFF (iOS blue)
- **Success**: #34C759 (iOS green)
- **Text Primary**: #1C1C1E
- **Text Secondary**: #8E8E93
- **Divider**: #E5E5EA

### Spacing
- **Card Padding**: 20-24px
- **Section Margin**: 16-24px
- **Border Radius**: 16-20px (cards), 12px (buttons)

### Shadows
```dart
BoxShadow(
  color: Colors.black.withOpacity(0.04),
  blurRadius: 16,
  offset: Offset(0, 4),
)
```

## 📱 Pages Overview

### 1. Course Library Page
- Grid of course cards (2 columns mobile, 3-4 desktop)
- Each card shows: cover, title, progress %, XP earned
- Filter by subject/level
- Search functionality

### 2. Course Unit List Page
- List of units/chapters
- Progress indicator per unit
- Lock units until prerequisite complete (optional)
- Show XP total and lessons count
- Elegant header with course info

### 3. Lesson Reader Page
- Clean reading experience
- Typography optimized for readability
- Content blocks: text, images, audio, tips
- Interactive quizzes inline
- Progress bar at top
- XP reward on completion
- Next/Previous lesson navigation

## 🚀 Setup Instructions

### 1. Upload Course Data
```bash
node upload_english_course.js
```

### 2. Add Navigation
Add to `home_page.dart` navigation:
```dart
ListTile(
  leading: Icon(Icons.menu_book),
  title: Text('Books'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CourseLibraryPage(),
    ),
  ),
),
```

### 3. Test Flow
1. Open Books tab
2. See English JHS 1 course
3. Tap to view units
4. Tap unit to see lessons
5. Tap lesson to read
6. Complete quick checks
7. Earn XP on completion

## 🎯 Features

✅ Clean Apple-inspired UI
✅ Progress tracking per lesson/unit
✅ XP rewards integration
✅ Quiz system inline
✅ Audio support (ready)
✅ Vocabulary highlighting
✅ Moral/values integration
✅ Parent reporting hooks

## 📊 XP System Integration

- Lesson completion: Award `lesson.xp_reward` XP
- Quiz accuracy: Bonus XP for perfect scores
- Streak bonus: `unit.streak_bonus_xp` for consecutive days
- Updates user's total XP
- Triggers rank-up check

## 🔐 Security Rules

```javascript
// Firestore rules
match /courses/{courseId} {
  allow read: if request.auth != null;
  allow write: if false; // Admin only
  
  match /units/{unitId} {
    allow read: if request.auth != null;
    allow write: if false;
  }
}

match /users/{userId}/lesson_progress/{progressId} {
  allow read, write: if request.auth.uid == userId;
}

match /users/{userId}/unit_progress/{progressId} {
  allow read, write: if request.auth.uid == userId;
}
```

## 🎨 UI Components Needed

1. **CourseCard**: Displays course with progress
2. **UnitCard**: Shows unit with lesson count
3. **LessonCard**: Lesson preview with duration
4. **ContentBlockWidget**: Renders text/image/audio blocks
5. **QuickCheckWidget**: Interactive quiz questions
6. **ProgressBar**: Shows lesson/unit progress
7. **VocabularyTooltip**: Word definitions on tap

## 📈 Analytics Events

Track user engagement:
- `course_viewed`
- `unit_started`
- `lesson_opened`
- `lesson_completed`
- `quiz_answered`
- `xp_earned_textbook`

## 🔮 Future Enhancements

- [ ] Offline reading (download units)
- [ ] Note-taking within lessons
- [ ] Highlighting text
- [ ] Bookmarks
- [ ] AI voice narration
- [ ] Social features (study groups)
- [ ] Certificates on course completion
- [ ] Parent dashboard
