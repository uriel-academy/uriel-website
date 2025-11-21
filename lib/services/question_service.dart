import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/question_model.dart';

import 'package:flutter/foundation.dart';
class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collections
  CollectionReference get _questionsCollection => _firestore.collection('questions');

  /// Add a single question
  Future<void> addQuestion(Question question) async {
    try {
      await _questionsCollection.doc(question.id).set(question.toJson());
    } catch (e) {
      throw Exception('Failed to add question: $e');
    }
  }

  /// Add multiple questions in batch
  Future<void> addQuestionsBatch(List<Question> questions) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (Question question in questions) {
        DocumentReference docRef = _questionsCollection.doc(question.id);
        batch.set(docRef, question.toJson());
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add questions in batch: $e');
    }
  }

  /// Get questions by exam type and subject with database fallback
  Future<List<Question>> getQuestions({
    dynamic examType, // Can be ExamType enum or String
    dynamic subject, // Can be Subject enum or String
    String? year,
    String? section,
    bool activeOnly = true,
  }) async {
    try {
      // Try to fetch from Firestore first
      Query query = _questionsCollection;
      
      if (examType != null) {
        String examTypeStr = examType is ExamType ? _getExamTypeString(examType) : examType.toString();
        query = query.where('examType', isEqualTo: examTypeStr);
      }
      
      if (subject != null) {
        String subjectStr = subject is Subject ? _getSubjectString(subject) : subject.toString();
        query = query.where('subject', isEqualTo: subjectStr);
      }
      
      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }
      
      if (section != null) {
        query = query.where('section', isEqualTo: section);
      }
      
      // Don't add isActive filter to avoid index issues - filter client-side instead
      
      QuerySnapshot snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        // Convert to Question objects and filter active/inactive client-side
        List<Question> questions = [];
        for (var doc in snapshot.docs) {
          try {
            final question = Question.fromJson(doc.data() as Map<String, dynamic>);
            // Filter inactive if activeOnly is true
            if (!activeOnly || question.isActive) {
              questions.add(question);
            }
          } catch (e) {
            debugPrint('❌ Error parsing question ${doc.id}: $e');
            // Skip this question and continue with others
            continue;
          }
        }
        return _sortQuestions(questions);
      }
      
      // Fallback to sample questions if no data in Firestore
      ExamType? examTypeEnum = examType is ExamType ? examType : null;
      Subject? subjectEnum = subject is Subject ? subject : null;
      return getSampleQuestions(examType: examTypeEnum, subject: subjectEnum, year: year, section: section);
      
    } catch (e) {
      debugPrint('Error fetching questions from database: $e');
      // Fallback to sample questions on error
      ExamType? examTypeEnum = examType is ExamType ? examType : null;
      Subject? subjectEnum = subject is Subject ? subject : null;
      return getSampleQuestions(examType: examTypeEnum, subject: subjectEnum, year: year, section: section);
    }
  }

  /// Get RME questions specifically for debugging
  Future<List<Question>> getRMEQuestions() async {
    try {
      debugPrint('🔍 Fetching RME questions from Firestore...');
      
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .where('subject', isEqualTo: 'religiousMoralEducation')
          .where('isActive', isEqualTo: true)
          .get();
      
      debugPrint('📊 Found ${snapshot.docs.length} RME documents in Firestore');
      
      if (snapshot.docs.isNotEmpty) {
        final questions = snapshot.docs.map((doc) {
          debugPrint('📝 Processing RME question: ${doc.id}');
          return Question.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
        
        debugPrint('✅ Successfully converted ${questions.length} RME questions');
        return _sortQuestions(questions);
      } else {
        debugPrint('❌ No RME questions found in database');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching RME questions: $e');
      return [];
    }
  }

  /// Get sample questions for fallback
  List<Question> getSampleQuestions({
    ExamType? examType,
    Subject? subject,
    String? year,
    String? section,
  }) {
    // Return empty list - no fallback sample questions
    return [];
  }

  /// Enhanced method to get questions with advanced filtering
  Future<List<Question>> getQuestionsByFilters({
    dynamic examType, // Can be ExamType enum or String
    dynamic subject, // Can be Subject enum or String  
    String? year,
    String? section,
    String? level,
    int? limit,
    bool activeOnly = true,
    String? difficulty,
    List<String>? topics,
    String? triviaCategory, // New: filter by trivia category
  }) async {
    try {
      Query query = _questionsCollection;
      
      String? examTypeStr;
      String? subjectStr;
      
      if (examType != null) {
        examTypeStr = examType is ExamType ? _getExamTypeString(examType) : examType.toString();
        query = query.where('examType', isEqualTo: examTypeStr);
      }
      
      if (subject != null) {
        subjectStr = subject is Subject ? _getSubjectString(subject) : subject.toString();
        query = query.where('subject', isEqualTo: subjectStr);
      }
      
      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }
      
      if (section != null) {
        query = query.where('section', isEqualTo: section);
      }
      
      // Only add isActive filter if it's the only filter or with single examType/subject
      // This avoids composite index issues - we'll filter inactive questions client-side
      // if (activeOnly) {
      //   query = query.where('isActive', isEqualTo: true);
      // }
      
      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }
      
      // Note: level parameter is available but not used in filtering since it's not part of our Question model
      // You can add level field to Question model if needed
      
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }
      
      debugPrint('🔍 QuestionService.getQuestionsByFilters: Querying Firestore with subject=$subjectStr, examType=$examTypeStr, triviaCategory=$triviaCategory, activeOnly=$activeOnly, limit=$limit');
      
      // Use default get() to avoid cache/server issues
      QuerySnapshot snapshot = await query.get();
      
      debugPrint('📊 QuestionService.getQuestionsByFilters: Found ${snapshot.docs.length} documents');
      
      if (snapshot.docs.isNotEmpty) {
        List<Question> questions = [];
        
        // Convert documents to Question objects and apply client-side filters
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            
            // Client-side filter: Skip inactive questions if activeOnly is true
            if (activeOnly) {
              final isActive = data['isActive'] ?? false;
              if (!isActive) {
                continue;
              }
            }
            
            // If triviaCategory filter is specified, check if this question matches
            if (triviaCategory != null && triviaCategory.isNotEmpty) {
              final String? qCategory = data['triviaCategory'] as String?;
              // Case-insensitive comparison
              if (qCategory == null || qCategory.toLowerCase().trim() != triviaCategory.toLowerCase().trim()) {
                debugPrint('   ⏭️ Skipping question with category "$qCategory" (looking for "$triviaCategory")');
                continue; // Skip questions that don't match the category
              }
            }
            
            questions.add(Question.fromJson(data));
          } catch (e) {
            debugPrint('❌ Error parsing question ${doc.id}: $e');
            // Skip this question and continue with others
            continue;
          }
        }
        
        debugPrint('📊 After filters: ${questions.length} questions${triviaCategory != null ? ' for category "$triviaCategory"' : ''}');
        
        // Filter by topics if specified
        if (topics != null && topics.isNotEmpty) {
          questions = questions.where((q) => 
            q.topics.any((topic) => topics.contains(topic))
          ).toList();
        }
        // Ensure deterministic ordering before returning
        return _sortQuestions(questions);
      }
      
      // Fallback to sample questions
      ExamType? examTypeEnum = examType is ExamType ? examType : null;
      Subject? subjectEnum = subject is Subject ? subject : null;
      return getSampleQuestions(examType: examTypeEnum, subject: subjectEnum, year: year, section: section);
      
    } catch (e) {
      debugPrint('Error fetching questions with filters: $e');
      ExamType? examTypeEnum = examType is ExamType ? examType : null;
      Subject? subjectEnum = subject is Subject ? subject : null;
      return getSampleQuestions(examType: examTypeEnum, subject: subjectEnum, year: year, section: section);
    }
  }

  /// Convert ExamType enum to string for Firestore
  String _getExamTypeString(ExamType examType) {
    switch (examType) {
      case ExamType.bece:
        return 'bece';
      case ExamType.wassce:
        return 'wassce';
      case ExamType.mock:
        return 'mock';
      case ExamType.practice:
        return 'practice';
      case ExamType.trivia:
        return 'trivia';
    }
  }

  /// Convert Subject enum to string for Firestore
  String _getSubjectString(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'mathematics';
      case Subject.english:
        return 'english';
      case Subject.integratedScience:
        return 'integratedScience';
      case Subject.socialStudies:
        return 'socialStudies';
      case Subject.religiousMoralEducation:
        return 'religiousMoralEducation';
      case Subject.ga:
        return 'ga';
      case Subject.asanteTwi:
        return 'asanteTwi';
      case Subject.french:
        return 'french';
      case Subject.ict:
        return 'ict';
      case Subject.creativeArts:
        return 'creativeArts';
      case Subject.careerTechnology:
        return 'careerTechnology';
      case Subject.trivia:
        return 'trivia';
    }
  }

  /// Sort questions deterministically by year (numeric) then questionNumber
  List<Question> _sortQuestions(List<Question> questions) {
    questions.sort((a, b) {
      final int ay = int.tryParse(a.year) ?? 0;
      final int by = int.tryParse(b.year) ?? 0;
      if (ay != by) return ay.compareTo(by);
      return a.questionNumber.compareTo(b.questionNumber);
    });
    return questions;
  }

  /// Get question by ID
  Future<Question?> getQuestionById(String questionId) async {
    try {
      DocumentSnapshot doc = await _questionsCollection.doc(questionId).get();
      if (doc.exists) {
        return Question.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get question: $e');
    }
  }

  /// Update question
  Future<void> updateQuestion(Question question) async {
    try {
      await _questionsCollection.doc(question.id).update(question.toJson());
    } catch (e) {
      throw Exception('Failed to update question: $e');
    }
  }

  /// Delete question
  Future<void> deleteQuestion(String questionId) async {
    try {
      await _questionsCollection.doc(questionId).delete();
    } catch (e) {
      throw Exception('Failed to delete question: $e');
    }
  }

  /// Upload image for question
  Future<String?> uploadQuestionImage(String fileName, Uint8List imageData) async {
    try {
      Reference ref = _storage.ref().child('question_images').child(fileName);
      await ref.putData(imageData);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Get questions count by filters
  Future<int> getQuestionsCount({
    dynamic examType,
    dynamic subject,
    String? year,
    String? section,
    bool activeOnly = true,
  }) async {
    try {
      Query query = _questionsCollection;
      
      if (examType != null) {
        String examTypeStr = examType is ExamType ? _getExamTypeString(examType) : examType.toString();
        query = query.where('examType', isEqualTo: examTypeStr);
      }
      
      if (subject != null) {
        String subjectStr = subject is Subject ? _getSubjectString(subject) : subject.toString();
        query = query.where('subject', isEqualTo: subjectStr);
      }
      
      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }
      
      if (section != null) {
        query = query.where('section', isEqualTo: section);
      }
      
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      QuerySnapshot snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting questions count: $e');
      return 0;
    }
  }

  /// Parse questions from text (for admin use)
  Future<List<Question>> parseQuestionsFromText(String text) async {
    List<Question> questions = [];
    // Implementation for parsing questions from text
    // This is a placeholder - implement based on your text format
    return questions;
  }

  /// Parse trivia questions (for admin use)
  Future<List<Question>> parseTriviaQuestions(String text) async {
    List<Question> questions = [];
    // Implementation for parsing trivia questions
    // This is a placeholder - implement based on your trivia format
    return questions;
  }

  /// Create BECE exam
  Future<String> createBECEExam(Subject subject, String year) async {
    // Implementation for creating BECE exam
    // This is a placeholder - implement based on your exam creation logic
    return 'exam_id_placeholder';
  }
}