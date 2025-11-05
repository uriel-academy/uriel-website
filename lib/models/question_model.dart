import 'package:flutter/foundation.dart';

enum QuestionType {
  multipleChoice,
  shortAnswer,
  essay,
  calculation,
  trivia
}

enum Subject {
  mathematics,
  english,
  integratedScience,
  socialStudies,
  ghanaianLanguage,
  french,
  ict,
  religiousMoralEducation,
  creativeArts,
  trivia
}

enum ExamType {
  bece,
  wassce,
  mock,
  practice,
  trivia
}

class Question {
  final String id;
  final String questionText;
  final QuestionType type;
  final Subject subject;
  final ExamType examType;
  final String year;
  final String section; // "A", "B", "C" for BECE, "General" for trivia
  final int questionNumber;
  final List<String>? options; // For multiple choice
  final String correctAnswer;
  final String? explanation;
  final String? imageUrl;
  final int marks;
  final String difficulty; // "easy", "medium", "hard"
  final List<String> topics;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  Question({
    required this.id,
    required this.questionText,
    required this.type,
    required this.subject,
    required this.examType,
    required this.year,
    required this.section,
    required this.questionNumber,
    this.options,
    required this.correctAnswer,
    this.explanation,
    this.imageUrl,
    required this.marks,
    required this.difficulty,
    required this.topics,
    required this.createdAt,
    required this.createdBy,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionText': questionText,
      'type': type.name,
      'subject': subject.name,
      'examType': examType.name,
      'year': year,
      'section': section,
      'questionNumber': questionNumber,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'imageUrl': imageUrl,
      'marks': marks,
      'difficulty': difficulty,
      'topics': topics,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    try {
      // Handle legacy subject field values
      String? subjectValue = json['subject'];
      if (subjectValue == 'RME') {
        subjectValue = 'religiousMoralEducation';
      } else if (subjectValue == 'unknown') {
        subjectValue = null; // Will use default
      }
      
      return Question(
        id: json['id'] ?? '',
        questionText: json['questionText'] ?? '',
        type: QuestionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => QuestionType.multipleChoice,
        ),
        subject: Subject.values.firstWhere(
          (e) => e.name == subjectValue,
          orElse: () => Subject.religiousMoralEducation, // Default to RME instead of mathematics
        ),
        examType: ExamType.values.firstWhere(
          (e) => e.name == json['examType'],
          orElse: () => ExamType.practice,
        ),
        year: json['year']?.toString() ?? '',
        section: json['section']?.toString() ?? '',
        questionNumber: json['questionNumber'] ?? 0,
        options: json['options'] != null ? List<String>.from(json['options']) : null,
        correctAnswer: json['correctAnswer'] ?? '',
        explanation: json['explanation'],
        imageUrl: json['imageUrl'],
        marks: json['marks'] ?? 1,
        difficulty: json['difficulty'] ?? 'medium',
        topics: json['topics'] != null ? List<String>.from(json['topics']) : [],
        createdAt: _parseDateTime(json['createdAt']),
        createdBy: json['createdBy'] ?? '',
        isActive: json['isActive'] ?? true,
      );
    } catch (e) {
      debugPrint('Error parsing question from JSON: $e');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }
    
    // Handle Firestore Timestamp object
    if (dateValue is Map && dateValue.containsKey('_seconds')) {
      final seconds = dateValue['_seconds'] as int;
      final nanoseconds = (dateValue['_nanoseconds'] as int?) ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanoseconds ~/ 1000000),
      );
    }
    
    // Handle ISO string format
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    
    // Fallback
    return DateTime.now();
  }
}

class Exam {
  final String id;
  final String title;
  final Subject subject;
  final ExamType type;
  final String year;
  final int duration; // in minutes
  final int totalMarks;
  final List<String> questionIds;
  final DateTime createdAt;
  final bool isActive;
  final String description;

  Exam({
    required this.id,
    required this.title,
    required this.subject,
    required this.type,
    required this.year,
    required this.duration,
    required this.totalMarks,
    required this.questionIds,
    required this.createdAt,
    required this.isActive,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject.name,
      'type': type.name,
      'year': year,
      'duration': duration,
      'totalMarks': totalMarks,
      'questionIds': questionIds,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'description': description,
    };
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      title: json['title'],
      subject: Subject.values.firstWhere(
        (e) => e.name == json['subject'],
      ),
      type: ExamType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      year: json['year'],
      duration: json['duration'],
      totalMarks: json['totalMarks'],
      questionIds: List<String>.from(json['questionIds']),
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'],
      description: json['description'],
    );
  }
}

class ExamResult {
  final String id;
  final String examId;
  final String studentId;
  final String studentEmail;
  final Map<String, String> answers; // questionId -> answer
  final Map<String, bool> correctness; // questionId -> isCorrect
  final int score;
  final int totalMarks;
  final double percentage;
  final DateTime startTime;
  final DateTime endTime;
  final int timeSpent; // in seconds

  ExamResult({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentEmail,
    required this.answers,
    required this.correctness,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    required this.startTime,
    required this.endTime,
    required this.timeSpent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'examId': examId,
      'studentId': studentId,
      'studentEmail': studentEmail,
      'answers': answers,
      'correctness': correctness,
      'score': score,
      'totalMarks': totalMarks,
      'percentage': percentage,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'timeSpent': timeSpent,
    };
  }

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['id'],
      examId: json['examId'],
      studentId: json['studentId'],
      studentEmail: json['studentEmail'],
      answers: Map<String, String>.from(json['answers']),
      correctness: Map<String, bool>.from(json['correctness']),
      score: json['score'],
      totalMarks: json['totalMarks'],
      percentage: json['percentage'].toDouble(),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      timeSpent: json['timeSpent'],
    );
  }
}