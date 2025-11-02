import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to sync student performance data to studentSummaries collection
/// This ensures teacher dashboards always show current XP, questions, rank, subjects
class StudentDataSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Sync a student's current performance to studentSummaries
  /// Called after quiz completion, XP changes, rank updates
  Future<void> syncStudentData(String studentId) async {
    try {
      // Get student document
      final studentDoc = await _firestore.collection('users').doc(studentId).get();
      if (!studentDoc.exists) {
        debugPrint('Student $studentId not found');
        return;
      }
      
      final studentData = studentDoc.data()!;
      final role = studentData['role'] as String?;
      
      // Only sync students, not teachers
      if (role != 'student') {
        debugPrint('Skipping non-student user $studentId (role: $role)');
        return;
      }
      
      final teacherId = studentData['teacherId'] as String?;
      if (teacherId == null || teacherId.isEmpty) {
        debugPrint('Student $studentId has no teacher assigned');
        return;
      }
      
      // Get comprehensive performance data
      final performanceData = await _calculateStudentPerformance(studentId, studentData);
      
      // Update studentSummaries
      await _firestore.collection('studentSummaries').doc(studentId).set({
        'teacherId': teacherId,
        'firstName': studentData['firstName'] ?? '',
        'lastName': studentData['lastName'] ?? '',
        'displayName': studentData['displayName'] ?? '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'.trim(),
        'email': studentData['email'] ?? '',
        'school': studentData['school'] ?? '',
        'class': studentData['grade'] ?? studentData['class'] ?? '',
        'normalizedSchool': _normalizeText(studentData['school'] as String?),
        'normalizedClass': _normalizeText(studentData['grade'] as String? ?? studentData['class'] as String?),
        'avatar': studentData['profileImageUrl'] ?? studentData['avatar'] ?? studentData['presetAvatar'],
        // Performance metrics
        'totalXP': performanceData['totalXP'],
        'totalQuestions': performanceData['totalQuestions'],
        'subjectsCount': performanceData['subjectsCount'],
        'avgPercent': performanceData['avgPercent'],
        'rank': performanceData['rank'],
        'rankName': performanceData['rankName'],
        // Metadata
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ Synced student data for $studentId');
    } catch (e, stackTrace) {
      debugPrint('❌ Error syncing student data for $studentId: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  /// Calculate student's current performance metrics
  Future<Map<String, dynamic>> _calculateStudentPerformance(String studentId, Map<String, dynamic> studentData) async {
    // Get XP from user document (source of truth)
    final totalXP = (studentData['totalXP'] ?? studentData['xp'] ?? 0) as num;
    
    // Get rank from user document or calculate from XP
    String? rank;
    String? rankName;
    if (studentData['currentRank'] != null) {
      rank = studentData['currentRank'].toString();
      rankName = studentData['currentRankName'] as String?;
    } else {
      // Calculate rank from XP
      final rankData = await _calculateRankFromXP(totalXP.toInt());
      rank = rankData['rank']?.toString();
      rankName = rankData['name'] as String?;
    }
    
    // Get quiz statistics
    final quizzesSnapshot = await _firestore
        .collection('quizzes')
        .where('userId', isEqualTo: studentId)
        .get();
    
    final quizzes = quizzesSnapshot.docs;
    
    // Calculate total questions answered
    int totalQuestions = 0;
    double totalPercentage = 0;
    int quizzesWithPercentage = 0;
    Set<String> uniqueSubjects = {};
    
    for (final quiz in quizzes) {
      final quizData = quiz.data();
      final questionsInQuiz = (quizData['totalQuestions'] ?? 0) as num;
      totalQuestions += questionsInQuiz.toInt();
      
      final percentage = quizData['percentage'] as num?;
      if (percentage != null && percentage > 0) {
        totalPercentage += percentage.toDouble();
        quizzesWithPercentage++;
      }
      
      // Track unique subjects
      final subject = quizData['subject'] as String? ?? quizData['collectionName'] as String?;
      if (subject != null && subject.isNotEmpty) {
        uniqueSubjects.add(subject);
      }
    }
    
    // Calculate average accuracy
    final avgPercent = quizzesWithPercentage > 0 
        ? totalPercentage / quizzesWithPercentage 
        : 0.0;
    
    return {
      'totalXP': totalXP.toInt(),
      'totalQuestions': totalQuestions,
      'subjectsCount': uniqueSubjects.length,
      'avgPercent': avgPercent,
      'rank': rank,
      'rankName': rankName,
    };
  }
  
  /// Calculate rank from XP by querying leaderboardRanks
  Future<Map<String, dynamic>> _calculateRankFromXP(int xp) async {
    try {
      // Get all ranks and find the matching one (client-side filtering)
      final ranksSnapshot = await _firestore
          .collection('leaderboardRanks')
          .orderBy('rank')
          .get();
      
      for (final doc in ranksSnapshot.docs) {
        final rankData = doc.data();
        final minXP = (rankData['minXP'] ?? 0) as num;
        final maxXP = (rankData['maxXP'] ?? 999999999) as num;
        
        if (xp >= minXP.toInt() && xp <= maxXP.toInt()) {
          return {
            'rank': rankData['rank'],
            'name': rankData['name'],
            'imageUrl': rankData['imageUrl'],
          };
        }
      }
    } catch (e) {
      debugPrint('Error calculating rank from XP: $e');
    }
    return {'rank': null, 'name': null, 'imageUrl': null};
  }
  
  /// Normalize text for matching (lowercase, trim, remove extra spaces)
  String _normalizeText(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  
  /// Sync all students for a given teacher
  /// Useful for bulk updates or when teacher profile changes
  Future<void> syncAllStudentsForTeacher(String teacherId) async {
    try {
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      debugPrint('Syncing ${studentsSnapshot.docs.length} students for teacher $teacherId');
      
      for (final studentDoc in studentsSnapshot.docs) {
        await syncStudentData(studentDoc.id);
      }
      
      debugPrint('✅ Completed sync for all students of teacher $teacherId');
    } catch (e) {
      debugPrint('❌ Error syncing students for teacher $teacherId: $e');
    }
  }
  
  /// Sync all students in the system (admin function)
  /// Should be run periodically or when data integrity issues are detected
  Future<void> syncAllStudents() async {
    try {
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      
      debugPrint('Starting full sync for ${studentsSnapshot.docs.length} students');
      
      int successCount = 0;
      int failCount = 0;
      
      for (final studentDoc in studentsSnapshot.docs) {
        try {
          await syncStudentData(studentDoc.id);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Failed to sync student ${studentDoc.id}: $e');
        }
      }
      
      debugPrint('✅ Full sync completed: $successCount success, $failCount failed');
    } catch (e) {
      debugPrint('❌ Error during full student sync: $e');
    }
  }
  
  /// Remove student from studentSummaries (e.g., when student deleted or teacher unassigned)
  Future<void> removeStudentSummary(String studentId) async {
    try {
      await _firestore.collection('studentSummaries').doc(studentId).delete();
      debugPrint('✅ Removed studentSummary for $studentId');
    } catch (e) {
      debugPrint('❌ Error removing studentSummary for $studentId: $e');
    }
  }
}
