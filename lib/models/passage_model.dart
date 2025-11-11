import 'package:flutter/foundation.dart';
import 'question_model.dart';

class Passage {
  final String id;
  final String title; // e.g., "The Farmer's Son"
  final String content; // The full passage text
  final Subject subject;
  final ExamType examType;
  final String year;
  final String section; // "A", "B", "C"
  final List<int> questionRange; // e.g., [1, 2, 3, 4, 5] for questions 1-5
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  Passage({
    required this.id,
    required this.title,
    required this.content,
    required this.subject,
    required this.examType,
    required this.year,
    required this.section,
    required this.questionRange,
    required this.createdAt,
    required this.createdBy,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'subject': subject.name,
      'examType': examType.name,
      'year': year,
      'section': section,
      'questionRange': questionRange,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  factory Passage.fromJson(Map<String, dynamic> json) {
    try {
      return Passage(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        subject: Subject.values.firstWhere(
          (e) => e.name == json['subject'],
          orElse: () => Subject.english,
        ),
        examType: ExamType.values.firstWhere(
          (e) => e.name == json['examType'],
          orElse: () => ExamType.bece,
        ),
        year: json['year']?.toString() ?? '',
        section: json['section']?.toString() ?? '',
        questionRange: _parseQuestionRange(json['questionRange']),
        createdAt: _parseDateTime(json['createdAt']),
        createdBy: json['createdBy'] ?? '',
        isActive: json['isActive'] ?? true,
      );
    } catch (e) {
      debugPrint('Error parsing passage from JSON: $e');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  static List<int> _parseQuestionRange(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    }
    if (value is String) {
      if (value.isEmpty) return [];
      // Try to parse comma-separated numbers
      try {
        return value.split(',').map((e) => int.parse(e.trim())).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
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
