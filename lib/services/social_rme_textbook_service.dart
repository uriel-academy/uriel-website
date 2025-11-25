import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing Social Studies and RME textbooks from JSON assets
/// These textbooks were generated using OpenAI GPT-4o
class SocialRmeTextbookService {
  static final SocialRmeTextbookService _instance = SocialRmeTextbookService._internal();
  factory SocialRmeTextbookService() => _instance;
  SocialRmeTextbookService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cache for loaded textbooks
  final Map<String, Map<String, dynamic>> _textbookCache = {};
  bool _socialStudiesLoaded = false;
  bool _rmeLoaded = false;

  /// Get cover image path for a textbook
  String getCoverImage(String subject, String year) {
    final yearNum = year.replaceAll('JHS ', '');
    if (subject.toLowerCase().contains('social')) {
      return 'assets/social-studies_jhs$yearNum.png';
    } else if (subject.toLowerCase().contains('rme') || 
               subject.toLowerCase().contains('religious')) {
      return 'assets/rme_jhs$yearNum.png';
    }
    return '';
  }

  /// Get all Social Studies textbooks from JSON assets
  Future<List<Map<String, dynamic>>> getSocialStudiesTextbooks() async {
    if (_socialStudiesLoaded && _textbookCache.isNotEmpty) {
      return _textbookCache.values
          .where((t) => t['subject'] == 'Social Studies')
          .map((t) => {
                'id': t['id'],
                'subject': t['subject'],
                'year': t['year'],
                'title': t['title'],
                'description': t['description'],
                'coverImage': t['coverImage'],
                'totalChapters': t['totalChapters'],
                'totalSections': t['totalSections'],
                'totalQuestions': t['totalQuestions'],
                'features': t['features'],
              })
          .toList();
    }

    try {
      final textbooks = <Map<String, dynamic>>[];
      final textbookIds = [
        'social_studies_jhs_1',
        'social_studies_jhs_2',
        'social_studies_jhs_3',
      ];

      for (final id in textbookIds) {
        try {
          final jsonString = await rootBundle
              .loadString('assets/textbooks/$id.json');
          final data = json.decode(jsonString) as Map<String, dynamic>;
          
          // Cache the full textbook
          _textbookCache[id] = data;
          
          // Add to list
          textbooks.add({
            'id': data['id'],
            'subject': data['subject'],
            'year': data['year'],
            'title': data['title'],
            'description': data['description'] ?? '',
            'coverImage': data['coverImage'],
            'totalChapters': data['totalChapters'],
            'totalSections': data['totalSections'],
            'totalQuestions': data['totalQuestions'],
            'features': data['features'] ?? [],
          });
        } catch (e) {
          debugPrint('⚠️ Could not load $id: $e');
        }
      }
      
      _socialStudiesLoaded = true;
      debugPrint('📚 Loaded ${textbooks.length} Social Studies textbooks');
      return textbooks;
    } catch (e) {
      debugPrint('❌ Error loading Social Studies textbooks: $e');
      return [];
    }
  }

  /// Get all RME textbooks from JSON assets
  Future<List<Map<String, dynamic>>> getRmeTextbooks() async {
    if (_rmeLoaded && _textbookCache.isNotEmpty) {
      return _textbookCache.values
          .where((t) => t['subject'] == 'Religious and Moral Education')
          .map((t) => {
                'id': t['id'],
                'subject': 'RME',
                'fullSubject': t['subject'],
                'year': t['year'],
                'title': t['title'],
                'description': t['description'],
                'coverImage': t['coverImage'],
                'totalChapters': t['totalChapters'],
                'totalSections': t['totalSections'],
                'totalQuestions': t['totalQuestions'],
                'features': t['features'],
              })
          .toList();
    }

    try {
      final textbooks = <Map<String, dynamic>>[];
      final textbookIds = [
        'religious_and_moral_education_jhs_1',
        'religious_and_moral_education_jhs_2',
        // Note: JHS 3 not included as it has no content yet
      ];

      for (final id in textbookIds) {
        try {
          final jsonString = await rootBundle
              .loadString('assets/textbooks/$id.json');
          final data = json.decode(jsonString) as Map<String, dynamic>;
          
          // Cache the full textbook
          _textbookCache[id] = data;
          
          // Add to list
          textbooks.add({
            'id': data['id'],
            'subject': 'RME',
            'fullSubject': data['subject'],
            'year': data['year'],
            'title': data['title'],
            'description': data['description'] ?? '',
            'coverImage': data['coverImage'],
            'totalChapters': data['totalChapters'],
            'totalSections': data['totalSections'],
            'totalQuestions': data['totalQuestions'],
            'features': data['features'] ?? [],
          });
        } catch (e) {
          debugPrint('⚠️ Could not load $id: $e');
        }
      }
      
      _rmeLoaded = true;
      debugPrint('📚 Loaded ${textbooks.length} RME textbooks');
      return textbooks;
    } catch (e) {
      debugPrint('❌ Error loading RME textbooks: $e');
      return [];
    }
  }

  /// Get all textbooks (both Social Studies and RME)
  Future<List<Map<String, dynamic>>> getAllTextbooks() async {
    final socialStudies = await getSocialStudiesTextbooks();
    final rme = await getRmeTextbooks();
    return [...socialStudies, ...rme];
  }

  /// Get textbook by ID
  Future<Map<String, dynamic>?> getTextbook(String textbookId) async {
    try {
      // Check cache first
      if (_textbookCache.containsKey(textbookId)) {
        return _textbookCache[textbookId];
      }
      
      // Load from JSON
      try {
        final jsonString = await rootBundle
            .loadString('assets/textbooks/$textbookId.json');
        final data = json.decode(jsonString) as Map<String, dynamic>;
        _textbookCache[textbookId] = data;
        return data;
      } catch (e) {
        debugPrint('⚠️ Could not load textbook $textbookId from JSON: $e');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error loading textbook $textbookId: $e');
      return null;
    }
  }

  /// Get all chapters for a textbook
  Future<List<Map<String, dynamic>>> getChapters(String textbookId) async {
    try {
      final textbook = await getTextbook(textbookId);
      if (textbook == null) {
        return [];
      }
      
      final chapters = (textbook['chapters'] as List<dynamic>?)
          ?.map((c) => c as Map<String, dynamic>)
          .toList() ?? [];
      
      debugPrint('📖 Loaded ${chapters.length} chapters for $textbookId');
      return chapters;
    } catch (e) {
      debugPrint('❌ Error loading chapters: $e');
      return [];
    }
  }

  /// Get all sections for a chapter
  Future<List<Map<String, dynamic>>> getSections(
      String textbookId, String chapterId) async {
    try {
      final chapters = await getChapters(textbookId);
      final chapter = chapters.firstWhere(
        (c) => c['id'] == chapterId,
        orElse: () => <String, dynamic>{},
      );
      
      if (chapter.isEmpty) {
        return [];
      }
      
      final sections = (chapter['sections'] as List<dynamic>?)
          ?.map((s) => s as Map<String, dynamic>)
          .toList() ?? [];
      
      debugPrint('📄 Loaded ${sections.length} sections for chapter $chapterId');
      return sections;
    } catch (e) {
      debugPrint('❌ Error loading sections: $e');
      return [];
    }
  }

  /// Get section content
  Future<Map<String, dynamic>?> getSection(
      String textbookId, String chapterId, String sectionId) async {
    try {
      final sections = await getSections(textbookId, chapterId);
      final section = sections.firstWhere(
        (s) => s['id'] == sectionId,
        orElse: () => <String, dynamic>{},
      );
      
      return section.isNotEmpty ? section : null;
    } catch (e) {
      debugPrint('❌ Error loading section: $e');
      return null;
    }
  }

  /// Get questions for a section
  Future<List<Map<String, dynamic>>> getQuestions(
      String textbookId, String chapterId, String sectionId) async {
    try {
      final section = await getSection(textbookId, chapterId, sectionId);
      if (section == null) {
        return [];
      }
      
      final questions = (section['questions'] as List<dynamic>?)
          ?.map((q) => q as Map<String, dynamic>)
          .toList() ?? [];
      
      return questions;
    } catch (e) {
      debugPrint('❌ Error loading questions: $e');
      return [];
    }
  }

  /// Get user's progress for a textbook
  Future<Map<String, dynamic>> getUserProgress(String textbookId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {};
    }

    try {
      final doc = await _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('userProgress')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        return {
          'completedSections': <String>[],
          'completedChapters': <String>[],
          'totalXP': 0,
          'lastAccessed': null,
        };
      }

      return doc.data() ?? {};
    } catch (e) {
      debugPrint('❌ Error loading user progress: $e');
      return {};
    }
  }

  /// Mark section as complete and award XP
  Future<void> completeSection(
      String textbookId, String chapterId, String sectionId, int xpReward) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final progressRef = _firestore
          .collection('textbooks')
          .doc(textbookId)
          .collection('userProgress')
          .doc(user.uid);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(progressRef);
        
        List<String> completedSections;
        int totalXP;
        
        if (snapshot.exists) {
          final data = snapshot.data()!;
          completedSections = List<String>.from(data['completedSections'] ?? []);
          totalXP = data['totalXP'] ?? 0;
        } else {
          completedSections = [];
          totalXP = 0;
        }

        // Add section if not already completed
        if (!completedSections.contains(sectionId)) {
          completedSections.add(sectionId);
          totalXP += xpReward;

          transaction.set(progressRef, {
            'completedSections': completedSections,
            'totalXP': totalXP,
            'lastAccessed': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Also update user's global XP (using totalXP field)
          final userRef = _firestore.collection('users').doc(user.uid);
          transaction.update(userRef, {
            'totalXP': FieldValue.increment(xpReward),
            'lastXPUpdate': FieldValue.serverTimestamp(),
          });
          
          // Log XP transaction for tracking
          final xpTransactionRef = _firestore.collection('xp_transactions').doc();
          transaction.set(xpTransactionRef, {
            'userId': user.uid,
            'xpAmount': xpReward,
            'source': 'textbook',
            'details': {
              'textbookId': textbookId,
              'chapterId': chapterId,
              'sectionId': sectionId,
              'action': 'section_completion',
            },
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Error completing section: $e');
    }
  }

  /// Submit answer to a question and award XP if correct
  Future<bool> submitAnswer(
      String textbookId,
      String chapterId,
      String sectionId,
      String questionId,
      String answer,
      String correctAnswer,
      int xpReward) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final isCorrect = answer.toLowerCase().trim() == correctAnswer.toLowerCase().trim();

    if (isCorrect) {
      try {
        // Award XP to user's main profile (using totalXP field)
        final userRef = _firestore.collection('users').doc(user.uid);
        await userRef.update({
          'totalXP': FieldValue.increment(xpReward),
          'lastXPUpdate': FieldValue.serverTimestamp(),
        });

        // Track answer in progress
        final progressRef = _firestore
            .collection('textbooks')
            .doc(textbookId)
            .collection('userProgress')
            .doc(user.uid);

        await progressRef.set({
          'totalXP': FieldValue.increment(xpReward),
          'lastAccessed': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        // Log XP transaction for tracking
        await _firestore.collection('xp_transactions').add({
          'userId': user.uid,
          'xpAmount': xpReward,
          'source': 'textbook',
          'details': {
            'textbookId': textbookId,
            'chapterId': chapterId,
            'sectionId': sectionId,
            'questionId': questionId,
            'action': 'correct_answer',
          },
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ Awarded $xpReward XP for correct answer');
      } catch (e) {
        debugPrint('❌ Error submitting answer: $e');
      }
    }

    return isCorrect;
  }
}
