import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get BECE RME past questions from storage
  static Future<List<PastQuestion>> getBECERMEQuestions() async {
    try {
      final ListResult result = await _storage.ref('bece-rme questions').listAll();
      
      List<PastQuestion> questions = [];
      
      for (var item in result.items) {
        final String downloadUrl = await item.getDownloadURL();
        final FullMetadata metadata = await item.getMetadata();
        
        questions.add(PastQuestion(
          id: item.name,
          title: item.name.replaceAll('.pdf', '').replaceAll('_', ' '),
          subject: 'Religious and Moral Education',
          year: extractYearFromFileName(item.name),
          downloadUrl: downloadUrl,
          fileSize: metadata.size ?? 0,
          uploadTime: metadata.timeCreated ?? DateTime.now(),
        ));
      }
      
      // Sort by year (newest first)
      questions.sort((a, b) => b.year.compareTo(a.year));
      
      return questions;
    } catch (e) {
      print('Error fetching BECE RME questions: $e');
      return [];
    }
  }

  // Get all past questions from different subjects
  static Future<List<PastQuestion>> getAllPastQuestions() async {
    try {
      List<PastQuestion> allQuestions = [];
      
      // Get BECE RME questions
      final beceRmeQuestions = await getBECERMEQuestions();
      allQuestions.addAll(beceRmeQuestions);
      
      // TODO: Add other subjects as you upload them
      // final mathQuestions = await getBECEMathQuestions();
      // allQuestions.addAll(mathQuestions);
      
      return allQuestions;
    } catch (e) {
      print('Error fetching all past questions: $e');
      return [];
    }
  }

  // Extract year from file name (assumes format includes year)
  static String extractYearFromFileName(String fileName) {
    final RegExp yearPattern = RegExp(r'20\d{2}');
    final match = yearPattern.firstMatch(fileName);
    return match?.group(0) ?? 'Unknown';
  }

  // Search questions by keyword
  static List<PastQuestion> searchQuestions(List<PastQuestion> questions, String query) {
    if (query.isEmpty) return questions;
    
    return questions.where((question) {
      return question.title.toLowerCase().contains(query.toLowerCase()) ||
             question.subject.toLowerCase().contains(query.toLowerCase()) ||
             question.year.contains(query);
    }).toList();
  }
}

class PastQuestion {
  final String id;
  final String title;
  final String subject;
  final String year;
  final String downloadUrl;
  final int fileSize;
  final DateTime uploadTime;

  PastQuestion({
    required this.id,
    required this.title,
    required this.subject,
    required this.year,
    required this.downloadUrl,
    required this.fileSize,
    required this.uploadTime,
  });

  String get formattedFileSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}