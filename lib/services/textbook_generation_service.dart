import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for generating and managing AI-generated textbook content
/// Uses Claude AI via Cloud Functions for high-quality educational content
class TextbookGenerationService {
  static final TextbookGenerationService _instance = TextbookGenerationService._internal();
  factory TextbookGenerationService() => _instance;
  TextbookGenerationService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate textbook content for a single topic
  /// 
  /// Parameters:
  /// - [subject]: Subject name (e.g., "Mathematics", "Science")
  /// - [topic]: Specific topic (e.g., "Quadratic Equations", "Cell Biology")
  /// - [grade]: Grade level (BECE, WASSCE, JHS 1-3, SHS 1-3)
  /// - [syllabusReference]: Optional NACCA syllabus reference
  /// - [contentType]: Type of content (full_lesson, summary, practice_questions, worked_examples)
  /// - [language]: Language code (en, tw, ee, ga)
  Future<Map<String, dynamic>> generateContent({
    required String subject,
    required String topic,
    String? syllabusReference,
    String grade = 'BECE',
    String contentType = 'full_lesson',
    String language = 'en',
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateTextbookContent')
          .call({
        'subject': subject,
        'topic': topic,
        'syllabusReference': syllabusReference,
        'grade': grade,
        'contentType': contentType,
        'language': language,
      });

      return {
        'success': true,
        'id': result.data['id'],
        'content': result.data['content'],
        'metadata': result.data['metadata'],
      };
    } catch (e) {
      print('Error generating textbook content: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Generate an entire chapter with multiple topics
  /// 
  /// Parameters:
  /// - [subject]: Subject name
  /// - [chapterTitle]: Title of the chapter
  /// - [topics]: List of topics with titles and optional syllabus references
  /// - [grade]: Grade level
  Future<Map<String, dynamic>> generateChapter({
    required String subject,
    required String chapterTitle,
    required List<Map<String, String>> topics,
    String grade = 'BECE',
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateChapter')
          .call({
        'subject': subject,
        'chapterTitle': chapterTitle,
        'topics': topics,
        'grade': grade,
      });

      return {
        'success': true,
        'chapterId': result.data['chapterId'],
        'sections': result.data['sections'],
        'totalSections': result.data['totalSections'],
      };
    } catch (e) {
      print('Error generating chapter: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Bulk generate content for multiple topics (background processing)
  /// 
  /// Parameters:
  /// - [subject]: Subject name
  /// - [topics]: List of topics to generate
  /// - [grade]: Grade level
  /// - [batchSize]: Number of topics to process concurrently (1-10)
  Future<Map<String, dynamic>> bulkGenerateContent({
    required String subject,
    required List<Map<String, String>> topics,
    String grade = 'BECE',
    int batchSize = 5,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('bulkGenerateContent')
          .call({
        'subject': subject,
        'topics': topics,
        'grade': grade,
        'batchSize': batchSize,
      });

      return {
        'success': true,
        'jobId': result.data['jobId'],
        'totalTopics': result.data['totalTopics'],
        'successfulTopics': result.data['successfulTopics'],
        'failedTopics': result.data['failedTopics'],
        'results': result.data['results'],
      };
    } catch (e) {
      print('Error in bulk generation: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Publish draft content (make it available to students)
  /// Requires admin privileges
  Future<Map<String, dynamic>> publishContent(String contentId) async {
    try {
      final result = await _functions
          .httpsCallable('publishTextbookContent')
          .call({'contentId': contentId});

      return {
        'success': true,
        'contentId': result.data['contentId'],
      };
    } catch (e) {
      print('Error publishing content: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get generated content by ID
  Future<Map<String, dynamic>?> getContent(String contentId) async {
    try {
      final doc = await _firestore
          .collection('textbook_content')
          .doc(contentId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching content: $e');
      return null;
    }
  }

  /// Get all content for a subject
  Future<List<Map<String, dynamic>>> getContentBySubject({
    required String subject,
    String? grade,
    String status = 'published',
  }) async {
    try {
      Query query = _firestore
          .collection('textbook_content')
          .where('subject', isEqualTo: subject)
          .where('status', isEqualTo: status);

      if (grade != null) {
        query = query.where('grade', isEqualTo: grade);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching content by subject: $e');
      return [];
    }
  }

  /// Get chapter details with all sections
  Future<Map<String, dynamic>?> getChapter(String chapterId) async {
    try {
      final chapterDoc = await _firestore
          .collection('textbook_chapters')
          .doc(chapterId)
          .get();

      if (!chapterDoc.exists) return null;

      final chapterData = chapterDoc.data()!;
      final sections = chapterData['sections'] as List<dynamic>;

      // Fetch all section content
      final sectionContent = await Future.wait(
        sections.map((section) async {
          final contentId = section['contentId'];
          final content = await getContent(contentId);
          return {
            'topicTitle': section['topicTitle'],
            'contentId': contentId,
            'content': content,
          };
        }),
      );

      return {
        'id': chapterId,
        'title': chapterData['title'],
        'subject': chapterData['subject'],
        'grade': chapterData['grade'],
        'sections': sectionContent,
        'totalSections': chapterData['totalSections'],
        'createdAt': chapterData['createdAt'],
        'status': chapterData['status'],
      };
    } catch (e) {
      print('Error fetching chapter: $e');
      return null;
    }
  }

  /// Monitor bulk generation job progress
  Stream<Map<String, dynamic>> watchBulkGenerationJob(String jobId) {
    return _firestore
        .collection('textbook_generation_jobs')
        .doc(jobId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return {'status': 'not_found'};
      }

      final data = snapshot.data()!;
      return {
        'status': data['status'],
        'totalTopics': data['totalTopics'],
        'processedTopics': data['processedTopics'],
        'results': data['results'] ?? [],
        'progress': (data['processedTopics'] ?? 0) / (data['totalTopics'] ?? 1),
      };
    });
  }

  /// Get all chapters for a subject
  Future<List<Map<String, dynamic>>> getChaptersBySubject({
    required String subject,
    String? grade,
  }) async {
    try {
      Query query = _firestore
          .collection('textbook_chapters')
          .where('subject', isEqualTo: subject);

      if (grade != null) {
        query = query.where('grade', isEqualTo: grade);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching chapters: $e');
      return [];
    }
  }

  /// Search textbook content
  Future<List<Map<String, dynamic>>> searchContent({
    required String searchQuery,
    String? subject,
    String? grade,
  }) async {
    try {
      Query query = _firestore
          .collection('textbook_content')
          .where('status', isEqualTo: 'published');

      if (subject != null) {
        query = query.where('subject', isEqualTo: subject);
      }

      if (grade != null) {
        query = query.where('grade', isEqualTo: grade);
      }

      final snapshot = await query.get();
      
      // Client-side filtering for search (Firestore doesn't support full-text search natively)
      final results = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .where((content) {
            final topic = (content['topic'] ?? '').toString().toLowerCase();
            final contentText = (content['content'] ?? '').toString().toLowerCase();
            final query = searchQuery.toLowerCase();
            return topic.contains(query) || contentText.contains(query);
          })
          .toList();

      return results;
    } catch (e) {
      print('Error searching content: $e');
      return [];
    }
  }

  /// Delete content (admin only)
  Future<bool> deleteContent(String contentId) async {
    try {
      await _firestore.collection('textbook_content').doc(contentId).delete();
      return true;
    } catch (e) {
      print('Error deleting content: $e');
      return false;
    }
  }

  /// Update content status (draft, published, archived)
  Future<bool> updateContentStatus(String contentId, String status) async {
    try {
      await _firestore.collection('textbook_content').doc(contentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating content status: $e');
      return false;
    }
  }
}
