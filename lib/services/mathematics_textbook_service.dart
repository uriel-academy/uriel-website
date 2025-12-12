import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// Service for managing Mathematics textbooks with XP system
/// Loads from local JSON assets for instant performance
class MathematicsTextbookService {
  static final MathematicsTextbookService _instance = MathematicsTextbookService._internal();
  factory MathematicsTextbookService() => _instance;
  MathematicsTextbookService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for loaded textbooks from JSON
  final Map<String, Map<String, dynamic>> _textbookCache = {};
  bool _cacheLoaded = false;

  /// Load all Mathematics textbooks from JSON assets into cache
  Future<void> _loadTextbooksFromAssets() async {
    if (_cacheLoaded) return;
    
    try {
      final textbookIds = ['mathematics_jhs_1', 'mathematics_jhs_2', 'mathematics_jhs_3'];
      
      // Clear any existing cache to force fresh load
      _textbookCache.clear();
      
      for (final id in textbookIds) {
        try {
          print('📚 [Mathematics] Loading: assets/textbooks/$id.json');
          final jsonString = await rootBundle.loadString('assets/textbooks/$id.json');
          final textbookData = json.decode(jsonString) as Map<String, dynamic>;
          _textbookCache[id] = textbookData;
          
          // Log first section title for verification
          if (textbookData['chapters'] != null && (textbookData['chapters'] as List).isNotEmpty) {
            final firstChapter = (textbookData['chapters'] as List)[0];
            final firstSection = (firstChapter['sections'] as List)[0];
            print('✅ Loaded: $id - ${textbookData['title']} - First section: ${firstSection['title']}');
          }
        } catch (e) {
          print('❌ Could not load $id.json from assets: $e');
        }
      }
      
      _cacheLoaded = true;
      print('📖 Loaded ${_textbookCache.length} Mathematics textbooks from assets');
      print('   Cached IDs: ${_textbookCache.keys.join(', ')}');
    } catch (e) {
      print('❌ Error loading Mathematics textbooks from assets: $e');
    }
  }

  /// Get all Mathematics textbooks (from JSON assets with Firestore fallback)
  Future<List<Map<String, dynamic>>> getAllTextbooks() async {
    try {
      // Load from assets first
      await _loadTextbooksFromAssets();
      
      if (_textbookCache.isNotEmpty) {
        final textbooks = _textbookCache.values.map((textbook) {
          return {
            'id': textbook['id'] ?? '',
            'subject': textbook['subject'] ?? 'Mathematics',
            'year': textbook['year'] ?? '',
            'title': textbook['title'] ?? '',
            'description': textbook['description'] ?? '',
            'coverImage': textbook['coverImage'] ?? '',
            'totalChapters': textbook['totalChapters'] ?? 0,
            'totalSections': textbook['totalSections'] ?? 0,
          };
        }).toList();
        
        // Sort by year
        textbooks.removeWhere((book) => book['year'] == null || book['year'] == '');
        textbooks.sort((a, b) {
          final yearA = a['year'] as String?;
          final yearB = b['year'] as String?;
          if (yearA == null || yearB == null) return 0;
          return yearA.compareTo(yearB);
        });
        
        return textbooks;
      }
      
      return [];
    } catch (e) {
      print('Error getting Mathematics textbooks: $e');
      return [];
    }
  }

  /// Get textbook for a specific year
  Future<Map<String, dynamic>?> getTextbook(String year) async {
    try {
      await _loadTextbooksFromAssets();
      
      for (final textbook in _textbookCache.values) {
        if (textbook['year'] == year) {
          return textbook;
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting Mathematics textbook: $e');
      return null;
    }
  }

  /// Get chapter details (from JSON with Firestore fallback)
  Future<Map<String, dynamic>?> getChapter(String textbookId, int chapterNumber) async {
    try {
      await _loadTextbooksFromAssets();
      
      final textbook = _textbookCache[textbookId];
      if (textbook != null && textbook['chapters'] != null) {
        final chapters = textbook['chapters'] as List;
        final chapter = chapters.firstWhere(
          (ch) => ch['chapterNumber'] == chapterNumber,
          orElse: () => null,
        );
        return chapter;
      }
      
      return null;
    } catch (e) {
      print('Error getting chapter: $e');
      return null;
    }
  }

  /// Get section details (from JSON with Firestore fallback)
  Future<Map<String, dynamic>?> getSection(
    String textbookId,
    int chapterNumber,
    int sectionNumber,
  ) async {
    try {
      await _loadTextbooksFromAssets();
      
      final textbook = _textbookCache[textbookId];
      if (textbook != null && textbook['chapters'] != null) {
        final chapters = textbook['chapters'] as List;
        final chapter = chapters.firstWhere(
          (ch) => ch['chapterNumber'] == chapterNumber,
          orElse: () => null,
        );
        
        if (chapter != null && chapter['sections'] != null) {
          final sections = chapter['sections'] as List;
          final section = sections.firstWhere(
            (sec) => sec['sectionNumber'] == sectionNumber,
            orElse: () => null,
          );
          return section;
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting section: $e');
      return null;
    }
  }

  /// Get user progress for a textbook
  Future<Map<String, dynamic>> getUserProgress(String textbookId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {
          'completedSections': [],
          'totalXp': 0,
          'lastAccessed': null,
        };
      }

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('Mathematics_textbook_progress')
          .doc(textbookId)
          .get();

      if (!doc.exists) {
        return {
          'completedSections': [],
          'totalXp': 0,
          'lastAccessed': null,
        };
      }

      return doc.data() ?? {};
    } catch (e) {
      print('Error getting user progress: $e');
      return {
        'completedSections': [],
        'totalXp': 0,
        'lastAccessed': null,
      };
    }
  }

  /// Mark section as completed and award XP
  Future<void> completeSection({
    required String textbookId,
    required int chapterNumber,
    required int sectionNumber,
    required int xpReward,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final sectionId = '${textbookId}_ch${chapterNumber}_sec${sectionNumber}';
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('Mathematics_textbook_progress')
          .doc(textbookId)
          .set({
        'completedSections': FieldValue.arrayUnion([sectionId]),
        'totalXp': FieldValue.increment(xpReward),
        'lastAccessed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update user's total XP
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'xp': FieldValue.increment(xpReward),
      });
    } catch (e) {
      print('Error completing section: $e');
    }
  }

  /// Submit quiz answers and get results
  Future<Map<String, dynamic>> submitQuiz({
    required String textbookId,
    required int chapterNumber,
    required int sectionNumber,
    required Map<String, String> answers,
  }) async {
    try {
      final section = await getSection(textbookId, chapterNumber, sectionNumber);
      if (section == null || section['questions'] == null) {
        return {
          'success': false,
          'error': 'Section not found',
        };
      }

      final questions = section['questions'] as List;
      int correctCount = 0;
      int totalQuestions = questions.length;
      final results = <Map<String, dynamic>>[];

      for (final question in questions) {
        final questionId = question['id'] as String;
        final userAnswer = answers[questionId];
        final correctAnswer = question['correctAnswer'] as String;
        final isCorrect = userAnswer == correctAnswer;

        if (isCorrect) correctCount++;

        results.add({
          'questionId': questionId,
          'userAnswer': userAnswer,
          'correctAnswer': correctAnswer,
          'isCorrect': isCorrect,
          'explanation': question['explanation'],
        });
      }

      final percentage = (correctCount / totalQuestions * 100).round();
      final xpEarned = (section['xpReward'] as int? ?? 50) * correctCount ~/ totalQuestions;

      // Award XP if score >= 70%
      if (percentage >= 70) {
        await completeSection(
          textbookId: textbookId,
          chapterNumber: chapterNumber,
          sectionNumber: sectionNumber,
          xpReward: xpEarned,
        );
      }

      return {
        'success': true,
        'correctCount': correctCount,
        'totalQuestions': totalQuestions,
        'percentage': percentage,
        'xpEarned': xpEarned,
        'results': results,
      };
    } catch (e) {
      print('Error submitting quiz: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get chapters for a textbook
  Future<List<Map<String, dynamic>>> getChapters(String textbookId) async {
    await _loadTextbooksFromAssets();
    final textbook = _textbookCache[textbookId];
    if (textbook == null) return [];
    return List<Map<String, dynamic>>.from(textbook['chapters'] ?? []);
  }

  /// Get sections for a chapter
  Future<List<Map<String, dynamic>>> getSections(String textbookId, String chapterId) async {
    final chapters = await getChapters(textbookId);
    final chapter = chapters.firstWhere(
      (c) => c['id'] == chapterId,
      orElse: () => {},
    );
    return List<Map<String, dynamic>>.from(chapter['sections'] ?? []);
  }

  /// Submit answer (stub for now)
  Future<bool> submitAnswer(String textbookId, String sectionId, int questionIndex, String answer) async {
    return true; // Always return true for now
  }
}

