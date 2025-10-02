import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/question_model.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collections
  CollectionReference get _questionsCollection => _firestore.collection('questions');
  CollectionReference get _examsCollection => _firestore.collection('exams');
  CollectionReference get _examResultsCollection => _firestore.collection('exam_results');

  /// Add a single question
  Future<void> addQuestion(Question question) async {
    try {
      await _questionsCollection.doc(question.id).set(question.toJson());
    } catch (e) {
      throw Exception('Failed to add question: $e');
    }
  }

  /// Add multiple questions in batch
  Future<void> addQuestionsBatch(List<Question> questions) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (Question question in questions) {
        DocumentReference docRef = _questionsCollection.doc(question.id);
        batch.set(docRef, question.toJson());
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add questions in batch: $e');
    }
  }

  /// Get questions by exam type and subject
  Future<List<Question>> getQuestions({
    ExamType? examType,
    Subject? subject,
    String? year,
    String? section,
    bool activeOnly = true,
  }) async {
    try {
      // Return sample questions instead of querying Firestore for demo purposes
      final allQuestions = await getQuestionsByFilters(
        subject: 'All Subjects',
        examType: 'All Types', 
        level: 'All Levels',
      );
      
      // Apply filters
      List<Question> filtered = allQuestions;
      
      if (examType != null) {
        filtered = filtered.where((q) => q.examType == examType).toList();
      }
      if (subject != null) {
        filtered = filtered.where((q) => q.subject == subject).toList();
      }
      if (year != null) {
        filtered = filtered.where((q) => q.year == year).toList();
      }
      if (section != null) {
        filtered = filtered.where((q) => q.section == section).toList();
      }
      if (activeOnly) {
        filtered = filtered.where((q) => q.isActive).toList();
      }
      
      // Sort by question number
      filtered.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));
      
      return filtered;
    } catch (e) {
      throw Exception('Failed to fetch questions: $e');
    }
  }

  /// Get specific questions by IDs
  Future<List<Question>> getQuestionsByIds(List<String> questionIds) async {
    try {
      List<Question> questions = [];
      
      // Firestore has a limit of 10 items in whereIn, so we need to batch
      for (int i = 0; i < questionIds.length; i += 10) {
        List<String> batch = questionIds.skip(i).take(10).toList();
        
        QuerySnapshot snapshot = await _questionsCollection
            .where('id', whereIn: batch)
            .get();
        
        questions.addAll(
          snapshot.docs.map((doc) => Question.fromJson(doc.data() as Map<String, dynamic>))
        );
      }
      
      // Sort by the order in questionIds
      questions.sort((a, b) {
        int indexA = questionIds.indexOf(a.id);
        int indexB = questionIds.indexOf(b.id);
        return indexA.compareTo(indexB);
      });
      
      return questions;
    } catch (e) {
      throw Exception('Failed to fetch questions by IDs: $e');
    }
  }

  /// Get questions by filters for quiz functionality
  Future<List<Question>> getQuestionsByFilters({
    required String subject,
    required String examType,
    required String level,
    int? limit,
  }) async {
    try {
      // For now, return mock data that matches the filter criteria
      // In a real implementation, this would query Firestore
      
      final List<Question> sampleQuestions = [
        // RME 2018 Questions
        Question(
          id: 'rme_2018_1',
          questionText: 'Which of the following is the first book of the Bible?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 1,
          options: ['Exodus', 'Genesis', 'Leviticus', 'Numbers'],
          correctAnswer: 'Genesis',
          explanation: 'Genesis is the first book of the Bible, meaning "beginning" or "origin".',
          marks: 1,
          difficulty: 'easy',
          topics: ['Christianity', 'Bible Study'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2018_2',
          questionText: 'Who was the first man created by God according to the Bible?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 2,
          options: ['Noah', 'Abraham', 'Adam', 'Moses'],
          correctAnswer: 'Adam',
          explanation: 'Adam was the first man created by God from the dust of the earth.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Christianity', 'Creation'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2018_3',
          questionText: 'What does the word "Islam" mean?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 3,
          options: ['Peace', 'Submission to Allah', 'Prayer', 'Charity'],
          correctAnswer: 'Submission to Allah',
          explanation: 'Islam means "submission to Allah" and comes from the Arabic root meaning "peace".',
          marks: 1,
          difficulty: 'medium',
          topics: ['Islam', 'Islamic Studies'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2018_4',
          questionText: 'Which of the following is NOT one of the Five Pillars of Islam?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 4,
          options: ['Shahada (Declaration of Faith)', 'Salah (Prayer)', 'Jihad (Holy War)', 'Zakat (Charity)'],
          correctAnswer: 'Jihad (Holy War)',
          explanation: 'The Five Pillars are Shahada, Salah, Zakat, Sawm (Fasting), and Hajj (Pilgrimage).',
          marks: 1,
          difficulty: 'medium',
          topics: ['Islam', 'Five Pillars'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2018_5',
          questionText: 'In traditional African religion, what is the role of ancestors?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 5,
          options: ['They are forgotten after death', 'They mediate between the living and the Supreme Being', 'They have no influence on the living', 'They are worshipped as gods'],
          correctAnswer: 'They mediate between the living and the Supreme Being',
          explanation: 'In African traditional religion, ancestors serve as intermediaries between the living and the Supreme Being.',
          marks: 1,
          difficulty: 'medium',
          topics: ['African Traditional Religion', 'Ancestors'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // RME 2019 Questions
        Question(
          id: 'rme_2019_1',
          questionText: 'Jesus Christ was born in which town?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2019',
          section: 'A',
          questionNumber: 1,
          options: ['Nazareth', 'Jerusalem', 'Bethlehem', 'Capernaum'],
          correctAnswer: 'Bethlehem',
          explanation: 'Jesus was born in Bethlehem, in the city of David, as prophesied in the Old Testament.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Christianity', 'Life of Jesus'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2019_2',
          questionText: 'The Quran was revealed to Prophet Muhammad through which angel?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2019',
          section: 'A',
          questionNumber: 2,
          options: ['Mikail', 'Jibril (Gabriel)', 'Israfil', 'Azrail'],
          correctAnswer: 'Jibril (Gabriel)',
          explanation: 'The Quran was revealed to Prophet Muhammad through the angel Jibril (Gabriel).',
          marks: 1,
          difficulty: 'medium',
          topics: ['Islam', 'Quran', 'Prophets'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // RME 2020 Questions
        Question(
          id: 'rme_2020_1',
          questionText: 'Which of the following is the holiest city in Islam?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2020',
          section: 'A',
          questionNumber: 1,
          options: ['Medina', 'Mecca', 'Jerusalem', 'Baghdad'],
          correctAnswer: 'Mecca',
          explanation: 'Mecca is the holiest city in Islam, home to the Kaaba and destination for Hajj pilgrimage.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Islam', 'Holy Places'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2020_2',
          questionText: 'The Ten Commandments were given to which prophet?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2020',
          section: 'A',
          questionNumber: 2,
          options: ['Abraham', 'Moses', 'David', 'Elijah'],
          correctAnswer: 'Moses',
          explanation: 'The Ten Commandments were given by God to Moses on Mount Sinai.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Christianity', 'Judaism', 'Moses'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // RME 2021 Questions
        Question(
          id: 'rme_2021_1',
          questionText: 'What is the meaning of "Ramadan" in Islam?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2021',
          section: 'A',
          questionNumber: 1,
          options: ['The month of fasting', 'The month of charity', 'The month of pilgrimage', 'The month of prayer'],
          correctAnswer: 'The month of fasting',
          explanation: 'Ramadan is the ninth month of the Islamic calendar, observed by Muslims worldwide as a month of fasting.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Islam', 'Ramadan', 'Fasting'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2021_2',
          questionText: 'In Christianity, what does "Trinity" refer to?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2021',
          section: 'A',
          questionNumber: 2,
          options: ['Three angels', 'Three prophets', 'Father, Son, and Holy Spirit', 'Three books of the Bible'],
          correctAnswer: 'Father, Son, and Holy Spirit',
          explanation: 'The Trinity in Christianity refers to the three persons of God: the Father, the Son (Jesus), and the Holy Spirit.',
          marks: 1,
          difficulty: 'medium',
          topics: ['Christianity', 'Trinity'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // RME 2022 Questions
        Question(
          id: 'rme_2022_1',
          questionText: 'Which African traditional festival celebrates the harvest season?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2022',
          section: 'A',
          questionNumber: 1,
          options: ['Homowo', 'Aboakyir', 'Hogbetsotso', 'Akwasidae'],
          correctAnswer: 'Homowo',
          explanation: 'Homowo is a traditional harvest festival celebrated by the Ga people of Ghana.',
          marks: 1,
          difficulty: 'medium',
          topics: ['African Traditional Religion', 'Festivals'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2022_2',
          questionText: 'What is the first pillar of Islam called?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2022',
          section: 'A',
          questionNumber: 2,
          options: ['Salah', 'Shahada', 'Zakat', 'Hajj'],
          correctAnswer: 'Shahada',
          explanation: 'Shahada is the declaration of faith and the first pillar of Islam.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Islam', 'Five Pillars'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // RME 2023 Questions
        Question(
          id: 'rme_2023_1',
          questionText: 'What is the main theme of the book of Genesis?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2023',
          section: 'A',
          questionNumber: 1,
          options: ['Creation and beginnings', 'Laws and commandments', 'Prophecies and visions', 'Parables and teachings'],
          correctAnswer: 'Creation and beginnings',
          explanation: 'Genesis is the first book of the Bible and focuses on creation stories and the beginnings of humanity.',
          marks: 1,
          difficulty: 'medium',
          topics: ['Christianity', 'Bible Study'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
        Question(
          id: 'rme_2023_2',
          questionText: 'Which of the following is a fruit of the Spirit mentioned in Galatians 5:22?',
          type: QuestionType.multipleChoice,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: '2023',
          section: 'A',
          questionNumber: 2,
          options: ['Anger', 'Love', 'Pride', 'Jealousy'],
          correctAnswer: 'Love',
          explanation: 'Love is the first fruit of the Spirit mentioned in Galatians 5:22-23.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Christianity', 'Bible Study'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // Mathematics Questions (for other subjects)
        Question(
          id: 'math_2018_1',
          questionText: 'If 2x + 5 = 13, what is the value of x?',
          type: QuestionType.multipleChoice,
          subject: Subject.mathematics,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 1,
          options: ['3', '4', '5', '6'],
          correctAnswer: '4',
          explanation: '2x + 5 = 13, so 2x = 8, therefore x = 4',
          marks: 1,
          difficulty: 'easy',
          topics: ['Algebra', 'Linear Equations'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // English Questions
        Question(
          id: 'eng_2018_1',
          questionText: 'What is the plural form of "child"?',
          type: QuestionType.multipleChoice,
          subject: Subject.english,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 1,
          options: ['childs', 'children', 'childes', 'childrens'],
          correctAnswer: 'children',
          explanation: 'The plural form of "child" is "children", which is an irregular plural.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Grammar', 'Plurals'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),

        // Science Questions
        Question(
          id: 'sci_2018_1',
          questionText: 'What is the chemical symbol for water?',
          type: QuestionType.multipleChoice,
          subject: Subject.integratedScience,
          examType: ExamType.bece,
          year: '2018',
          section: 'A',
          questionNumber: 1,
          options: ['H2O', 'CO2', 'NaCl', 'O2'],
          correctAnswer: 'H2O',
          explanation: 'Water has the chemical formula H2O, consisting of two hydrogen atoms and one oxygen atom.',
          marks: 1,
          difficulty: 'easy',
          topics: ['Chemistry', 'Chemical Formulas'],
          createdAt: DateTime.now(),
          createdBy: 'system',
          isActive: true,
        ),
      ];

      // Filter questions based on criteria
      List<Question> filteredQuestions = sampleQuestions;
      
      // Apply limit if specified
      if (limit != null && limit > 0) {
        filteredQuestions = filteredQuestions.take(limit).toList();
      }
      
      return filteredQuestions;
    } catch (e) {
      throw Exception('Failed to fetch questions by filters: $e');
    }
  }

  /// Create an exam
  Future<void> createExam(Exam exam) async {
    try {
      await _examsCollection.doc(exam.id).set(exam.toJson());
    } catch (e) {
      throw Exception('Failed to create exam: $e');
    }
  }

  /// Get all exams
  Future<List<Exam>> getExams({bool activeOnly = true}) async {
    try {
      Query query = _examsCollection;
      
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      query = query.orderBy('createdAt', descending: true);
      
      QuerySnapshot snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => Exam.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch exams: $e');
    }
  }

  /// Get exam by ID
  Future<Exam?> getExamById(String examId) async {
    try {
      DocumentSnapshot doc = await _examsCollection.doc(examId).get();
      
      if (doc.exists) {
        return Exam.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch exam: $e');
    }
  }

  /// Save exam result
  Future<void> saveExamResult(ExamResult result) async {
    try {
      await _examResultsCollection.doc(result.id).set(result.toJson());
    } catch (e) {
      throw Exception('Failed to save exam result: $e');
    }
  }

  /// Get exam results for a student
  Future<List<ExamResult>> getStudentExamResults(String studentId) async {
    try {
      QuerySnapshot snapshot = await _examResultsCollection
          .where('studentId', isEqualTo: studentId)
          .orderBy('endTime', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => ExamResult.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch exam results: $e');
    }
  }

  /// Upload image for question
  Future<String> uploadQuestionImage(String fileName, List<int> imageBytes) async {
    try {
      Reference ref = _storage.ref().child('question_images').child(fileName);
      UploadTask uploadTask = ref.putData(Uint8List.fromList(imageBytes));
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Parse trivia questions from text (for bulk import)
  Future<List<Question>> parseTriviaQuestions(String triviaText) async {
    List<Question> questions = [];
    List<String> lines = triviaText.split('\n');
    
    String? currentQuestion;
    String? currentAnswer;
    String? currentCategory;
    int questionNumber = 1;
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Check for category markers [Category]
      if (line.startsWith('[') && line.endsWith(']')) {
        currentCategory = line.substring(1, line.length - 1);
        continue;
      }
      
      // Check if line is a question (number followed by period and space)
      final questionMatch = RegExp(r'^\d+\.\s+(.+)').firstMatch(line);
      if (questionMatch != null) {
        // If we have a previous question and answer, save it
        if (currentQuestion != null && currentAnswer != null) {
          questions.add(_createTriviaQuestion(
            questionNumber - 1,
            currentQuestion,
            currentAnswer,
            currentCategory,
          ));
        }
        
        currentQuestion = questionMatch.group(1);
        currentAnswer = null;
        questionNumber++;
      } else if (line.toLowerCase().startsWith('answer:')) {
        currentAnswer = line.substring(7).trim();
      } else if (currentQuestion != null && currentAnswer == null) {
        // This might be the answer line without "Answer:" prefix
        currentAnswer = line;
      }
    }
    
    // Don't forget the last question
    if (currentQuestion != null && currentAnswer != null) {
      questions.add(_createTriviaQuestion(
        questionNumber - 1,
        currentQuestion,
        currentAnswer,
        currentCategory,
      ));
    }
    
    return questions;
  }

  /// Parse structured questions from text (for bulk import)
  Future<List<Question>> parseQuestionsFromText(
    String text, {
    required Subject subject,
    required ExamType examType,
    required String year,
    required String section,
  }) async {
    final questions = <Question>[];
    final lines = text.split('\n');
    
    String? currentQuestion;
    List<String> currentOptions = [];
    String? currentAnswer;
    int? currentMarks;
    String? currentExplanation;
    int questionNumber = 1;
    bool isMultipleChoice = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) continue;
      
      // Check for question start (Q1., Q2., etc.)
      final questionMatch = RegExp(r'^Q(\d+)\.\s+(.+)').firstMatch(line);
      if (questionMatch != null) {
        // Save previous question if exists
        if (currentQuestion != null && currentAnswer != null) {
          questions.add(_createStructuredQuestion(
            currentQuestion,
            currentOptions,
            currentAnswer,
            currentMarks ?? 1,
            currentExplanation,
            questionNumber - 1,
            subject,
            examType,
            year,
            section,
            isMultipleChoice,
          ));
        }
        
        // Reset for new question
        questionNumber = int.parse(questionMatch.group(1)!);
        currentQuestion = questionMatch.group(2);
        currentOptions = [];
        currentAnswer = null;
        currentMarks = null;
        currentExplanation = null;
        isMultipleChoice = false;
        continue;
      }
      
      // Check for options (A), B), C), D))
      final optionMatch = RegExp(r'^([A-D])\)\s+(.+)').firstMatch(line);
      if (optionMatch != null) {
        currentOptions.add(optionMatch.group(2)!);
        isMultipleChoice = true;
        continue;
      }
      
      // Check for answer
      if (line.toLowerCase().startsWith('answer:')) {
        currentAnswer = line.substring(7).trim();
        continue;
      }
      
      // Check for marks
      if (line.toLowerCase().startsWith('marks:')) {
        final marksText = line.substring(6).trim();
        currentMarks = int.tryParse(marksText);
        continue;
      }
      
      // Check for explanation
      if (line.toLowerCase().startsWith('explanation:')) {
        currentExplanation = line.substring(12).trim();
        continue;
      }
    }
    
    // Don't forget the last question
    if (currentQuestion != null && currentAnswer != null) {
      questions.add(_createStructuredQuestion(
        currentQuestion,
        currentOptions,
        currentAnswer,
        currentMarks ?? 1,
        currentExplanation,
        questionNumber,
        subject,
        examType,
        year,
        section,
        isMultipleChoice,
      ));
    }
    
    return questions;
  }

  Question _createStructuredQuestion(
    String questionText,
    List<String> options,
    String answer,
    int marks,
    String? explanation,
    int questionNumber,
    Subject subject,
    ExamType examType,
    String year,
    String section,
    bool isMultipleChoice,
  ) {
    return Question(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}_$questionNumber',
      questionText: questionText,
      type: isMultipleChoice ? QuestionType.multipleChoice : QuestionType.shortAnswer,
      subject: subject,
      examType: examType,
      year: year,
      section: section,
      questionNumber: questionNumber,
      options: isMultipleChoice ? options : null,
      correctAnswer: answer,
      explanation: explanation,
      marks: marks,
      difficulty: _inferDifficulty(marks),
      topics: _inferTopics(questionText, subject),
      createdAt: DateTime.now(),
      createdBy: FirebaseAuth.instance.currentUser?.email ?? 'admin',
    );
  }

  String _inferDifficulty(int marks) {
    if (marks <= 1) return 'easy';
    if (marks <= 5) return 'medium';
    return 'hard';
  }

  List<String> _inferTopics(String questionText, Subject subject) {
    List<String> topics = [];
    
    // Add subject-specific topic inference logic
    switch (subject) {
      case Subject.mathematics:
        if (questionText.toLowerCase().contains('algebra')) topics.add('algebra');
        if (questionText.toLowerCase().contains('geometry')) topics.add('geometry');
        if (questionText.toLowerCase().contains('trigonometry')) topics.add('trigonometry');
        if (questionText.toLowerCase().contains('calculus')) topics.add('calculus');
        break;
      case Subject.integratedScience:
        if (questionText.toLowerCase().contains('biology')) topics.add('biology');
        if (questionText.toLowerCase().contains('chemistry')) topics.add('chemistry');
        if (questionText.toLowerCase().contains('physics')) topics.add('physics');
        break;
      default:
        topics.add('general');
    }
    
    return topics.isEmpty ? ['general'] : topics;
  }

  Question _createTriviaQuestion(
    int number,
    String question,
    String answer,
    String? category,
  ) {
    return Question(
      id: 'trivia_${DateTime.now().millisecondsSinceEpoch}_$number',
      questionText: question,
      type: QuestionType.trivia,
      subject: Subject.trivia,
      examType: ExamType.trivia,
      year: DateTime.now().year.toString(),
      section: 'General',
      questionNumber: number,
      correctAnswer: answer,
      marks: 1,
      difficulty: 'medium',
      topics: category != null ? [category.toLowerCase().replaceAll(' ', '_')] : ['general_knowledge'],
      createdAt: DateTime.now(),
      createdBy: FirebaseAuth.instance.currentUser?.email ?? 'admin',
    );
  }

  /// Auto-create BECE exam from questions
  Future<Exam> createBECEExam(Subject subject, String year) async {
    try {
      // Get all questions for the subject and year
      List<Question> sectionAQuestions = await getQuestions(
        examType: ExamType.bece,
        subject: subject,
        year: year,
        section: 'A',
      );
      
      List<Question> sectionBQuestions = await getQuestions(
        examType: ExamType.bece,
        subject: subject,
        year: year,
        section: 'B',
      );
      
      // Sort questions by question number
      sectionAQuestions.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));
      sectionBQuestions.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));
      
      List<String> allQuestionIds = [
        ...sectionAQuestions.map((q) => q.id),
        ...sectionBQuestions.map((q) => q.id),
      ];
      
      int totalMarks = sectionAQuestions.fold(0, (sum, q) => sum + q.marks) +
                      sectionBQuestions.fold(0, (sum, q) => sum + q.marks);
      
      String examId = 'bece_${subject.name}_${year}_${DateTime.now().millisecondsSinceEpoch}';
      
      Exam exam = Exam(
        id: examId,
        title: 'BECE ${_getSubjectDisplayName(subject)} $year',
        subject: subject,
        type: ExamType.bece,
        year: year,
        duration: 120, // 2 hours default
        totalMarks: totalMarks,
        questionIds: allQuestionIds,
        createdAt: DateTime.now(),
        isActive: true,
        description: 'BECE ${_getSubjectDisplayName(subject)} examination for $year. '
                    'Section A: ${sectionAQuestions.length} multiple choice questions. '
                    'Section B: ${sectionBQuestions.length} essay questions.',
      );
      
      await createExam(exam);
      return exam;
    } catch (e) {
      throw Exception('Failed to create BECE exam: $e');
    }
  }

  static String _getSubjectDisplayName(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English Language';
      case Subject.integratedScience:
        return 'Integrated Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.ghanaianLanguage:
        return 'Ghanaian Language';
      case Subject.french:
        return 'French';
      case Subject.ict:
        return 'ICT';
      case Subject.religiousMoralEducation:
        return 'Religious & Moral Education';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.trivia:
        return 'Trivia';
    }
  }
}