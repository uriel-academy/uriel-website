import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mock_exam_model.dart';

class MockExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'mock_exams';

  Future<List<MockExam>> getMockExams() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      if (querySnapshot.docs.isEmpty) {
        // Return sample data if no mock exams in Firestore
        return _getSampleMockExams();
      }
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return MockExam.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching mock exams: $e');
      // Return sample data as fallback
      return _getSampleMockExams();
    }
  }

  Future<List<MockExam>> getMockExamsByType(String examType) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('examType', isEqualTo: examType)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return MockExam.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching mock exams by type: $e');
      return [];
    }
  }

  Future<List<MockExam>> getMockExamsBySubject(String subject) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('subject', isEqualTo: subject)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return MockExam.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error fetching mock exams by subject: $e');
      return [];
    }
  }

  Future<List<MockExam>> searchMockExams(String query) async {
    try {
      final mockExams = await getMockExams();
      final lowercaseQuery = query.toLowerCase();
      
      return mockExams.where((exam) {
        return exam.title.toLowerCase().contains(lowercaseQuery) ||
            exam.description.toLowerCase().contains(lowercaseQuery) ||
            exam.subject.toLowerCase().contains(lowercaseQuery) ||
            exam.topics.any((topic) => topic.toLowerCase().contains(lowercaseQuery));
      }).toList();
    } catch (e) {
      print('Error searching mock exams: $e');
      return [];
    }
  }

  Future<MockExam?> getMockExamById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return MockExam.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching mock exam by ID: $e');
      return null;
    }
  }

  Future<void> updateExamProgress(String examId, int score, DateTime completedDate) async {
    try {
      await _firestore.collection(_collection).doc(examId).update({
        'isCompleted': true,
        'lastScore': score,
        'lastAttemptDate': completedDate.toIso8601String(),
        'currentAttempts': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error updating exam progress: $e');
    }
  }

  List<MockExam> _getSampleMockExams() {
    return [
      MockExam(
        id: '1',
        title: 'BECE 2024 Mathematics Mock Exam',
        description: 'Comprehensive mathematics mock examination based on the 2024 BECE format with detailed solutions.',
        examType: 'BECE',
        subject: 'Mathematics',
        difficulty: 'Medium',
        year: '2024',
        duration: 120,
        totalQuestions: 40,
        totalMarks: 100,
        isCompleted: true,
        lastScore: 78,
        lastAttemptDate: DateTime(2024, 8, 15),
        topics: ['Algebra', 'Geometry', 'Statistics', 'Arithmetic'],
        instructions: 'Answer all questions. Use mathematical instruments where necessary. Show all workings clearly.',
        currentAttempts: 1,
      ),
      MockExam(
        id: '2',
        title: 'BECE 2024 English Language Mock',
        description: 'Complete English Language practice exam covering comprehension, essay writing, and objective questions.',
        examType: 'BECE',
        subject: 'English Language',
        difficulty: 'Medium',
        year: '2024',
        duration: 180,
        totalQuestions: 60,
        totalMarks: 100,
        isCompleted: false,
        topics: ['Comprehension', 'Grammar', 'Vocabulary', 'Essay Writing', 'Letter Writing'],
        instructions: 'Read all instructions carefully. Plan your essay before writing. Pay attention to spelling and punctuation.',
        currentAttempts: 0,
      ),
      MockExam(
        id: '3',
        title: 'BECE 2024 Integrated Science Mock',
        description: 'Science mock exam covering physics, chemistry, and biology concepts from the JHS curriculum.',
        examType: 'BECE',
        subject: 'Integrated Science',
        difficulty: 'Hard',
        year: '2024',
        duration: 120,
        totalQuestions: 50,
        totalMarks: 100,
        isCompleted: true,
        lastScore: 85,
        lastAttemptDate: DateTime(2024, 9, 10),
        topics: ['Physics', 'Chemistry', 'Biology', 'Environmental Science'],
        instructions: 'Answer all questions. Draw diagrams where necessary. Use scientific terms appropriately.',
        currentAttempts: 2,
      ),
      MockExam(
        id: '4',
        title: 'BECE 2024 Social Studies Mock',
        description: 'Comprehensive social studies examination covering Ghanaian history, geography, and civic education.',
        examType: 'BECE',
        subject: 'Social Studies',
        difficulty: 'Medium',
        year: '2024',
        duration: 120,
        totalQuestions: 45,
        totalMarks: 100,
        isCompleted: false,
        topics: ['History', 'Geography', 'Civic Education', 'Economics'],
        instructions: 'Answer all questions. Support your answers with relevant examples. Write legibly.',
        currentAttempts: 0,
      ),
      MockExam(
        id: '5',
        title: 'WASSCE 2024 Core Mathematics',
        description: 'Core Mathematics mock examination for WASSCE candidates with detailed marking scheme.',
        examType: 'WASSCE',
        subject: 'Mathematics',
        difficulty: 'Hard',
        year: '2024',
        duration: 180,
        totalQuestions: 50,
        totalMarks: 100,
        isCompleted: true,
        lastScore: 68,
        lastAttemptDate: DateTime(2024, 7, 20),
        topics: ['Functions', 'Trigonometry', 'Calculus', 'Statistics', 'Coordinate Geometry'],
        instructions: 'Answer all questions in Section A and any 4 questions from Section B. Use approved calculators.',
        currentAttempts: 1,
      ),
      MockExam(
        id: '6',
        title: 'WASSCE 2024 Physics Mock',
        description: 'Advanced physics mock exam covering mechanics, waves, electricity, and modern physics.',
        examType: 'WASSCE',
        subject: 'Physics',
        difficulty: 'Expert',
        year: '2024',
        duration: 180,
        totalQuestions: 50,
        totalMarks: 100,
        isCompleted: false,
        topics: ['Mechanics', 'Waves', 'Electricity', 'Magnetism', 'Modern Physics'],
        instructions: 'Answer all questions in Section A and any 4 questions from Section B. Show all calculations.',
        currentAttempts: 0,
      ),
      MockExam(
        id: '7',
        title: 'NECO 2024 Chemistry Practice',
        description: 'Chemistry practice test with emphasis on practical applications and theoretical concepts.',
        examType: 'NECO',
        subject: 'Chemistry',
        difficulty: 'Hard',
        year: '2024',
        duration: 150,
        totalQuestions: 45,
        totalMarks: 100,
        isCompleted: false,
        topics: ['Atomic Structure', 'Chemical Bonding', 'Acids and Bases', 'Organic Chemistry'],
        instructions: 'Answer all questions. Use the periodic table provided. Express answers to appropriate significant figures.',
        currentAttempts: 0,
      ),
      MockExam(
        id: '8',
        title: 'Custom Mathematics Quiz',
        description: 'Custom-created mathematics quiz focusing on algebra and geometry for JHS students.',
        examType: 'Custom',
        subject: 'Mathematics',
        difficulty: 'Easy',
        year: '2024',
        duration: 60,
        totalQuestions: 20,
        totalMarks: 50,
        isCompleted: true,
        lastScore: 95,
        lastAttemptDate: DateTime(2024, 9, 25),
        topics: ['Basic Algebra', 'Geometry', 'Fractions'],
        instructions: 'Answer all questions. Show your working. Time limit is strictly enforced.',
        currentAttempts: 1,
      ),
    ];
  }
}