import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/textbook_model.dart';

import 'package:flutter/foundation.dart';
class TextbookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'textbooks';

  Future<List<Textbook>> getTextbooks() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      if (querySnapshot.docs.isEmpty) {
        // Return sample data if no textbooks in Firestore
        return _getSampleTextbooks();
      }
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Textbook.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching textbooks: $e');
      // Return sample data as fallback
      return _getSampleTextbooks();
    }
  }

  Future<List<Textbook>> getTextbooksByLevel(String level) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('level', isEqualTo: level)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Textbook.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching textbooks by level: $e');
      return [];
    }
  }

  Future<List<Textbook>> getTextbooksBySubject(String subject) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('subject', isEqualTo: subject)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Textbook.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching textbooks by subject: $e');
      return [];
    }
  }

  Future<List<Textbook>> searchTextbooks(String query) async {
    try {
      final textbooks = await getTextbooks();
      final lowercaseQuery = query.toLowerCase();
      
      return textbooks.where((textbook) {
        return textbook.title.toLowerCase().contains(lowercaseQuery) ||
            textbook.author.toLowerCase().contains(lowercaseQuery) ||
            textbook.subject.toLowerCase().contains(lowercaseQuery) ||
            textbook.topics.any((topic) => topic.toLowerCase().contains(lowercaseQuery));
      }).toList();
    } catch (e) {
      debugPrint('Error searching textbooks: $e');
      return [];
    }
  }

  Future<Textbook?> getTextbookById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return Textbook.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching textbook by ID: $e');
      return null;
    }
  }

  Future<void> incrementDownloadCount(String textbookId) async {
    try {
      await _firestore.collection(_collection).doc(textbookId).update({
        'downloads': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing download count: $e');
    }
  }

  List<Textbook> _getSampleTextbooks() {
    return [
      Textbook(
        id: '1',
        title: 'New General Mathematics for JHS 1',
        author: 'Prof. K. A. Dankwa',
        publisher: 'Unimax Macmillan',
        subject: 'Mathematics',
        level: 'JHS 1',
        pages: 280,
        description: 'Comprehensive mathematics textbook covering basic arithmetic, algebra, and geometry for JHS Form 1 students.',
        downloadUrl: '',
        isNew: true,
        publishedDate: DateTime(2024, 1, 15),
        topics: ['Arithmetic', 'Algebra', 'Geometry', 'Statistics'],
        rating: 4.5,
        downloads: 1250,
      ),
      Textbook(
        id: '2',
        title: 'English Language Skills for JHS',
        author: 'Dr. Margaret Amoah',
        publisher: 'Sedco Publishing',
        subject: 'English Language',
        level: 'JHS 2',
        pages: 320,
        description: 'Develops reading, writing, speaking, and listening skills with practical exercises and examples.',
        downloadUrl: '',
        isNew: false,
        publishedDate: DateTime(2023, 8, 20),
        topics: ['Grammar', 'Vocabulary', 'Comprehension', 'Essay Writing'],
        rating: 4.3,
        downloads: 980,
      ),
      Textbook(
        id: '3',
        title: 'Integrated Science for Basic Schools',
        author: 'Dr. Samuel Opoku & Dr. Grace Mensah',
        publisher: 'Sam-Woode Publishers',
        subject: 'Science',
        level: 'JHS 3',
        pages: 350,
        description: 'Covers physics, chemistry, and biology concepts integrated for comprehensive science education.',
        downloadUrl: '',
        isNew: true,
        publishedDate: DateTime(2024, 3, 10),
        topics: ['Physics', 'Chemistry', 'Biology', 'Environmental Science'],
        rating: 4.7,
        downloads: 1450,
      ),
      Textbook(
        id: '4',
        title: 'Our World Our People - Social Studies',
        author: 'Prof. Akwasi Wiredu',
        publisher: 'Goldfield Publishers',
        subject: 'Social Studies',
        level: 'JHS 1',
        pages: 250,
        description: 'Explores Ghanaian culture, history, geography, and civic education for young learners.',
        downloadUrl: '',
        isNew: false,
        publishedDate: DateTime(2023, 5, 12),
        topics: ['Ghanaian Culture', 'History', 'Geography', 'Civic Education'],
        rating: 4.2,
        downloads: 750,
      ),
      Textbook(
        id: '5',
        title: 'ICT for Basic Schools',
        author: 'Dr. Emmanuel Asante',
        publisher: 'Ministry of Education',
        subject: 'ICT',
        level: 'JHS 2',
        pages: 180,
        description: 'Introduction to computer literacy, basic programming, and digital citizenship.',
        downloadUrl: '',
        isNew: true,
        publishedDate: DateTime(2024, 2, 5),
        topics: ['Computer Basics', 'Internet Safety', 'Word Processing', 'Programming'],
        rating: 4.1,
        downloads: 650,
      ),
      Textbook(
        id: '6',
        title: 'Religious and Moral Education',
        author: 'Rev. Dr. Joseph Abeiku Mensah',
        publisher: 'Unimax Macmillan',
        subject: 'Religious & Moral Education',
        level: 'JHS 3',
        pages: 200,
        description: 'Teaches moral values, religious tolerance, and ethical decision-making.',
        downloadUrl: '',
        isNew: false,
        publishedDate: DateTime(2023, 9, 18),
        topics: ['Christian Values', 'Islamic Principles', 'Traditional Religion', 'Ethics'],
        rating: 4.4,
        downloads: 420,
      ),
      Textbook(
        id: '7',
        title: 'Creative Arts and Design',
        author: 'Mrs. Akosua Osei-Bonsu',
        publisher: 'Sedco Publishing',
        subject: 'Creative Arts',
        level: 'JHS 1',
        pages: 160,
        description: 'Develops artistic skills through drawing, painting, music, and drama activities.',
        downloadUrl: '',
        isNew: true,
        publishedDate: DateTime(2024, 1, 25),
        topics: ['Visual Arts', 'Music', 'Drama', 'Crafts'],
        rating: 4.6,
        downloads: 380,
      ),
      Textbook(
        id: '8',
        title: 'French Language for Beginners',
        author: 'Mme. Ama Serwaa',
        publisher: 'Sam-Woode Publishers',
        subject: 'French',
        level: 'JHS 2',
        pages: 220,
        description: 'Basic French language skills with emphasis on communication and culture.',
        downloadUrl: '',
        isNew: false,
        publishedDate: DateTime(2023, 7, 14),
        topics: ['Basic Grammar', 'Vocabulary', 'Pronunciation', 'French Culture'],
        rating: 4.0,
        downloads: 290,
      ),
    ];
  }
}
