// Textbook Data Models for Uriel Academy
import 'package:cloud_firestore/cloud_firestore.dart';

/// Course model representing a complete textbook (e.g., English B7)
class Course {
  final String courseId;
  final String title;
  final String description;
  final String version;
  final DateTime lastUpdated;
  final int totalUnits;
  final String? coverImageUrl;
  final String? subject;
  final String? level;

  Course({
    required this.courseId,
    required this.title,
    required this.description,
    required this.version,
    required this.lastUpdated,
    this.totalUnits = 0,
    this.coverImageUrl,
    this.subject,
    this.level,
  });

  factory Course.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Course(
      courseId: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      version: data['version'] ?? '1.0.0',
      lastUpdated: (data['last_updated_utc'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalUnits: data['total_units'] ?? 0,
      coverImageUrl: data['cover_image_url'],
      subject: data['subject'],
      level: data['level'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'version': version,
      'last_updated_utc': Timestamp.fromDate(lastUpdated),
      'total_units': totalUnits,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (subject != null) 'subject': subject,
      if (level != null) 'level': level,
    };
  }
}

/// Unit model representing a chapter/unit in a textbook
class CourseUnit {
  final String unitId;
  final String courseId;
  final String title;
  final String overview;
  final int estimatedDurationMin;
  final List<String> competencies;
  final List<String> valuesMorals;
  final int xpTotal;
  final int streakBonusXP;
  final List<String> parentReportHooks;
  final List<Lesson> lessons;

  CourseUnit({
    required this.unitId,
    required this.courseId,
    required this.title,
    required this.overview,
    required this.estimatedDurationMin,
    required this.competencies,
    required this.valuesMorals,
    required this.xpTotal,
    required this.streakBonusXP,
    required this.parentReportHooks,
    required this.lessons,
  });

  factory CourseUnit.fromFirestore(DocumentSnapshot doc, String courseId) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseUnit(
      unitId: doc.id,
      courseId: courseId,
      title: data['title'] ?? '',
      overview: data['overview'] ?? '',
      estimatedDurationMin: data['estimated_duration_min'] ?? 0,
      competencies: List<String>.from(data['competencies'] ?? []),
      valuesMorals: List<String>.from(data['values_morals'] ?? []),
      xpTotal: data['xp_total'] ?? 0,
      streakBonusXP: data['streak_bonus_xp'] ?? 0,
      parentReportHooks: List<String>.from(data['parent_report_hooks'] ?? []),
      lessons: (data['lessons'] as List<dynamic>?)
              ?.map((l) => Lesson.fromMap(l as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory CourseUnit.fromMap(Map<String, dynamic> data, String courseId) {
    return CourseUnit(
      unitId: data['unit_id'] ?? '',
      courseId: courseId,
      title: data['title'] ?? '',
      overview: data['overview'] ?? '',
      estimatedDurationMin: data['estimated_duration_min'] ?? 0,
      competencies: List<String>.from(data['competencies'] ?? []),
      valuesMorals: List<String>.from(data['values_morals'] ?? []),
      xpTotal: data['xp_total'] ?? 0,
      streakBonusXP: data['streak_bonus_xp'] ?? 0,
      parentReportHooks: List<String>.from(data['parent_report_hooks'] ?? []),
      lessons: (data['lessons'] as List<dynamic>?)
              ?.map((l) => Lesson.fromMap(l as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'unit_id': unitId,
      'title': title,
      'overview': overview,
      'estimated_duration_min': estimatedDurationMin,
      'competencies': competencies,
      'values_morals': valuesMorals,
      'xp_total': xpTotal,
      'streak_bonus_xp': streakBonusXP,
      'parent_report_hooks': parentReportHooks,
      'lessons': lessons.map((l) => l.toMap()).toList(),
    };
  }
}

/// Lesson model representing a single lesson within a unit
class Lesson {
  final String lessonId;
  final String title;
  final int estimatedTimeMin;
  final int xpReward;
  final List<String> objectives;
  final List<Vocabulary> vocabulary;
  final String? moralLink;
  final List<ContentBlock> contentBlocks;
  final Interactive? interactive;

  Lesson({
    required this.lessonId,
    required this.title,
    required this.estimatedTimeMin,
    required this.xpReward,
    required this.objectives,
    required this.vocabulary,
    this.moralLink,
    required this.contentBlocks,
    this.interactive,
  });

  factory Lesson.fromMap(Map<String, dynamic> data) {
    return Lesson(
      lessonId: data['lesson_id'] ?? '',
      title: data['title'] ?? '',
      estimatedTimeMin: data['estimated_time_min'] ?? 0,
      xpReward: data['xp_reward'] ?? 0,
      objectives: List<String>.from(data['objectives'] ?? []),
      vocabulary: (data['vocabulary'] as List<dynamic>?)
              ?.map((v) => Vocabulary.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      moralLink: data['moral_link'],
      contentBlocks: (data['content_blocks'] as List<dynamic>?)
              ?.map((c) => ContentBlock.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      interactive: data['interactive'] != null
          ? Interactive.fromMap(data['interactive'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lesson_id': lessonId,
      'title': title,
      'estimated_time_min': estimatedTimeMin,
      'xp_reward': xpReward,
      'objectives': objectives,
      'vocabulary': vocabulary.map((v) => v.toMap()).toList(),
      if (moralLink != null) 'moral_link': moralLink,
      'content_blocks': contentBlocks.map((c) => c.toMap()).toList(),
      if (interactive != null) 'interactive': interactive!.toMap(),
    };
  }
}

/// Vocabulary word with definition
class Vocabulary {
  final String word;
  final String level;
  final String definition;

  Vocabulary({
    required this.word,
    required this.level,
    required this.definition,
  });

  factory Vocabulary.fromMap(Map<String, dynamic> data) {
    return Vocabulary(
      word: data['word'] ?? '',
      level: data['level'] ?? '',
      definition: data['definition'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'level': level,
      'definition': definition,
    };
  }
}

/// Content block (text, audio, image, tip, etc.)
class ContentBlock {
  final String type; // text, audio, image, tip, example, etc.
  final String? body;
  final String? src;
  final String? caption;
  final String? alt;

  ContentBlock({
    required this.type,
    this.body,
    this.src,
    this.caption,
    this.alt,
  });

  factory ContentBlock.fromMap(Map<String, dynamic> data) {
    return ContentBlock(
      type: data['type'] ?? 'text',
      body: data['body'],
      src: data['src'],
      caption: data['caption'],
      alt: data['alt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (body != null) 'body': body,
      if (src != null) 'src': src,
      if (caption != null) 'caption': caption,
      if (alt != null) 'alt': alt,
    };
  }
}

/// Interactive elements (quizzes, speaking tasks, etc.)
class Interactive {
  final List<QuickCheck>? quickCheck;
  final SpeakingTask? speakingTask;
  final WritingTask? writingTask;

  Interactive({
    this.quickCheck,
    this.speakingTask,
    this.writingTask,
  });

  factory Interactive.fromMap(Map<String, dynamic> data) {
    return Interactive(
      quickCheck: (data['quick_check'] as List<dynamic>?)
          ?.map((q) => QuickCheck.fromMap(q as Map<String, dynamic>))
          .toList(),
      speakingTask: data['speaking_task'] != null
          ? SpeakingTask.fromMap(data['speaking_task'] as Map<String, dynamic>)
          : null,
      writingTask: data['writing_task'] != null
          ? WritingTask.fromMap(data['writing_task'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (quickCheck != null) 'quick_check': quickCheck!.map((q) => q.toMap()).toList(),
      if (speakingTask != null) 'speaking_task': speakingTask!.toMap(),
      if (writingTask != null) 'writing_task': writingTask!.toMap(),
    };
  }
}

/// Quick check question
class QuickCheck {
  final String question;
  final List<String> options;
  final int answerIndex;
  final int xp;
  final String? explanation;

  QuickCheck({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.xp,
    this.explanation,
  });

  factory QuickCheck.fromMap(Map<String, dynamic> data) {
    return QuickCheck(
      question: data['q'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      answerIndex: data['answer_index'] ?? 0,
      xp: data['xp'] ?? 5,
      explanation: data['explanation'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'q': question,
      'options': options,
      'answer_index': answerIndex,
      'xp': xp,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

/// Speaking task
class SpeakingTask {
  final String prompt;
  final List<String>? aiFeedback;

  SpeakingTask({
    required this.prompt,
    this.aiFeedback,
  });

  factory SpeakingTask.fromMap(Map<String, dynamic> data) {
    return SpeakingTask(
      prompt: data['prompt'] ?? '',
      aiFeedback: data['ai_feedback'] != null
          ? List<String>.from(data['ai_feedback'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      if (aiFeedback != null) 'ai_feedback': aiFeedback,
    };
  }
}

/// Writing task
class WritingTask {
  final String prompt;
  final int minWords;
  final List<String>? criteria;

  WritingTask({
    required this.prompt,
    required this.minWords,
    this.criteria,
  });

  factory WritingTask.fromMap(Map<String, dynamic> data) {
    return WritingTask(
      prompt: data['prompt'] ?? '',
      minWords: data['min_words'] ?? 50,
      criteria: data['criteria'] != null
          ? List<String>.from(data['criteria'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'min_words': minWords,
      if (criteria != null) 'criteria': criteria,
    };
  }
}

/// User progress for a specific lesson
class LessonProgress {
  final String userId;
  final String courseId;
  final String unitId;
  final String lessonId;
  final bool completed;
  final int xpEarned;
  final int quizScore;
  final DateTime? completedAt;
  final DateTime lastAccessed;

  LessonProgress({
    required this.userId,
    required this.courseId,
    required this.unitId,
    required this.lessonId,
    required this.completed,
    required this.xpEarned,
    required this.quizScore,
    this.completedAt,
    required this.lastAccessed,
  });

  factory LessonProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LessonProgress(
      userId: data['user_id'] ?? '',
      courseId: data['course_id'] ?? '',
      unitId: data['unit_id'] ?? '',
      lessonId: data['lesson_id'] ?? '',
      completed: data['completed'] ?? false,
      xpEarned: data['xp_earned'] ?? 0,
      quizScore: data['quiz_score'] ?? 0,
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      lastAccessed: (data['last_accessed'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'course_id': courseId,
      'unit_id': unitId,
      'lesson_id': lessonId,
      'completed': completed,
      'xp_earned': xpEarned,
      'quiz_score': quizScore,
      if (completedAt != null) 'completed_at': Timestamp.fromDate(completedAt!),
      'last_accessed': Timestamp.fromDate(lastAccessed),
    };
  }
}

/// Unit progress summary
class UnitProgress {
  final String userId;
  final String courseId;
  final String unitId;
  final double completionRate;
  final double quizAccuracy;
  final int xpEarned;
  final int lessonsCompleted;
  final int totalLessons;

  UnitProgress({
    required this.userId,
    required this.courseId,
    required this.unitId,
    required this.completionRate,
    required this.quizAccuracy,
    required this.xpEarned,
    required this.lessonsCompleted,
    required this.totalLessons,
  });

  factory UnitProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UnitProgress(
      userId: data['user_id'] ?? '',
      courseId: data['course_id'] ?? '',
      unitId: data['unit_id'] ?? '',
      completionRate: (data['completion_rate'] ?? 0).toDouble(),
      quizAccuracy: (data['quiz_accuracy'] ?? 0).toDouble(),
      xpEarned: data['xp_earned'] ?? 0,
      lessonsCompleted: data['lessons_completed'] ?? 0,
      totalLessons: data['total_lessons'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'course_id': courseId,
      'unit_id': unitId,
      'completion_rate': completionRate,
      'quiz_accuracy': quizAccuracy,
      'xp_earned': xpEarned,
      'lessons_completed': lessonsCompleted,
      'total_lessons': totalLessons,
    };
  }
}
