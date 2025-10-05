import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

/// Simple script to check if RME questions exist in database
void main() async {
  print('🔍 Checking for RME questions in database...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Check for RME questions
    final firestore = FirebaseFirestore.instance;
    final questionsSnapshot = await firestore
        .collection('questions')
        .where('subject', isEqualTo: 'religiousMoralEducation')
        .where('examType', isEqualTo: 'bece')
        .where('year', isEqualTo: '1999')
        .get();
    
    print('📊 Found ${questionsSnapshot.docs.length} RME questions');
    
    if (questionsSnapshot.docs.isEmpty) {
      print('📝 No RME questions found. Importing now...');
      
      // Import using the service
      await _importRMEQuestions();
      
      // Check again
      final newSnapshot = await firestore
          .collection('questions')
          .where('subject', isEqualTo: 'religiousMoralEducation')
          .where('examType', isEqualTo: 'bece')
          .where('year', isEqualTo: '1999')
          .get();
      
      print('✅ Import complete! Now have ${newSnapshot.docs.length} RME questions');
    } else {
      print('✅ RME questions already exist in database!');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> _importRMEQuestions() async {
  final firestore = FirebaseFirestore.instance;
  
  // Sample RME questions data (first 5 questions for testing)
  final questions = [
    {
      'id': 'rme_1999_q1',
      'questionText': 'According to Christian teaching, God created man and woman on the',
      'type': 'multipleChoice',
      'subject': 'religiousMoralEducation',
      'examType': 'bece',
      'year': '1999',
      'section': 'A',
      'questionNumber': 1,
      'options': ['A. 1st day', 'B. 2nd day', 'C. 3rd day', 'D. 5th day', 'E. 6th day'],
      'correctAnswer': 'E',
      'explanation': 'According to Genesis, God created man and woman on the 6th day.',
      'marks': 1,
      'difficulty': 'easy',
      'topics': ['Christianity', 'Creation'],
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': 'system',
      'isActive': true,
    },
    {
      'id': 'rme_1999_q2',
      'questionText': 'Palm Sunday is observed by Christians to remember the',
      'type': 'multipleChoice',
      'subject': 'religiousMoralEducation',
      'examType': 'bece',
      'year': '1999',
      'section': 'A',
      'questionNumber': 2,
      'options': [
        'A. birth and baptism of Christ',
        'B. resurrection and appearance of Christ',
        'C. joyful journey of Christ into Jerusalem',
        'D. baptism of the Holy Spirit',
        'E. last supper and sacrifice of Christ'
      ],
      'correctAnswer': 'C',
      'explanation': 'Palm Sunday commemorates Jesus triumphant entry into Jerusalem.',
      'marks': 1,
      'difficulty': 'easy',
      'topics': ['Christianity', 'Jesus Christ'],
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': 'system',
      'isActive': true,
    },
    {
      'id': 'rme_1999_q3',
      'questionText': 'God gave Noah and his people the rainbow to remember',
      'type': 'multipleChoice',
      'subject': 'religiousMoralEducation',
      'examType': 'bece',
      'year': '1999',
      'section': 'A',
      'questionNumber': 3,
      'options': [
        'A. the floods which destroyed the world',
        'B. the disobedience of the idol worshippers',
        'C. that God would not destroy the world with water again',
        'D. the building of the ark',
        'E. the usefulness of the heavenly bodies'
      ],
      'correctAnswer': 'C',
      'explanation': 'The rainbow was Gods covenant sign that He would never again destroy the earth by flood.',
      'marks': 1,
      'difficulty': 'easy',
      'topics': ['Christianity', 'Noah', 'Covenant'],
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': 'system',
      'isActive': true,
    },
    {
      'id': 'rme_1999_q4',
      'questionText': 'All the religions in Ghana believe in',
      'type': 'multipleChoice',
      'subject': 'religiousMoralEducation',
      'examType': 'bece',
      'year': '1999',
      'section': 'A',
      'questionNumber': 4,
      'options': [
        'A. Jesus Christ',
        'B. the Bible',
        'C. the Prophet Muhammed',
        'D. the Rain god',
        'E. the Supreme God'
      ],
      'correctAnswer': 'E',
      'explanation': 'All major religions in Ghana acknowledge a Supreme Being/God.',
      'marks': 1,
      'difficulty': 'easy',
      'topics': ['Comparative Religion', 'Supreme Being'],
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': 'system',
      'isActive': true,
    },
    {
      'id': 'rme_1999_q5',
      'questionText': 'The Muslim prayers observed between Asr and Isha is',
      'type': 'multipleChoice',
      'subject': 'religiousMoralEducation',
      'examType': 'bece',
      'year': '1999',
      'section': 'A',
      'questionNumber': 5,
      'options': [
        'A. Zuhr',
        'B. Jumu\'ah',
        'C. Idd',
        'D. Subhi',
        'E. Maghrib'
      ],
      'correctAnswer': 'E',
      'explanation': 'Maghrib prayer is observed between Asr and Isha prayers.',
      'marks': 1,
      'difficulty': 'easy',
      'topics': ['Islam', 'Prayer', 'Salah'],
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': 'system',
      'isActive': true,
    },
  ];
  
  // Import in batch
  WriteBatch batch = firestore.batch();
  
  for (var questionData in questions) {
    DocumentReference docRef = firestore.collection('questions').doc(questionData['id'] as String);
    batch.set(docRef, questionData);
  }
  
  await batch.commit();
  print('📝 Successfully imported ${questions.length} RME questions');
}