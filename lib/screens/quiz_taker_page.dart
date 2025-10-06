import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../services/question_service.dart';
import 'quiz_results_page.dart';

class QuizTakerPage extends StatefulWidget {
  final String subject;
  final String examType;
  final String level;
  final List<Question>? preloadedQuestions;
  final int? questionCount;

  const QuizTakerPage({
    super.key,
    required this.subject,
    required this.examType,
    required this.level,
    this.preloadedQuestions,
    this.questionCount,
  });

  @override
  State<QuizTakerPage> createState() => _QuizTakerPageState();
}

class _QuizTakerPageState extends State<QuizTakerPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _progressController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final QuestionService _questionService = QuestionService();
  
  List<Question> questions = [];
  int currentQuestionIndex = 0;
  Map<int, String> userAnswers = {};
  bool isLoading = true;
  bool isSubmitting = false;
  String? selectedAnswer;
  
  DateTime? quizStartTime;
  DateTime? quizEndTime;
  
  bool showExplanation = false;
  bool isPracticeMode = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _loadQuestions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      setState(() => isLoading = true);
      
      if (widget.preloadedQuestions != null) {
        questions = widget.preloadedQuestions!;
      } else {
        // Map display name to Firestore field name
        final subjectEnum = _mapStringToSubject(widget.subject);
        final examTypeEnum = _mapStringToExamType(widget.examType);
        
        print('🎯 QuizTaker: Loading questions for subject=${subjectEnum.name}, examType=${examTypeEnum.name}, level=${widget.level}');
        
        questions = await _questionService.getQuestionsByFilters(
          subject: subjectEnum,
          examType: examTypeEnum,
          level: widget.level,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏰ QuizTaker: Timeout loading questions');
            return <Question>[];
          },
        );
        
        print('📊 QuizTaker: Loaded ${questions.length} questions');
      }
      
      // Shuffle questions for randomization
      questions.shuffle();
      
      // Limit to specified question count
      // Special rule: Trivia is always limited to 20 questions
      int maxQuestions;
      if (widget.examType.toLowerCase() == 'trivia') {
        maxQuestions = widget.questionCount ?? 20; // Trivia default: 20 questions
      } else {
        maxQuestions = widget.questionCount ?? (questions.length > 50 ? 50 : questions.length);
      }
      
      if (questions.length > maxQuestions) {
        questions = questions.take(maxQuestions).toList();
      }
      
      print('📊 QuizTaker: Final question count: ${questions.length} (max: $maxQuestions for ${widget.examType})');
      
      // If no questions loaded, create a fallback or just continue silently
      if (questions.isNotEmpty) {
        quizStartTime = DateTime.now();
        _animationController.forward();
      }
      
    } catch (e) {
      // Silent fallback - don't show error dialog to user
      print('Quiz questions loading error (handled gracefully): $e');
      setState(() {
        questions = [];
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      selectedAnswer = answer;
    });
  }

  Future<void> _nextQuestion() async {
    if (selectedAnswer == null) return;
    
    // Store the answer
    userAnswers[currentQuestionIndex] = selectedAnswer!;
    
    if (isPracticeMode) {
      setState(() => showExplanation = true);
      await Future.delayed(const Duration(seconds: 2));
      setState(() => showExplanation = false);
    }
    
    if (currentQuestionIndex < questions.length - 1) {
      // Animate to next question
      await _animationController.reverse();
      
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = userAnswers[currentQuestionIndex];
      });
      
      _updateProgress();
      await _animationController.forward();
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() async {
    if (currentQuestionIndex > 0) {
      await _animationController.reverse();
      
      setState(() {
        currentQuestionIndex--;
        selectedAnswer = userAnswers[currentQuestionIndex];
      });
      
      _updateProgress();
      await _animationController.forward();
    }
  }

  void _updateProgress() {
    final progress = (currentQuestionIndex + 1) / questions.length;
    _progressController.animateTo(progress);
  }

  Future<void> _finishQuiz() async {
    if (userAnswers.length < questions.length) {
      _showConfirmationDialog();
      return;
    }
    
    setState(() => isSubmitting = true);
    
    quizEndTime = DateTime.now();
    
    // Calculate results
    int correctAnswers = 0;
    List<QuizAnswer> quizAnswers = [];
    
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final userAnswer = userAnswers[i] ?? '';
      
      // Extract answer letter from full option text (e.g., "E. 6th day" -> "E")
      String userAnswerLetter = userAnswer;
      if (userAnswer.contains('.')) {
        userAnswerLetter = userAnswer.split('.')[0].trim();
      }
      
      // Also handle if correctAnswer has the full text
      String correctAnswerLetter = question.correctAnswer;
      if (correctAnswerLetter.contains('.')) {
        correctAnswerLetter = correctAnswerLetter.split('.')[0].trim();
      }
      
      final isCorrect = userAnswerLetter == correctAnswerLetter;
      
      print('🎯 Quiz Result: Q${i+1} - User: "$userAnswerLetter" vs Correct: "$correctAnswerLetter" = ${isCorrect ? "✅" : "❌"}');
      
      if (isCorrect) correctAnswers++;
      
      quizAnswers.add(QuizAnswer(
        questionId: question.id,
        questionText: question.questionText,
        userAnswer: userAnswer,
        correctAnswer: question.correctAnswer,
        isCorrect: isCorrect,
        options: question.options ?? [],
        explanation: question.explanation ?? '',
      ));
    }
    
    final quiz = Quiz(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subject: widget.subject,
      examType: widget.examType,
      level: widget.level,
      totalQuestions: questions.length,
      correctAnswers: correctAnswers,
      answers: quizAnswers,
      startTime: quizStartTime!,
      endTime: quizEndTime!,
    );
    
    // Navigate to results
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultsPage(quiz: quiz),
      ),
    );
  }

  void _showConfirmationDialog() {
    final unanswered = questions.length - userAnswers.length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Submit Quiz?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        content: Text(
          'You have $unanswered unanswered questions. Are you sure you want to submit?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue Quiz',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finishQuiz();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: Text('Submit', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  void _exitQuiz() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Exit Quiz?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        content: Text(
          'Your progress will be lost. Are you sure you want to exit?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue Quiz',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: Text('Exit', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading Quiz...',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preparing ${widget.subject} questions',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1E3F)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  'No Questions Found',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No questions available for ${widget.subject} (${widget.examType}).\nPlease try a different subject or check back later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Back to Questions', style: GoogleFonts.montserrat()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];
    final progress = (currentQuestionIndex + 1) / questions.length;

    return WillPopScope(
      onWillPop: () async {
        _exitQuiz();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        body: SafeArea(
          child: Column(
            children: [
              // Header with progress
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top row with back button and quiz info
                    Row(
                      children: [
                        IconButton(
                          onPressed: _exitQuiz,
                          icon: const Icon(Icons.close, color: Color(0xFF1A1E3F)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${widget.subject} Quiz',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1E3F),
                                ),
                              ),
                              Text(
                                'Question ${currentQuestionIndex + 1} of ${questions.length}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD62828).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFD62828),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Progress bar
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),

              // Question content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_slideAnimation.value * 300, 0),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildQuestionCard(currentQuestion, isMobile),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Navigation buttons
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (currentQuestionIndex > 0) ...[
                      OutlinedButton.icon(
                        onPressed: _previousQuestion,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1E3F),
                          side: const BorderSide(color: Color(0xFF1A1E3F)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      const Spacer(),
                    ] else ...[
                      const Spacer(),
                    ],
                    
                    ElevatedButton.icon(
                      onPressed: selectedAnswer != null ? _nextQuestion : null,
                      icon: Icon(
                        currentQuestionIndex == questions.length - 1 
                            ? Icons.check 
                            : Icons.arrow_forward,
                      ),
                      label: Text(
                        currentQuestionIndex == questions.length - 1 
                            ? 'Finish Quiz' 
                            : 'Next',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedAnswer != null 
                            ? const Color(0xFFD62828) 
                            : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question, bool isMobile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text
            Text(
              question.questionText,
              style: GoogleFonts.playfairDisplay(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Answer options
            ...(question.options ?? []).map((option) {
              final isSelected = selectedAnswer == option;
              final isCorrect = option == question.correctAnswer;
              final showCorrect = showExplanation && isCorrect;
              final showIncorrect = showExplanation && isSelected && !isCorrect;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: showExplanation ? null : () => _selectAnswer(option),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: showCorrect 
                            ? Colors.green 
                            : showIncorrect 
                                ? Colors.red
                                : isSelected 
                                    ? const Color(0xFFD62828) 
                                    : Colors.grey[300]!,
                        width: isSelected || showCorrect || showIncorrect ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: showCorrect 
                          ? Colors.green.withOpacity(0.1)
                          : showIncorrect 
                              ? Colors.red.withOpacity(0.1)
                              : isSelected 
                                  ? const Color(0xFFD62828).withOpacity(0.1) 
                                  : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: showCorrect 
                                  ? Colors.green 
                                  : showIncorrect 
                                      ? Colors.red
                                      : isSelected 
                                          ? const Color(0xFFD62828) 
                                          : Colors.grey[400]!,
                              width: 2,
                            ),
                            color: isSelected || showCorrect 
                                ? (showCorrect ? Colors.green : const Color(0xFFD62828))
                                : Colors.white,
                          ),
                          child: isSelected || showCorrect 
                              ? Icon(
                                  showCorrect ? Icons.check : Icons.circle,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            option,
                            style: GoogleFonts.montserrat(
                              fontSize: isMobile ? 14 : 16,
                              color: const Color(0xFF1A1E3F),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (showCorrect) ...[
                          const Icon(Icons.check_circle, color: Colors.green),
                        ] else if (showIncorrect) ...[
                          const Icon(Icons.cancel, color: Colors.red),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            
            // Show explanation if in practice mode
            if (showExplanation && question.explanation?.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Explanation',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.explanation!,
                      style: GoogleFonts.montserrat(
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods to map string display names to enums
  Subject _mapStringToSubject(String subject) {
    switch (subject) {
      case 'Religious and Moral Education':
        return Subject.religiousMoralEducation;
      case 'Mathematics':
        return Subject.mathematics;
      case 'English Language':
        return Subject.english;
      case 'Science':
        return Subject.integratedScience;
      case 'Social Studies':
        return Subject.socialStudies;
      case 'Information Technology':
        return Subject.ict;
      case 'Creative Arts':
        return Subject.creativeArts;
      case 'French':
        return Subject.french;
      case 'Twi':
      case 'Ga':
      case 'Ewe':
        return Subject.ghanaianLanguage;
      default:
        return Subject.religiousMoralEducation;
    }
  }

  ExamType _mapStringToExamType(String examType) {
    switch (examType) {
      case 'BECE':
        return ExamType.bece;
      case 'Mock Exam':
        return ExamType.mock;
      case 'Class Test':
      case 'Assignment':
      case 'Practice Questions':
        return ExamType.practice;
      default:
        return ExamType.bece;
    }
  }
}
