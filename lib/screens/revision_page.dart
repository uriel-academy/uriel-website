import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';
import '../screens/quiz_taker_page.dart';
import '../screens/flip_card_page.dart';

class RevisionPage extends StatefulWidget {
  const RevisionPage({Key? key}) : super(key: key);

  @override
  State<RevisionPage> createState() => _RevisionPageState();
}

class _RevisionPageState extends State<RevisionPage> {
  // Selection states
  ExamType? _selectedExamType;
  Subject? _selectedSubject;
  int _selectedQuestionCount = 20;
  String _selectedQuizDifficulty = 'medium';
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _flipCardTopicController = TextEditingController();
  final QuestionService _questionService = QuestionService();

  // Available options
  final List<ExamType> _availableExamTypes = [ExamType.bece, ExamType.wassce];
  final List<Subject> _availableSubjects = [
    Subject.mathematics,
    Subject.english,
    Subject.integratedScience,
    Subject.socialStudies,
    Subject.ghanaianLanguage,
    Subject.french,
    Subject.ict,
    Subject.religiousMoralEducation,
    Subject.creativeArts,
  ];
  bool _isGeneratingQuiz = false;
  bool _isGeneratingAIQuiz = false;
  bool _isGeneratingFlipCards = false;
  
  // Flip card specific options
  int _selectedCardCount = 20;
  String _selectedFlipCardDifficulty = 'medium';
  String _selectedFlipCardClassLevel = 'JHS 3';
  final List<String> _difficultyLevels = ['easy', 'medium', 'difficult'];
  final List<String> _classLevels = ['JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3'];

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _topicController.dispose();
    _flipCardTopicController.dispose();
    super.dispose();
  }

  // Generate mock exam from database questions
  Future<void> _generateMockExam() async {
    if (_selectedExamType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both exam type and subject'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() => _isGeneratingQuiz = true);

    try {
      // Get questions from database
      final questions = await _questionService.getQuestionsByFilters(
        examType: _selectedExamType,
        subject: _selectedSubject,
        activeOnly: true,
      );

      if (questions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No questions found for ${_getSubjectDisplayName(_selectedSubject!)}'),
            backgroundColor: const Color(0xFFD62828),
          ),
        );
        return;
      }

      // Shuffle and select requested number
      final shuffled = List<Question>.from(questions)..shuffle();
      final selected = shuffled.take(_selectedQuestionCount.clamp(1, questions.length)).toList();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizTakerPage(
            subject: _getSubjectDisplayName(_selectedSubject!),
            examType: _selectedExamType!.name.toUpperCase(),
            level: 'JHS 3',
            preloadedQuestions: selected,
            questionCount: _selectedQuestionCount,
            randomizeQuestions: false,
            customTitle: '${_getSubjectDisplayName(_selectedSubject!)} Mock Exam',
            isRevisionQuiz: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error generating mock exam: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating mock exam: ${e.toString()}'),
          backgroundColor: const Color(0xFFD62828),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingQuiz = false);
      }
    }
  }

  // Generate AI-powered mock exam using BECE knowledge and NACCA curriculum
  Future<void> _generateAIQuestions() async {
    if (_selectedExamType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both exam type and subject'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() => _isGeneratingAIQuiz = true);

    try {
      // Call the Cloud Function to generate AI questions based on BECE and NACCA curriculum
      final callable = FirebaseFunctions.instance.httpsCallable('generateAIQuiz');
      
      final result = await callable.call({
        'subject': _getSubjectDisplayName(_selectedSubject!),
        'examType': _selectedExamType!.name.toUpperCase(),
        'numQuestions': _selectedQuestionCount,
        'difficultyLevel': _selectedQuizDifficulty,
        'customTopic': _topicController.text.trim().isNotEmpty ? _topicController.text.trim() : null,
      });

      final data = result.data;
      if (data['success'] != true || data['questions'] == null) {
        throw Exception('Invalid response from AI service');
      }

      // Convert AI-generated questions to Question objects
      final List<Question> aiQuestions = [];
      for (var i = 0; i < (data['questions'] as List).length; i++) {
        final q = data['questions'][i];
        
        // Convert options object to list with letter prefixes (A., B., C., D.)
        final optionsMap = q['options'] as Map<String, dynamic>;
        final optionsList = <String>[
          'A. ${optionsMap['A']?.toString() ?? ''}',
          'B. ${optionsMap['B']?.toString() ?? ''}',
          'C. ${optionsMap['C']?.toString() ?? ''}',
          'D. ${optionsMap['D']?.toString() ?? ''}',
        ];

        // Get the correct answer letter (A, B, C, or D)
        String correctAnswerLetter = (q['correctAnswer'] ?? 'A').toString().toUpperCase();
        // Extract just the letter if it contains a period (e.g., "A." or "A. Text")
        if (correctAnswerLetter.contains('.')) {
          correctAnswerLetter = correctAnswerLetter.split('.')[0].trim();
        }
        // Ensure it's a single letter
        if (correctAnswerLetter.length > 1) {
          correctAnswerLetter = correctAnswerLetter.substring(0, 1);
        }
        
        // Build the full correct answer in the format "A. answer text"
        String correctAnswerFull = optionsList.firstWhere(
          (opt) => opt.startsWith('$correctAnswerLetter.'),
          orElse: () => optionsList[0],
        );
        
        debugPrint('✅ AI Question ${i+1}: correctAnswer="$correctAnswerFull", options=${optionsList.length}');
        
        aiQuestions.add(Question(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}_$i',
          questionText: q['question'] ?? '',
          type: QuestionType.multipleChoice,
          subject: _selectedSubject!,
          examType: _selectedExamType!,
          year: DateTime.now().year.toString(),
          section: 'AI Generated',
          questionNumber: i + 1,
          options: optionsList,
          correctAnswer: correctAnswerFull,
          explanation: q['explanation'],
          marks: 1,
          difficulty: q['difficulty'] ?? 'medium',
          topics: [q['topic'] ?? 'General'],
          createdAt: DateTime.now(),
          createdBy: 'ai',
          isActive: true,
        ));
      }

      if (aiQuestions.isEmpty) {
        throw Exception('No questions generated');
      }

      // Navigate to quiz taker with AI-generated questions
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizTakerPage(
            subject: _getSubjectDisplayName(_selectedSubject!),
            examType: _selectedExamType!.name.toUpperCase(),
            level: 'JHS 3',
            preloadedQuestions: aiQuestions,
            questionCount: _selectedQuestionCount,
            randomizeQuestions: false,
            customTitle: _topicController.text.trim().isNotEmpty 
                ? '${_getSubjectDisplayName(_selectedSubject!)} - ${_topicController.text.trim()}'
                : '${_getSubjectDisplayName(_selectedSubject!)} AI Practice',
            isRevisionQuiz: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error generating AI questions: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating AI questions: ${e.toString()}'),
          backgroundColor: const Color(0xFFD62828),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAIQuiz = false);
      }
    }
  }

  // Generate AI-powered flip cards
  Future<void> _generateAIFlipCards() async {
    if (_selectedExamType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both exam type and subject'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() => _isGeneratingFlipCards = true);

    try {
      final customTopic = _flipCardTopicController.text.trim();
      debugPrint('📝 Calling generateAIFlipCards with params: subject=${_selectedSubject!.name}, examType=${_selectedExamType!.name}, count=$_selectedCardCount, difficulty=$_selectedFlipCardDifficulty, classLevel=$_selectedFlipCardClassLevel, topic=$customTopic');
      
      final callable = FirebaseFunctions.instance.httpsCallable('generateAIFlipCards');
      final result = await callable.call({
        'subject': _selectedSubject!.name,
        'examType': _selectedExamType!.name,
        'numCards': _selectedCardCount,
        'difficultyLevel': _selectedFlipCardDifficulty,
        'classLevel': _selectedFlipCardClassLevel,
        'customTopic': customTopic.isNotEmpty ? customTopic : null,
      });

      final data = result.data;
      if (data['success'] != true || data['cards'] == null) {
        throw Exception('Invalid response from AI service');
      }

      // Convert AI-generated cards to Question objects for FlipCardPage
      final List<Question> flipCardQuestions = [];
      for (var i = 0; i < (data['cards'] as List).length; i++) {
        final card = data['cards'][i];
        
        debugPrint('✅ AI Flip Card ${i+1}: front="${card['front']}", back="${card['back']}"');
        
        // Create a Question object from the flip card data
        // Front of card = question text, Back = correct answer, explanation remains
        flipCardQuestions.add(Question(
          id: 'flipcard_${DateTime.now().millisecondsSinceEpoch}_$i',
          questionText: card['front'] ?? '',
          type: QuestionType.shortAnswer,
          subject: _selectedSubject!,
          examType: _selectedExamType!,
          year: DateTime.now().year.toString(),
          section: 'AI Flip Cards',
          questionNumber: i + 1,
          options: null, // No options for flip cards
          correctAnswer: card['back'] ?? '',
          explanation: card['explanation'],
          marks: 1,
          difficulty: card['difficulty'] ?? _selectedFlipCardDifficulty,
          topics: [card['topic'] ?? (customTopic.isNotEmpty ? customTopic : 'General')],
          createdAt: DateTime.now(),
          createdBy: 'ai',
          isActive: true,
        ));
      }

      if (flipCardQuestions.isEmpty) {
        throw Exception('No flip cards generated');
      }

      // Navigate to flip card page with AI-generated cards
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlipCardPage(
            subject: _getSubjectDisplayName(_selectedSubject!),
            examType: _selectedExamType!.name.toUpperCase(),
            questions: flipCardQuestions,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error generating AI flip cards: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating AI flip cards: ${e.toString()}'),
          backgroundColor: const Color(0xFFD62828),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingFlipCards = false);
      }
    }
  }

  // TODO: Re-enable when flip card questions source is available
  // Future<void> _generateFlipCard() async {
  //   if (_selectedExamType == null || _selectedSubject == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Please select both exam type and subject'),
  //         backgroundColor: Color(0xFFD62828),
  //       ),
  //     );
  //     return;
  //   }

  //   setState(() => _isGeneratingQuiz = true);

  //   try {
  //     // Get all questions for the selected subject and exam type
  //     final allQuestions = await _questionService.getQuestionsByFilters(
  //       examType: _selectedExamType,
  //       subject: _selectedSubject,
  //       activeOnly: true,
  //     );

  //     if (allQuestions.isEmpty) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('No questions found for ${_getSubjectDisplayName(_selectedSubject!)} (${_selectedExamType!.name.toUpperCase()})'),
  //           backgroundColor: const Color(0xFFD62828),
  //         ),
  //       );
  //       return;
  //     }

  //     // Generate robust random selection
  //     final selectedQuestions = _selectRandomQuestions(allQuestions, _selectedQuestionCount);

  //     if (selectedQuestions.isEmpty) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Unable to generate flip cards. Please try again.'),
  //           backgroundColor: Color(0xFFD62828),
  //         ),
  //       );
  //       return;
  //     }

  //     // Navigate to flip card page
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => FlipCardPage(
  //           subject: _getSubjectDisplayName(_selectedSubject!),
  //           examType: _selectedExamType!.name.toUpperCase(),
  //           questions: selectedQuestions,
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     debugPrint('Error generating flip cards: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Error generating flip cards. Please try again.'),
  //         backgroundColor: Color(0xFFD62828),
  //       ),
  //     );
  //   } finally {
  //     setState(() => _isGeneratingQuiz = false);
  //   }
  // }

  List<Question> _selectRandomQuestions(List<Question> allQuestions, int count) {
    if (allQuestions.length <= count) {
      // Return all questions if we don't have enough
      return List.from(allQuestions);
    }

    // Create a robust randomization algorithm
    final selectedQuestions = <Question>[];

    // Shuffle the questions using a seed based on current time and user selections
    final shuffledQuestions = List<Question>.from(allQuestions);
    shuffledQuestions.shuffle();

    // Take the first 'count' questions from the shuffled list
    selectedQuestions.addAll(shuffledQuestions.take(count));

    // Sort by question number for consistent ordering within the quiz
    selectedQuestions.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));

    return selectedQuestions;
  }

  String _getSubjectDisplayName(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English';
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
        return 'Religious and Moral Education';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.trivia:
        return 'Trivia';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Revision',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 28 : 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create personalized mock exams to test your knowledge',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),

              // Exam Type, Subject & Question Count Selection (Combined)
              _buildSelectionCard(
                title: 'Create Mock Exam',
                subtitle: 'Choose your exam type, subject, and number of questions',
                child: _buildExamTypeSubjectAndCountSelector(isSmallScreen),
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 32 : 40),

              // Generate Quiz Buttons
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Choose your mock exam type',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use database questions or generate fresh AI questions',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Database Mock Exam Button
                    _isGeneratingQuiz
                        ? Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF2ECC71)),
                              const SizedBox(height: 8),
                              Text(
                                'Loading questions from database...',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: _generateMockExam,
                            icon: const Icon(Icons.library_books, size: 20),
                            label: Text(
                              'Generate from Database',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2ECC71),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                    
                    const SizedBox(height: 16),
                    
                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // AI-specific options (Difficulty & Topic)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 20, color: Color(0xFFD62828)),
                              const SizedBox(width: 8),
                              Text(
                                'AI Generation Options',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD62828),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Difficulty and Topic fields
                          if (isSmallScreen) ...[
                            _buildFilterDropdown('Difficulty', _selectedQuizDifficulty, _difficultyLevels, (value) {
                              setState(() => _selectedQuizDifficulty = value!);
                            }),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _topicController,
                              decoration: InputDecoration(
                                labelText: 'Topic (Optional)',
                                hintText: 'e.g., Algebra, Grammar, Electricity',
                                labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                                hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildFilterDropdown('Difficulty', _selectedQuizDifficulty, _difficultyLevels, (value) {
                                    setState(() => _selectedQuizDifficulty = value!);
                                  }),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _topicController,
                                    decoration: InputDecoration(
                                      labelText: 'Topic (Optional)',
                                      hintText: 'e.g., Algebra, Grammar, Electricity',
                                      labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                                      hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // AI Mock Exam Button
                    _isGeneratingAIQuiz
                        ? Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFFD62828)),
                              const SizedBox(height: 8),
                              Text(
                                'AI is generating questions...',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: _generateAIQuestions,
                            icon: const Icon(Icons.auto_awesome, size: 20),
                            label: Text(
                              'Generate with AI',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD62828),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                    
                    const SizedBox(height: 16),
                    
                    // Info card for AI generation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI generates fresh, randomized questions based on BECE standards and Ghana NACCA curriculum',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isSmallScreen ? 32 : 40),

              // AI Flip Cards Section
              _buildSelectionCard(
                title: 'AI Flip Cards',
                subtitle: 'Generate interactive study cards with AI',
                child: Column(
                  children: [
                    // Flip card options
                    _buildFlipCardOptionsSelector(isSmallScreen),
                    const SizedBox(height: 24),
                    
                    // Generate button
                    _isGeneratingFlipCards
                        ? Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF9B59B6)),
                              const SizedBox(height: 8),
                              Text(
                                'AI is generating flip cards...',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: _generateAIFlipCards,
                            icon: const Icon(Icons.flip_to_front, size: 20),
                            label: Text(
                              'Generate AI Flip Cards',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B59B6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                    
                    const SizedBox(height: 16),
                    
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Colors.purple[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI creates various card formats: definitions, questions, concepts, processes, and more',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.purple[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                isSmallScreen: isSmallScreen,
              ),

              // Add bottom padding for mobile
              if (isSmallScreen) const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildExamTypeSubjectAndCountSelector(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter dropdowns
        if (isSmallScreen)
          Column(
            children: [
              _buildFilterDropdown('Exam Type', _selectedExamType?.name.toUpperCase() ?? 'Select Type', _getExamTypeOptions(), (value) {
                final examType = value == 'Select Type' ? null : ExamType.values.firstWhere((e) => e.name.toUpperCase() == value);
                setState(() => _selectedExamType = examType);
              }),
              const SizedBox(height: 12),
              _buildFilterDropdown('Subject', _selectedSubject != null ? _getSubjectDisplayName(_selectedSubject!) : 'Select Subject', _getSubjectOptions(), (value) {
                final subject = value == 'Select Subject' ? null : _availableSubjects.firstWhere((s) => _getSubjectDisplayName(s) == value);
                setState(() => _selectedSubject = subject);
              }),
              const SizedBox(height: 12),
              _buildFilterDropdown('Question Count', _selectedQuestionCount.toString(), ['10', '20', '40'], (value) {
                setState(() => _selectedQuestionCount = int.parse(value!));
              }),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown('Exam Type', _selectedExamType?.name.toUpperCase() ?? 'Select Type', _getExamTypeOptions(), (value) {
                  final examType = value == 'Select Type' ? null : ExamType.values.firstWhere((e) => e.name.toUpperCase() == value);
                  setState(() => _selectedExamType = examType);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Subject', _selectedSubject != null ? _getSubjectDisplayName(_selectedSubject!) : 'Select Subject', _getSubjectOptions(), (value) {
                  final subject = value == 'Select Subject' ? null : _availableSubjects.firstWhere((s) => _getSubjectDisplayName(s) == value);
                  setState(() => _selectedSubject = subject);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Question Count', _selectedQuestionCount.toString(), ['10', '20', '40'], (value) {
                  setState(() => _selectedQuestionCount = int.parse(value!));
                }),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF8FAFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownColor: Colors.white,
      style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
      items: options.map((option) {
        return DropdownMenuItem(value: option, child: Text(option));
      }).toList(),
    );
  }

  Widget _buildFlipCardOptionsSelector(bool isSmall) {
    return Column(
      children: [
        // Card count, difficulty, and class level
        if (isSmall) ...[
          _buildFilterDropdown(
            'Number of Cards',
            _selectedCardCount.toString(),
            ['10', '20', '30', '40'],
            (v) => setState(() => _selectedCardCount = int.parse(v!)),
          ),
          const SizedBox(height: 12),
          _buildFilterDropdown(
            'Difficulty',
            _selectedFlipCardDifficulty,
            _difficultyLevels,
            (v) => setState(() => _selectedFlipCardDifficulty = v!),
          ),
          const SizedBox(height: 12),
          _buildFilterDropdown(
            'Class Level',
            _selectedFlipCardClassLevel,
            _classLevels,
            (v) => setState(() => _selectedFlipCardClassLevel = v!),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Number of Cards',
                  _selectedCardCount.toString(),
                  ['10', '20', '30', '40'],
                  (v) => setState(() => _selectedCardCount = int.parse(v!)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Difficulty',
                  _selectedFlipCardDifficulty,
                  _difficultyLevels,
                  (v) => setState(() => _selectedFlipCardDifficulty = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Class Level',
                  _selectedFlipCardClassLevel,
                  _classLevels,
                  (v) => setState(() => _selectedFlipCardClassLevel = v!),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        
        // Topic input field
        TextField(
          controller: _flipCardTopicController,
          decoration: InputDecoration(
            labelText: 'Topic (Optional)',
            hintText: 'e.g., Photosynthesis, Fractions, Ghana History',
            labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
            hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFFF8FAFE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
        ),
      ],
    );
  }

  List<String> _getExamTypeOptions() {
    return ['Select Type', ..._availableExamTypes.map((e) => e.name.toUpperCase())];
  }

  List<String> _getSubjectOptions() {
    return ['Select Subject', ..._availableSubjects.map((s) => _getSubjectDisplayName(s))];
  }
}