import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/web_compatibility.dart';

import 'package:flutter/foundation.dart';
class RMEDataImportService {
  /// Import RME questions using Cloud Function (Web-compatible version)
  static Future<Map<String, dynamic>> importRMEQuestions() async {
    try {
      debugPrint('Calling importRMEQuestions Cloud Function...');
      
      // Try Cloud Function first
      try {
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final HttpsCallable callable = functions.httpsCallable(
          'importRMEQuestions',
          options: HttpsCallableOptions(
            timeout: const Duration(minutes: 5),
          ),
        );
        final result = await callable.call(<String, dynamic>{});
        
        debugPrint('Cloud Function completed successfully');
        return {
          'success': true,
          'message': result.data['message']?.toString() ?? 'Import completed',
          'questionsImported': result.data['questionsImported'] ?? 0,
        };
      } catch (cloudFunctionError) {
        debugPrint('Cloud Function failed, trying direct import: $cloudFunctionError');
        
        // Fallback to direct Firestore import with web-compatible approach
        return await _directImport();
      }
      
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      
      String errorMessage = 'Failed to import RME questions';
      if (e.toString().contains('int64')) {
        errorMessage = 'Import failed due to data type compatibility. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please ensure you are logged in as an admin.';
      } else {
        errorMessage = 'Failed to import RME questions: ${e.toString()}';
      }
      
      return {
        'success': false,
        'message': errorMessage,
        'questionsImported': 0,
      };
    }
  }

  /// Direct Firestore import as fallback
  static Future<Map<String, dynamic>> _directImport() async {
    try {
      debugPrint('Starting direct Firestore import...');
      
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      // Simple RME questions data
      final questions = [
        {'q': 'According to Christian teaching, God created man and woman on the', 'opts': ['A. 1st day', 'B. 2nd day', 'C. 3rd day', 'D. 5th day', 'E. 6th day'], 'ans': 'E'},
        {'q': 'Palm Sunday is observed by Christians to remember the', 'opts': ['A. birth and baptism of Christ', 'B. resurrection and appearance of Christ', 'C. joyful journey of Christ into Jerusalem', 'D. baptism of the Holy Spirit', 'E. last supper and sacrifice of Christ'], 'ans': 'C'},
        {'q': 'God gave Noah and his people the rainbow to remember', 'opts': ['A. the floods which destroyed the world', 'B. the disobedience of the idol worshippers', 'C. that God would not destroy the world with water again', 'D. the building of the ark', 'E. the usefulness of the heavenly bodies'], 'ans': 'C'},
        {'q': 'All the religions in Ghana believe in', 'opts': ['A. Jesus Christ', 'B. the Bible', 'C. the Prophet Muhammed', 'D. the Rain god', 'E. the Supreme God'], 'ans': 'E'},
        {'q': 'The Muslim prayers observed between Asr and Isha is', 'opts': ['A. Zuhr', 'B. Jumu\'ah', 'C. Idd', 'D. Subhi', 'E. Maghrib'], 'ans': 'E'},
      ];
      
      int importedCount = 0;
      final currentTime = safeTimestamp(DateTime.now());
      final currentDate = DateTime.now().toIso8601String();
      
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final docId = 'rme_1999_q${i + 1}';
        
        final docData = {
          'id': docId,
          'questionText': q['q'],
          'type': 'multipleChoice',
          'subject': 'religiousMoralEducation',
          'examType': 'bece',
          'year': '1999',
          'section': 'A',
          'questionNumber': i + 1,
          'options': q['opts'],
          'correctAnswer': q['ans'],
          'explanation': 'This is question ${i + 1} from the 1999 BECE RME exam.',
          'marks': 1,
          'difficulty': 'medium',
          'topics': ['Religious And Moral Education', 'BECE', '1999'],
          'createdAt': currentDate,
          'updatedAt': currentDate,
          'createdBy': 'system_import',
          'isActive': true,
          'timestamp': currentTime,
        };
        
        final docRef = firestore.collection('questions').doc(docId);
        batch.set(docRef, docData);
        importedCount++;
      }
      
      await batch.commit();
      debugPrint('Direct import completed successfully');
      
      return {
        'success': true,
        'message': 'Successfully imported $importedCount RME questions using direct method!',
        'questionsImported': importedCount,
      };
      
    } catch (e) {
      debugPrint('Direct import failed: $e');
      return {
        'success': false,
        'message': 'Both Cloud Function and direct import failed: ${e.toString()}',
        'questionsImported': 0,
      };
    }
  }
}