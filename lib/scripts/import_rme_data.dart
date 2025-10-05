import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../services/rme_data_import_service.dart';

/// Standalone script to import RME data to Firestore
/// Run this with: flutter run lib/scripts/import_rme_data.dart
void main() async {
  print('🚀 Starting RME Data Import...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    print('📚 Preparing to import RME questions...');
    
    // Import RME questions
    print('⏳ Importing 1999 BECE RME questions...');
    final result = await RMEDataImportService.importRMEQuestions();
    
    if (result['success'] == true) {
      print('🎉 SUCCESS! ${result['questionsImported']} RME questions imported successfully!');
      print('📝 Questions are now available in the quiz system.');
      print('✨ You can now create RME quizzes from the homepage.');
    } else {
      print('❌ Import failed: ${result['message']}');
    }
    
  } catch (e) {
    print('❌ Error importing RME data: $e');
    print('💡 Make sure Firebase is properly configured.');
  }
  
  print('🏁 Import process completed.');
}