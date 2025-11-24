import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trivia_model.dart';

import 'package:flutter/foundation.dart';
class TriviaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'trivia_challenges';

  Future<List<TriviaChallenge>> getTriviaChallenges() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      if (querySnapshot.docs.isEmpty) {
        // Return sample data if no trivia challenges in Firestore
        return _getSampleTriviaChallenges();
      }
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TriviaChallenge.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching trivia challenges: $e');
      // Return sample data as fallback
      return _getSampleTriviaChallenges();
    }
  }

  Future<List<TriviaChallenge>> getChallengesByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TriviaChallenge.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching challenges by category: $e');
      return [];
    }
  }

  Future<List<TriviaChallenge>> getChallengesByDifficulty(String difficulty) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('difficulty', isEqualTo: difficulty)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TriviaChallenge.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching challenges by difficulty: $e');
      return [];
    }
  }

  Future<List<TriviaChallenge>> searchChallenges(String query) async {
    try {
      final challenges = await getTriviaChallenges();
      final lowercaseQuery = query.toLowerCase();
      
      return challenges.where((challenge) {
        return challenge.title.toLowerCase().contains(lowercaseQuery) ||
            challenge.description.toLowerCase().contains(lowercaseQuery) ||
            challenge.category.toLowerCase().contains(lowercaseQuery) ||
            challenge.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
      }).toList();
    } catch (e) {
      debugPrint('Error searching challenges: $e');
      return [];
    }
  }

  Future<TriviaChallenge?> getChallengeById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return TriviaChallenge.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching challenge by ID: $e');
      return null;
    }
  }

  Future<void> incrementParticipants(String challengeId) async {
    try {
      await _firestore.collection(_collection).doc(challengeId).update({
        'participants': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing participants: $e');
    }
  }

  Future<void> submitTriviaResult(TriviaResult result) async {
    try {
      await _firestore.collection('trivia_results').add(result.toJson());
      await incrementParticipants(result.challengeId);
    } catch (e) {
      debugPrint('Error submitting trivia result: $e');
    }
  }

  Future<List<TriviaResult>> getUserResults(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('trivia_results')
          .where('userId', isEqualTo: userId)
          .orderBy('completedDate', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TriviaResult.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching user results: $e');
      return [];
    }
  }

  List<TriviaChallenge> _getSampleTriviaChallenges() {
    return [
      TriviaChallenge(
        id: '1',
        title: 'Ghana Independence Day Quiz',
        description: 'Test your knowledge about Ghana\'s journey to independence with this special challenge featuring questions about our nation\'s history.',
        category: 'History',
        difficulty: 'Medium',
        gameMode: 'Quick Play',
        questionCount: 20,
        timeLimit: 15,
        points: 500,
        isNew: true,
        createdDate: DateTime(2024, 3, 1),
        participants: 1250,
        tags: ['Ghana', 'Independence', 'History', 'National'],
        rules: {'allowRetry': true, 'shuffleQuestions': true, 'showCorrectAnswers': true},
        minLevel: 1,
      ),
      TriviaChallenge(
        id: '2',
        title: 'Mathematics Lightning Round',
        description: 'Quick-fire mathematics questions covering basic arithmetic, algebra, and geometry. Perfect for sharpening your math skills!',
        category: 'Mathematics',
        difficulty: 'Easy',
        gameMode: 'Quick Play',
        questionCount: 15,
        timeLimit: 10,
        points: 300,
        isNew: false,
        createdDate: DateTime(2024, 2, 15),
        participants: 2100,
        tags: ['Math', 'Quick', 'Basic', 'Skills'],
        rules: {'allowRetry': true, 'shuffleQuestions': true, 'showCorrectAnswers': false},
        minLevel: 1,
      ),
      TriviaChallenge(
        id: '3',
        title: 'Science Exploration Challenge',
        description: 'Dive deep into the world of science with questions covering physics, chemistry, and biology concepts.',
        category: 'Science',
        difficulty: 'Hard',
        gameMode: 'Tournament',
        questionCount: 30,
        timeLimit: 25,
        points: 750,
        isNew: true,
        createdDate: DateTime(2024, 3, 10),
        participants: 890,
        tags: ['Science', 'Physics', 'Chemistry', 'Biology'],
        rules: {'allowRetry': false, 'shuffleQuestions': true, 'showCorrectAnswers': true},
        minLevel: 2,
      ),
      TriviaChallenge(
        id: '4',
        title: 'English Grammar Master',
        description: 'Challenge your English language skills with grammar, vocabulary, and comprehension questions.',
        category: 'English',
        difficulty: 'Medium',
        gameMode: 'Daily Challenge',
        questionCount: 25,
        timeLimit: 20,
        points: 600,
        isNew: false,
        createdDate: DateTime(2024, 2, 28),
        expiryDate: DateTime(2024, 12, 31),
        participants: 1650,
        tags: ['English', 'Grammar', 'Vocabulary', 'Language'],
        rules: {'allowRetry': true, 'shuffleQuestions': false, 'showCorrectAnswers': true},
        minLevel: 1,
      ),
      TriviaChallenge(
        id: '5',
        title: 'African Geography Quest',
        description: 'Explore the diverse geography of Africa with questions about countries, capitals, rivers, and landmarks.',
        category: 'Geography',
        difficulty: 'Medium',
        gameMode: 'Quick Play',
        questionCount: 18,
        timeLimit: 12,
        points: 450,
        isNew: true,
        createdDate: DateTime(2024, 3, 5),
        participants: 750,
        tags: ['Geography', 'Africa', 'Countries', 'Capitals'],
        rules: {'allowRetry': true, 'shuffleQuestions': true, 'showCorrectAnswers': true},
        minLevel: 1,
      ),
      TriviaChallenge(
        id: '6',
        title: 'Technology & Innovation Quiz',
        description: 'Test your knowledge of modern technology, computer science, and digital innovations.',
        category: 'Technology',
        difficulty: 'Hard',
        gameMode: 'Tournament',
        questionCount: 22,
        timeLimit: 18,
        points: 550,
        isNew: false,
        createdDate: DateTime(2024, 1, 20),
        participants: 1100,
        tags: ['Technology', 'Computers', 'Innovation', 'Digital'],
        rules: {'allowRetry': false, 'shuffleQuestions': true, 'showCorrectAnswers': false},
        minLevel: 3,
      ),
      TriviaChallenge(
        id: '7',
        title: 'Sports Championship Quiz',
        description: 'From football to athletics, test your knowledge of sports history, rules, and famous athletes.',
        category: 'Sports',
        difficulty: 'Easy',
        gameMode: 'Multiplayer',
        questionCount: 16,
        timeLimit: 14,
        points: 400,
        isNew: true,
        createdDate: DateTime(2024, 3, 8),
        participants: 920,
        tags: ['Sports', 'Football', 'Athletics', 'Champions'],
        rules: {'allowRetry': true, 'shuffleQuestions': true, 'showCorrectAnswers': true},
        minLevel: 1,
        isMultiplayer: true,
        maxPlayers: 4,
      ),
      TriviaChallenge(
        id: '8',
        title: 'Art & Culture Celebration',
        description: 'Discover the rich cultural heritage of Ghana and Africa through art, music, and traditional practices.',
        category: 'Arts & Culture',
        difficulty: 'Medium',
        gameMode: 'Quick Play',
        questionCount: 20,
        timeLimit: 16,
        points: 500,
        isNew: false,
        createdDate: DateTime(2024, 2, 10),
        participants: 680,
        tags: ['Culture', 'Art', 'Music', 'Tradition'],
        rules: {'allowRetry': true, 'shuffleQuestions': false, 'showCorrectAnswers': true},
        minLevel: 1,
      ),
      TriviaChallenge(
        id: '9',
        title: 'General Knowledge Ultimate',
        description: 'The ultimate test of your general knowledge covering various topics from around the world.',
        category: 'General Knowledge',
        difficulty: 'Expert',
        gameMode: 'Tournament',
        questionCount: 35,
        timeLimit: 30,
        points: 1000,
        isNew: true,
        createdDate: DateTime(2024, 3, 12),
        participants: 450,
        tags: ['General', 'Knowledge', 'Ultimate', 'Challenge'],
        rules: {'allowRetry': false, 'shuffleQuestions': true, 'showCorrectAnswers': false},
        minLevel: 4,
      ),
      TriviaChallenge(
        id: '10',
        title: 'Daily Brain Teaser',
        description: 'Start your day with fun and challenging questions designed to stimulate your mind.',
        category: 'General Knowledge',
        difficulty: 'Easy',
        gameMode: 'Daily Challenge',
        questionCount: 10,
        timeLimit: 8,
        points: 200,
        isNew: false,
        createdDate: DateTime(2024, 1, 1),
        expiryDate: DateTime(2024, 12, 31),
        participants: 3200,
        tags: ['Daily', 'Brain', 'Teaser', 'Morning'],
        rules: {'allowRetry': true, 'shuffleQuestions': true, 'showCorrectAnswers': true},
        minLevel: 1,
      ),
    ];
  }
}
