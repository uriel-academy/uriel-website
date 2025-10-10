import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../services/rme_data_import_service.dart';

import 'package:flutter/foundation.dart';
/// Standalone script to import RME data to Firestore
/// Run this with: flutter run lib/scripts/import_rme_data.dart
void main() async {
  debugPrint('🚀 Starting RME Data Import...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
    
    debugPrint('📚 Preparing to import RME questions...');
    
    // Import RME questions
    debugPrint('⏳ Importing 1999 BECE RME questions...');
    final result = await RMEDataImportService.importRMEQuestions();
    
    if (result['success'] == true) {
      debugPrint('🎉 SUCCESS! ${result['questionsImported']} RME questions imported successfully!');
      debugPrint('📝 Questions are now available in the quiz system.');
      debugPrint('✨ You can now create RME quizzes from the homepage.');
    } else {
      debugPrint('❌ Import failed: ${result['message']}');
    }
    
  } catch (e) {
    debugPrint('❌ Error importing RME data: $e');
    debugPrint('💡 Make sure Firebase is properly configured.');
  }
  
  debugPrint('🏁 Import process completed.');
}