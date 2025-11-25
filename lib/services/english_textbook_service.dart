import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// Service for managing interactive English textbooks with XP system
/// Now loads from local JSON assets for instant performance
class EnglishTextbookService {
  static final EnglishTextbookService _instance = EnglishTextbookService._internal();
  factory EnglishTextbookService() => _instance;
  EnglishTextbookService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for loaded textbooks from JSON
  final Map<String, Map<String, dynamic>> _textbookCache = {};
  bool _cacheLoaded = false;

  /// Load all textbooks from JSON assets into cache
  Future<void> _loadTextbooksFromAssets() async {
    if (_cacheLoaded) return;
    
    try {
      final textbookIds = ['english_jhs_1', 'english_jhs_2', 'english_jhs_3'];
      
      for (final id in textbookIds) {
        try {
          print('📚 Attempting to load: assets/textbooks/$id.json');
          final jsonString = await rootBundle.loadString('assets/textbooks/$id.json');
          final textbookData = json.decode(jsonString) as Map<String, dynamic>;
          _textbookCache[id] = textbookData;
          print('✅ Successfully loaded: $id (${textbookData['title']})');
        } catch (e) {
          print('❌ Could not load $id.json from assets: $e');
        }
      }
      
      _cacheLoaded = true;
      print('📖 Loaded ${_textbookCache.length} textbooks from assets');
      print('   Cached textbook IDs: ${_textbookCache.keys.join(', ')}');
    } catch (e) {
      print('❌ Error loading textbooks from assets: $e');
    }
  }

  /// Generate complete English textbook for a specific year
  Future<Map<String, dynamic>> generateTextbook({
    required String year, // 'JHS 1', 'JHS 2', or 'JHS 3'
    int batchSize = 2,
  }) async {
    try {
      final result = await _functions.httpsCallable('generateEnglishTextbooks').call({
        'year': year,
        'batchSize': batchSize,
      });

      return {
        'success': true,
        'textbookId': result.data['textbookId'],
        'year': result.data['year'],
        'chapters': result.data['chapters'],
        'sections': result.data['sections'],
        'totalQuestions': result.data['totalQuestions'],
      };
    } catch (e) {
      print('Error generating textbook: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get all English textbooks (from JSON assets with Firestore fallback)
  Future<List<Map<String, dynamic>>> getAllTextbooks() async {
    try {
      // Load from assets first
      await _loadTextbooksFromAssets();
      
      if (_textbookCache.isNotEmpty) {
        final textbooks = _textbookCache.values.map((textbook) {
          // Ensure all required fields exist with proper null safety
          return {
            'id': textbook['id'] ?? '',
            'subject': textbook['subject'] ?? 'English',
            'year': textbook['year'] ?? '',
            'title': textbook['title'] ?? '',
            'description': textbook['description'] ?? '',
            'coverImage': textbook['coverImage'] ?? '',
            'totalChapters': textbook['totalChapters'] ?? 0,
            'totalSections': textbook['totalSections'] ?? 0,
          };
        }).toList();
        
        // Safe sort with null checks and filtering
        textbooks.removeWhere((book) => book['year'] == null || book['year'] == '');
        textbooks.sort((a, b) {
          final yearA = a['year'] as String?;
          final yearB = b['year'] as String?;
          if (yearA == null || yearB == null) return 0;
          return yearA.compareTo(yearB);
        });
        
        return textbooks;
      }
      
      // Fallback to Firestore
      print('⚠️ Falling back to Firestore for textbooks');
      final snapshot = await _firestore
          .collection('textbooks')
          .where('subject', isEqualTo: 'English')
          .get();
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting textbooks: $e');
      return [];
    }
  }

  /// Get textbook for a specific year (from JSON assets with Firestore fallback)
  Future<Map<String, dynamic>?> getTextbook(String year) async {
    try {
      // Load from assets first
      await _loadTextbooksFromAssets();
      
      // Find in cache
      for (final textbook in _textbookCache.values) {
        if (textbook['year'] == year) {
          return textbook;
        }
      }
      
      // Fallback to Firestore
      print('⚠️ Falling back to Firestore for textbook: $year');
      final snapshot = await _firestore
          .collection('textbooks')
          .where('subject', isEqualTo: 'English')
          .where('year', isEqualTo: year)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return {
        'id': doc.id,
        ...doc.data(),
      };
    } catch (e) {
      print('Error fetching textbook: $e');
      return null;
    }
  }

  /// Get all chapters for a textbook (from JSON assets with Firestore fallback)
  Future<List<Map<String, dynamic>>> getChapters(String textbookId) async {
    try {
      // Load from assets first
      await _loadTextbooksFromAssets();
      
      // Check cache
      if (_textbookCache.containsKey(textbookId)) {
        final chapters = _textbookCache[textbookId]!['chapters'] as List;
        return chapters.map((ch) => ch as Map<String, dynamic>).toList();
      }
      
      // Fallback to Firestore
      print('⚠️ Falling back to Firestore for chapters: $textbookId');
      final snapshot = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('chapters')
          .orderBy('chapterNumber')
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error fetching chapters: $e');
      return [];
    }
  }

  /// Get all sections for a textbook (flattened from all chapters, from JSON with Firestore fallback)
  Future<List<Map<String, dynamic>>> getSections(String textbookId) async {
    try {
      // Load from assets first
      await _loadTextbooksFromAssets();
      
      // Check cache
      if (_textbookCache.containsKey(textbookId)) {
        final allSections = <Map<String, dynamic>>[];
        final chapters = _textbookCache[textbookId]!['chapters'] as List;
        
        for (var i = 0; i < chapters.length; i++) {
          final chapter = chapters[i] as Map<String, dynamic>;
          final sections = chapter['sections'] as List;
          
          for (var section in sections) {
            final sectionMap = section as Map<String, dynamic>;
            allSections.add({
              'id': sectionMap['id'],
              'chapterIndex': i,
              'chapterNumber': chapter['chapterNumber'],
              'chapterId': chapter['id'],
              ...sectionMap,
            });
          }
        }
        
        return allSections;
      }
      
      // Fallback to Firestore
      print('⚠️ Falling back to Firestore for sections: $textbookId');
      final allSections = <Map<String, dynamic>>[];
      
      // Get all chapters first
      final chaptersSnapshot = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('chapters')
          .orderBy('chapterNumber')
          .get();

      // For each chapter, get its sections
      for (var i = 0; i < chaptersSnapshot.docs.length; i++) {
        final chapterDoc = chaptersSnapshot.docs[i];
        final sectionsSnapshot = await chapterDoc.reference
            .collection('sections')
            .orderBy('sectionNumber')
            .get();

        for (var sectionDoc in sectionsSnapshot.docs) {
          final sectionData = sectionDoc.data();
          allSections.add({
            'id': sectionDoc.id,
            'chapterIndex': i,
            'chapterNumber': chapterDoc.data()['chapterNumber'],
            'chapterId': chapterDoc.id,
            ...sectionData,
          });
        }
      }

      return allSections;
    } catch (e) {
      print('Error fetching sections: $e');
      return [];
    }
  }

  /// Get section content (from JSON assets with Firestore fallback)
  Future<Map<String, dynamic>?> getSection(String textbookId, String chapterId, String sectionId) async {
    try {
      // Load from assets first
      await _loadTextbooksFromAssets();
      
      // Check cache
      if (_textbookCache.containsKey(textbookId)) {
        final chapters = _textbookCache[textbookId]!['chapters'] as List;
        
        for (final chapter in chapters) {
          final chapterMap = chapter as Map<String, dynamic>;
          if (chapterMap['id'] == chapterId) {
            final sections = chapterMap['sections'] as List;
            
            for (final section in sections) {
              final sectionMap = section as Map<String, dynamic>;
              if (sectionMap['id'] == sectionId) {
                return sectionMap;
              }
            }
          }
        }
      }
      
      // Fallback to Firestore
      print('⚠️ Falling back to Firestore for section: $textbookId/$chapterId/$sectionId');
      final doc = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('chapters')
          .doc(chapterId)
          .collection('sections')
          .doc(sectionId)
          .get();

      if (!doc.exists) return null;

      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      print('Error fetching section: $e');
      return null;
    }
  }

  /// Get questions for a section
  Future<List<Map<String, dynamic>>> getSectionQuestions(
    String textbookId,
    String sectionId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('questions')
          .where('sectionId', isEqualTo: sectionId)
          .where('questionType', isEqualTo: 'section')
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error fetching section questions: $e');
      return [];
    }
  }

  /// Get chapter review questions
  Future<List<Map<String, dynamic>>> getChapterQuestions(
    String textbookId,
    int chapterIndex,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('questions')
          .where('chapterIndex', isEqualTo: chapterIndex)
          .where('questionType', isEqualTo: 'chapter')
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error fetching chapter questions: $e');
      return [];
    }
  }

  /// Get year-end assessment questions
  Future<List<Map<String, dynamic>>> getYearEndQuestions(String textbookId) async {
    try {
      final snapshot = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('questions')
          .where('questionType', isEqualTo: 'yearEnd')
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error fetching year-end questions: $e');
      return [];
    }
  }

  /// Submit answer and award XP
  Future<Map<String, dynamic>> submitAnswer({
    required String textbookId,
    required String questionId,
    required String selectedAnswer,
    required String correctAnswer,
    required int xpValue,
    required String questionType, // 'section', 'chapter', 'yearEnd'
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'User not authenticated'};
    }

    final isCorrect = selectedAnswer == correctAnswer;
    final xpEarned = isCorrect ? xpValue : 0;

    try {
      final userProgressRef = _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('userProgress')
          .doc(user.uid);

      await _firestore.runTransaction((transaction) async {
        final progressDoc = await transaction.get(userProgressRef);
        final currentData = progressDoc.exists ? progressDoc.data()! : {};

        final answeredQuestions = List<String>.from(
          currentData['answeredQuestions'] ?? [],
        );
        
        if (!answeredQuestions.contains(questionId)) {
          answeredQuestions.add(questionId);
        }

        final correctAnswers = (currentData['correctAnswers'] ?? 0) + (isCorrect ? 1 : 0);
        final totalAnswers = (currentData['totalAnswers'] ?? 0) + 1;
        final totalXP = (currentData['totalXP'] ?? 0) + xpEarned;

        transaction.set(
          userProgressRef,
          {
            'answeredQuestions': answeredQuestions,
            'correctAnswers': correctAnswers,
            'totalAnswers': totalAnswers,
            'totalXP': totalXP,
            'lastActivity': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Award XP to user's main profile
        if (xpEarned > 0) {
          final userRef = _firestore.collection('users').doc(user.uid);
          transaction.update(userRef, {
            'badges.points': FieldValue.increment(xpEarned),
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }
      });

      return {
        'success': true,
        'isCorrect': isCorrect,
        'xpEarned': xpEarned,
      };
    } catch (e) {
      print('Error submitting answer: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark section as complete and award XP
  Future<Map<String, dynamic>> completionSection({
    required String textbookId,
    required String sectionId,
    required int xpReward,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'User not authenticated'};
    }

    try {
      final userProgressRef = _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('userProgress')
          .doc(user.uid);

      await _firestore.runTransaction((transaction) async {
        final progressDoc = await transaction.get(userProgressRef);
        final currentData = progressDoc.exists ? progressDoc.data()! : {};

        final completedSections = List<String>.from(
          currentData['completedSections'] ?? [],
        );

        // Only award XP if not already completed
        final isNewCompletion = !completedSections.contains(sectionId);
        final xpToAward = isNewCompletion ? xpReward : 0;

        if (isNewCompletion) {
          completedSections.add(sectionId);
        }

        transaction.set(
          userProgressRef,
          {
            'completedSections': completedSections,
            'totalXP': FieldValue.increment(xpToAward),
            'lastActivity': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Award XP to user's main profile
        if (xpToAward > 0) {
          final userRef = _firestore.collection('users').doc(user.uid);
          transaction.update(userRef, {
            'badges.points': FieldValue.increment(xpToAward),
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }
      });

      return {'success': true, 'xpEarned': xpReward};
    } catch (e) {
      print('Error completing section: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark chapter as complete and award XP
  Future<Map<String, dynamic>> completeChapter({
    required String textbookId,
    required int chapterIndex,
    required int xpReward,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'User not authenticated'};
    }

    try {
      final userProgressRef = _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('userProgress')
          .doc(user.uid);

      await _firestore.runTransaction((transaction) async {
        final progressDoc = await transaction.get(userProgressRef);
        final currentData = progressDoc.exists ? progressDoc.data()! : {};

        final completedChapters = List<int>.from(
          currentData['completedChapters'] ?? [],
        );

        final isNewCompletion = !completedChapters.contains(chapterIndex);
        final xpToAward = isNewCompletion ? xpReward : 0;

        if (isNewCompletion) {
          completedChapters.add(chapterIndex);
        }

        transaction.set(
          userProgressRef,
          {
            'completedChapters': completedChapters,
            'totalXP': FieldValue.increment(xpToAward),
            'lastActivity': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Award XP to user's main profile
        if (xpToAward > 0) {
          final userRef = _firestore.collection('users').doc(user.uid);
          transaction.update(userRef, {
            'badges.points': FieldValue.increment(xpToAward),
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }
      });

      return {'success': true, 'xpEarned': xpReward};
    } catch (e) {
      print('Error completing chapter: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark year as complete and award XP
  Future<Map<String, dynamic>> completeYear({
    required String textbookId,
    required int xpReward,
    required bool isAllYearsComplete,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'User not authenticated'};
    }

    try {
      final userProgressRef = _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('userProgress')
          .doc(user.uid);

      // Bonus XP if all 3 years are complete
      final bonusXP = isAllYearsComplete ? 5000 : 0;
      final totalXP = xpReward + bonusXP;

      await _firestore.runTransaction((transaction) async {
        transaction.set(
          userProgressRef,
          {
            'yearComplete': true,
            'completedAt': FieldValue.serverTimestamp(),
            'totalXP': FieldValue.increment(totalXP),
          },
          SetOptions(merge: true),
        );

        // Award XP to user's main profile
        final userRef = _firestore.collection('users').doc(user.uid);
        transaction.update(userRef, {
          'badges.points': FieldValue.increment(totalXP),
          'lastActivity': FieldValue.serverTimestamp(),
        });

        // Award special badge if all years complete
        if (isAllYearsComplete) {
          transaction.update(userRef, {
            'badges.earned': FieldValue.arrayUnion(['english_master_jhs']),
          });
        }
      });

      return {
        'success': true,
        'xpEarned': totalXP,
        'bonusXP': bonusXP,
      };
    } catch (e) {
      print('Error completing year: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get user's progress for a textbook
  Future<Map<String, dynamic>> getUserProgress(String textbookId) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final doc = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('userProgress')
          .doc(user.uid)
          .get();

      if (!doc.exists) return {};

      return doc.data()!;
    } catch (e) {
      print('Error fetching user progress: $e');
      return {};
    }
  }

  /// Check if user has completed all 3 years
  Future<bool> hasCompletedAllYears(String userId) async {
    try {
      final jhs1 = await _firestore
          .collection('textbooks')
          .where('subject', isEqualTo: 'English')
          .where('year', isEqualTo: 'JHS 1')
          .limit(1)
          .get();

      final jhs2 = await _firestore
          .collection('textbooks')
          .where('subject', isEqualTo: 'English')
          .where('year', isEqualTo: 'JHS 2')
          .limit(1)
          .get();

      final jhs3 = await _firestore
          .collection('textbooks')
          .where('subject', isEqualTo: 'English')
          .where('year', isEqualTo: 'JHS 3')
          .limit(1)
          .get();

      if (jhs1.docs.isEmpty || jhs2.docs.isEmpty || jhs3.docs.isEmpty) {
        return false;
      }

      final progress1 = await getUserProgress(jhs1.docs.first.id);
      final progress2 = await getUserProgress(jhs2.docs.first.id);
      final progress3 = await getUserProgress(jhs3.docs.first.id);

      return (progress1['yearComplete'] == true) &&
          (progress2['yearComplete'] == true) &&
          (progress3['yearComplete'] == true);
    } catch (e) {
      print('Error checking year completion: $e');
      return false;
    }
  }
}
