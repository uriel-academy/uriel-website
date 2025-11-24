import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get BECE RME past questions from storage
  static Future<List<PastQuestion>> getBECERMEQuestions() async {
    try {
      // Try multiple possible folder names for RME questions
      List<String> possiblePaths = [
        'bece-rme questions',
        'bece-rme',
        'rme questions',
        'rme',
        'RME',
        'Religious and Moral Education',
        'BECE RME'
      ];
      
      List<PastQuestion> questions = [];
      
      for (String path in possiblePaths) {
        try {
          final ListResult result = await _storage.ref(path).listAll();
          
          // Check files directly in the folder
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
          
          // Check subdirectories (e.g., 2014/, 2015/, etc.)
          for (var prefix in result.prefixes) {
            try {
              final ListResult subResult = await prefix.listAll();
              
              for (var item in subResult.items) {
                final String downloadUrl = await item.getDownloadURL();
                final FullMetadata metadata = await item.getMetadata();
                
                // Extract year from folder name (e.g., "2014" from "bece-rme questions/2014/")
                String yearFromFolder = prefix.name;
                String extractedYear = extractYearFromFileName(item.name);
                
                questions.add(PastQuestion(
                  id: item.name,
                  title: item.name.replaceAll('.pdf', '').replaceAll('.json', '').replaceAll('_', ' '),
                  subject: 'Religious and Moral Education',
                  year: extractedYear != 'Unknown' ? extractedYear : yearFromFolder,
                  downloadUrl: downloadUrl,
                  fileSize: metadata.size ?? 0,
                  uploadTime: metadata.timeCreated ?? DateTime.now(),
                ));
              }
            } catch (e) {
              debugPrint('Failed to access subfolder ${prefix.name}: $e');
            }
          }
          
          if (questions.isNotEmpty) {
            debugPrint('Found ${questions.length} RME questions in folder: $path');
            break; // Found questions, stop searching
          }
        } catch (e) {
          debugPrint('Failed to access folder: $path - $e');
          continue; // Try next folder
        }
      }
      
      // Sort by year (newest first) - handle string years
      questions.sort((a, b) {
        final aYear = int.tryParse(a.year) ?? 0;
        final bYear = int.tryParse(b.year) ?? 0;
        return bYear.compareTo(aYear);
      });
      
      return questions;
    } catch (e) {
      debugPrint('Error fetching BECE RME questions: $e');
      return [];
    }
  }

  // Get trivia content from storage
  static Future<List<PastQuestion>> getTriviaContent() async {
    try {
      // Try multiple possible folder names for trivia
      List<String> possiblePaths = [
        'trivia',
        'Trivia',
        'TRIVIA',
        'trivia questions',
        'Trivia Questions'
      ];
      
      List<PastQuestion> questions = [];
      
      for (String path in possiblePaths) {
        try {
          final ListResult result = await _storage.ref(path).listAll();
          
          for (var item in result.items) {
            final String downloadUrl = await item.getDownloadURL();
            final FullMetadata metadata = await item.getMetadata();
            
            questions.add(PastQuestion(
              id: item.name,
              title: item.name.replaceAll('.pdf', '').replaceAll('.txt', '').replaceAll('_', ' '),
              subject: 'Trivia',
              year: extractYearFromFileName(item.name),
              downloadUrl: downloadUrl,
              fileSize: metadata.size ?? 0,
              uploadTime: metadata.timeCreated ?? DateTime.now(),
            ));
          }
          
          if (questions.isNotEmpty) {
            debugPrint('Found trivia content in folder: $path');
            break; // Found questions, stop searching
          }
        } catch (e) {
          debugPrint('Failed to access folder: $path - $e');
          continue; // Try next folder
        }
      }
      
      // Sort by upload time (newest first)
      questions.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
      
      return questions;
    } catch (e) {
      debugPrint('Error fetching trivia content: $e');
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
      
      // Get trivia content
      final triviaQuestions = await getTriviaContent();
      allQuestions.addAll(triviaQuestions);
      
      // TODO: Add other subjects as you upload them
      // final mathQuestions = await getBECEMathQuestions();
      // allQuestions.addAll(mathQuestions);
      
      return allQuestions;
    } catch (e) {
      debugPrint('Error fetching all past questions: $e');
      return [];
    }
  }

  // Get questions by subject from storage
  static Future<List<PastQuestion>> getQuestionsBySubject(String subject) async {
    try {
      String folderPath;
      switch (subject.toLowerCase()) {
        case 'rme':
        case 'religious and moral education':
          folderPath = 'bece-rme questions';
          break;
        case 'trivia':
          folderPath = 'trivia';
          break;
        case 'mathematics':
          folderPath = 'bece-math questions';
          break;
        case 'english':
          folderPath = 'bece-english questions';
          break;
        case 'science':
          folderPath = 'bece-science questions';
          break;
        default:
          folderPath = 'bece-${subject.toLowerCase()} questions';
      }
      
      final ListResult result = await _storage.ref(folderPath).listAll();
      List<PastQuestion> questions = [];
      
      for (var item in result.items) {
        final String downloadUrl = await item.getDownloadURL();
        final FullMetadata metadata = await item.getMetadata();
        
        questions.add(PastQuestion(
          id: item.name,
          title: item.name.replaceAll('.pdf', '').replaceAll('.txt', '').replaceAll('_', ' '),
          subject: subject,
          year: extractYearFromFileName(item.name),
          downloadUrl: downloadUrl,
          fileSize: metadata.size ?? 0,
          uploadTime: metadata.timeCreated ?? DateTime.now(),
        ));
      }
      
      // Sort by year (newest first) - handle string years
      questions.sort((a, b) {
        final aYear = int.tryParse(a.year) ?? 0;
        final bYear = int.tryParse(b.year) ?? 0;
        return bYear.compareTo(aYear);
      });
      
      return questions;
    } catch (e) {
      debugPrint('Error fetching questions for subject $subject: $e');
      return [];
    }
  }

  // Debug method to list all folders in Firebase Storage root
  static Future<List<String>> listAllStorageFolders() async {
    try {
      final ListResult result = await _storage.ref().listAll();
      
      List<String> folders = [];
      
      // Add all prefixes (folders)
      for (var prefix in result.prefixes) {
        folders.add(prefix.name);
      }
      
      // Add all items (files in root)
      for (var item in result.items) {
        folders.add('FILE: ${item.name}');
      }
      
      debugPrint('Available folders/files in Firebase Storage:');
      for (String folder in folders) {
        debugPrint('- $folder');
      }
      
      return folders;
    } catch (e) {
      debugPrint('Error listing storage folders: $e');
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

  // Get storybook download URL from storage
  static Future<String?> getStorybookDownloadUrl(String fileName) async {
    try {
      final ref = _storage.ref('storybooks/$fileName');
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error getting storybook download URL for $fileName: $e');
      return null;
    }
  }

  // Download storybook bytes from storage
  static Future<Uint8List?> downloadStorybook(String fileName) async {
    try {
      final ref = _storage.ref('storybooks/$fileName');
      final bytes = await ref.getData();

      if (bytes != null) {
        // Track download analytics
        await _trackStorybookDownload(fileName);

        // Increment download count in Firestore
        await _incrementDownloadCount(fileName);
      }

      return bytes;
    } catch (e) {
      debugPrint('Error downloading storybook $fileName: $e');
      return null;
    }
  }

  // Track storybook download analytics
  static Future<void> _trackStorybookDownload(String fileName) async {
    try {
      final analytics = FirebaseAnalytics.instance;

      // Extract book info from filename for better analytics
      final bookTitle = fileName.replaceAll('.epub', '').replaceAll('.azw3', '')
          .replaceAll('-', ' ').split(' ').map((word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word)
          .join(' ');

      await analytics.logEvent(
        name: 'storybook_download',
        parameters: {
          'book_title': bookTitle,
          'file_name': fileName,
          'format': fileName.endsWith('.epub') ? 'epub' : 'azw3',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('Analytics: Tracked download for $bookTitle');
    } catch (e) {
      debugPrint('Error tracking analytics: $e');
    }
  }

  // Increment download count in Firestore
  static Future<void> _incrementDownloadCount(String fileName) async {
    try {
      // Find the storybook document by fileName
      final querySnapshot = await FirebaseFirestore.instance
          .collection('storybooks')
          .where('fileName', isEqualTo: fileName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docRef = querySnapshot.docs.first.reference;

        // Increment download count
        await docRef.update({
          'downloadCount': FieldValue.increment(1),
          'lastAccessed': FieldValue.serverTimestamp(),
        });

        debugPrint('Firestore: Incremented download count for $fileName');
      }
    } catch (e) {
      debugPrint('Error updating download count: $e');
    }
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
