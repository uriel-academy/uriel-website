import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Service for handling class aggregates and student summaries
class ClassAggregatesService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get class aggregates for a teacher or school+grade
  Future<Map<String, dynamic>?> getClassAggregates({
    String? teacherId,
    String? school,
    String? grade,
    int pageSize = 50,
    String? pageCursor,
    bool includeCount = false,
  }) async {
    try {
      debugPrint('ClassAggregatesService: Getting aggregates for teacher: $teacherId, school: $school, grade: $grade');
      
      final callable = _functions.httpsCallable('getClassAggregates');
      
      final result = await callable.call(<String, dynamic>{
        if (teacherId != null) 'teacherId': teacherId,
        if (school != null) 'school': school,
        if (grade != null) 'grade': grade,
        'pageSize': pageSize,
        if (pageCursor != null) 'pageCursor': pageCursor,
        'includeCount': includeCount,
      });

      if (result.data != null && result.data['ok'] == true) {
        debugPrint('ClassAggregatesService: Successfully retrieved ${result.data['students']?.length ?? 0} students');
        return Map<String, dynamic>.from(result.data as Map);
      }
      
      return null;
    } catch (e) {
      debugPrint('ClassAggregatesService Error getting class aggregates: $e');
      rethrow;
    }
  }

  /// Get class aggregate document directly from Firestore
  Future<Map<String, dynamic>?> getClassAggregateDoc({
    required String school,
    required String grade,
  }) async {
    try {
      // Normalize school and grade to match the document ID format
      final normalizedSchool = _normalizeText(school);
      final normalizedGrade = _normalizeText(grade);
      final classId = '${normalizedSchool}_$normalizedGrade';
      
      debugPrint('ClassAggregatesService: Fetching class aggregate doc: $classId');
      
      final doc = await _firestore.collection('classAggregates').doc(classId).get();
      
      if (doc.exists) {
        final data = doc.data();
        debugPrint('ClassAggregatesService: Found aggregate data for class $classId');
        return data;
      }
      
      debugPrint('ClassAggregatesService: No aggregate doc found for class $classId');
      return null;
    } catch (e) {
      debugPrint('ClassAggregatesService Error getting class aggregate doc: $e');
      return null;
    }
  }

  /// Run backfill to create/update aggregates (admin only)
  Future<Map<String, dynamic>?> backfillClassAggregates() async {
    try {
      debugPrint('ClassAggregatesService: Running backfill...');
      
      final callable = _functions.httpsCallable('backfillClassAggregates');
      final result = await callable.call();
      
      if (result.data != null && result.data['ok'] == true) {
        debugPrint('ClassAggregatesService: Backfill completed successfully');
        return Map<String, dynamic>.from(result.data as Map);
      }
      
      return null;
    } catch (e) {
      debugPrint('ClassAggregatesService Error running backfill: $e');
      rethrow;
    }
  }

  /// Run paginated backfill (admin only) - returns nextCursor for resumable processing
  Future<Map<String, dynamic>?> backfillClassPage({
    int pageSize = 500,
    String? lastUid,
  }) async {
    try {
      debugPrint('ClassAggregatesService: Running paginated backfill (pageSize: $pageSize, lastUid: $lastUid)...');
      
      final callable = _functions.httpsCallable('backfillClassPage');
      final result = await callable.call(<String, dynamic>{
        'pageSize': pageSize,
        if (lastUid != null) 'lastUid': lastUid,
      });
      
      if (result.data != null && result.data['ok'] == true) {
        debugPrint('ClassAggregatesService: Page backfill completed. Processed: ${result.data['processedCount']}');
        return Map<String, dynamic>.from(result.data as Map);
      }
      
      return null;
    } catch (e) {
      debugPrint('ClassAggregatesService Error running page backfill: $e');
      rethrow;
    }
  }

  /// Get backfill progress
  Future<Map<String, dynamic>?> getBackfillProgress() async {
    try {
      final doc = await _firestore.collection('backfillProgress').doc('studentBackfill').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('ClassAggregatesService Error getting backfill progress: $e');
      return null;
    }
  }

  /// Get student summary
  Future<Map<String, dynamic>?> getStudentSummary(String uid) async {
    try {
      final doc = await _firestore.collection('studentSummaries').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('ClassAggregatesService Error getting student summary: $e');
      return null;
    }
  }

  /// Stream class aggregate updates
  Stream<Map<String, dynamic>?> streamClassAggregate({
    required String school,
    required String grade,
  }) {
    final normalizedSchool = _normalizeText(school);
    final normalizedGrade = _normalizeText(grade);
    final classId = '${normalizedSchool}_$normalizedGrade';
    
    return _firestore
        .collection('classAggregates')
        .doc(classId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  /// Helper to normalize text (similar to server-side normalization)
  String _normalizeText(String text) {
    // Remove common noise words
    String normalized = text.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'\b(school|college|high school|senior high school|senior|basic|primary|jhs|shs|the)\b'), ' ');
    
    // Replace non-alphanumeric with spaces
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    
    // Collapse whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Use underscore-delimited token id
    return normalized.replaceAll(' ', '_');
  }

  /// Calculate aggregated performance metrics from class data
  Map<String, dynamic> calculatePerformanceMetrics(Map<String, dynamic> classData) {
    final totalStudents = classData['totalStudents'] ?? 0;
    final totalXP = classData['totalXP'] ?? 0;
    final avgScorePercent = classData['avgScorePercent'] ?? 0.0;
    final totalQuestions = classData['totalQuestions'] ?? 0;
    final totalSubjects = classData['totalSubjects'] ?? 0;

    return {
      'averageXP': totalStudents > 0 ? (totalXP / totalStudents).round() : 0,
      'averageScore': avgScorePercent,
      'totalQuestions': totalQuestions,
      'averageQuestionsPerStudent': totalStudents > 0 ? (totalQuestions / totalStudents).round() : 0,
      'subjectsEngaged': totalSubjects,
      'totalStudents': totalStudents,
    };
  }
}
