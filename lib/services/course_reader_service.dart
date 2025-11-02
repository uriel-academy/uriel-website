// Course Reader Service for Firestore operations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/course_models.dart';

class CourseReaderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all available courses
  Future<List<Course>> getAllCourses() async {
    try {
      final snapshot = await _firestore.collection('courses').get();
      return snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching courses: $e');
      return [];
    }
  }

  /// Get a specific course by ID
  Future<Course?> getCourse(String courseId) async {
    try {
      final doc = await _firestore.collection('courses').doc(courseId).get();
      if (doc.exists) {
        return Course.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching course: $e');
      return null;
    }
  }

  /// Get all units for a course
  Future<List<CourseUnit>> getCourseUnits(String courseId) async {
    try {
      final snapshot = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('units')
          .orderBy('unit_id')
          .get();
      
      return snapshot.docs
          .map((doc) => CourseUnit.fromFirestore(doc, courseId))
          .toList();
    } catch (e) {
      debugPrint('Error fetching units: $e');
      return [];
    }
  }

  /// Get a specific unit
  Future<CourseUnit?> getUnit(String courseId, String unitId) async {
    try {
      final doc = await _firestore
          .collection('courses')
          .doc(courseId)
          .collection('units')
          .doc(unitId)
          .get();
      
      if (doc.exists) {
        return CourseUnit.fromFirestore(doc, courseId);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching unit: $e');
      return null;
    }
  }

  /// Get lesson progress for current user
  Future<LessonProgress?> getLessonProgress(
    String courseId,
    String unitId,
    String lessonId,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .doc('${courseId}_${unitId}_$lessonId')
          .get();
      
      if (doc.exists) {
        return LessonProgress.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching lesson progress: $e');
      return null;
    }
  }

  /// Update lesson progress
  Future<void> updateLessonProgress({
    required String courseId,
    required String unitId,
    required String lessonId,
    required bool completed,
    required int xpEarned,
    required int quizScore,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final progressDoc = _firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .doc('${courseId}_${unitId}_$lessonId');

      final progress = LessonProgress(
        userId: userId,
        courseId: courseId,
        unitId: unitId,
        lessonId: lessonId,
        completed: completed,
        xpEarned: xpEarned,
        quizScore: quizScore,
        completedAt: completed ? DateTime.now() : null,
        lastAccessed: DateTime.now(),
      );

      await progressDoc.set(progress.toFirestore(), SetOptions(merge: true));

      // Update unit progress
      await _updateUnitProgress(courseId, unitId);

      // Award XP if completed
      if (completed && xpEarned > 0) {
        await _awardXP(xpEarned, 'Completed lesson: $lessonId');
      }
    } catch (e) {
      debugPrint('Error updating lesson progress: $e');
    }
  }

  /// Get unit progress for current user
  Future<UnitProgress?> getUnitProgress(String courseId, String unitId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('unit_progress')
          .doc('${courseId}_$unitId')
          .get();
      
      if (doc.exists) {
        return UnitProgress.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching unit progress: $e');
      return null;
    }
  }

  /// Update unit progress summary
  Future<void> _updateUnitProgress(String courseId, String unitId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Get all lesson progress for this unit
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .where('course_id', isEqualTo: courseId)
          .where('unit_id', isEqualTo: unitId)
          .get();

      if (snapshot.docs.isEmpty) return;

      int totalLessons = snapshot.docs.length;
      int completedLessons = 0;
      int totalXP = 0;
      int totalQuizScore = 0;
      int quizCount = 0;

      for (var doc in snapshot.docs) {
        final progress = LessonProgress.fromFirestore(doc);
        if (progress.completed) completedLessons++;
        totalXP += progress.xpEarned;
        if (progress.quizScore > 0) {
          totalQuizScore += progress.quizScore;
          quizCount++;
        }
      }

      double completionRate = totalLessons > 0 ? completedLessons / totalLessons : 0;
      double quizAccuracy = quizCount > 0 ? totalQuizScore / quizCount : 0;

      final unitProgress = UnitProgress(
        userId: userId,
        courseId: courseId,
        unitId: unitId,
        completionRate: completionRate,
        quizAccuracy: quizAccuracy,
        xpEarned: totalXP,
        lessonsCompleted: completedLessons,
        totalLessons: totalLessons,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('unit_progress')
          .doc('${courseId}_$unitId')
          .set(unitProgress.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating unit progress: $e');
    }
  }

  /// Award XP to user
  Future<void> _awardXP(int xpAmount, String source) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        final currentXP = snapshot.data()?['totalXP'] ?? 0;
        final newXP = currentXP + xpAmount;
        
        transaction.update(userDoc, {'totalXP': newXP});
      });

      // Log XP transaction
      await _firestore.collection('xp_transactions').add({
        'userId': userId,
        'xpAmount': xpAmount,
        'source': 'textbook',
        'sourceId': source,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error awarding XP: $e');
    }
  }

  /// Get all lesson progress for a unit
  Future<Map<String, LessonProgress>> getUnitLessonProgress(
    String courseId,
    String unitId,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('lesson_progress')
          .where('course_id', isEqualTo: courseId)
          .where('unit_id', isEqualTo: unitId)
          .get();

      final Map<String, LessonProgress> progressMap = {};
      for (var doc in snapshot.docs) {
        final progress = LessonProgress.fromFirestore(doc);
        progressMap[progress.lessonId] = progress;
      }
      return progressMap;
    } catch (e) {
      debugPrint('Error fetching unit lesson progress: $e');
      return {};
    }
  }

  /// Get course progress summary
  Future<Map<String, dynamic>> getCourseProgress(String courseId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('unit_progress')
          .where('course_id', isEqualTo: courseId)
          .get();

      int totalUnitsCompleted = 0;
      int totalXP = 0;
      double avgCompletion = 0;

      for (var doc in snapshot.docs) {
        final progress = UnitProgress.fromFirestore(doc);
        if (progress.completionRate >= 1.0) totalUnitsCompleted++;
        totalXP += progress.xpEarned;
        avgCompletion += progress.completionRate;
      }

      int totalUnits = snapshot.docs.length;
      avgCompletion = totalUnits > 0 ? avgCompletion / totalUnits : 0;

      return {
        'total_units': totalUnits,
        'completed_units': totalUnitsCompleted,
        'total_xp': totalXP,
        'avg_completion': avgCompletion,
      };
    } catch (e) {
      debugPrint('Error fetching course progress: $e');
      return {};
    }
  }
}
