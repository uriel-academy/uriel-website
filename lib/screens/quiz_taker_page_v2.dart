import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../services/question_service.dart';
import 'quiz_results_page.dart';

class QuizTakerPageV2 extends StatefulWidget {
  final String subject;
  final String examType;
  final String level;
  final List<Question>? preloadedQuestions;
  final int? questionCount;
  final String? triviaCategory;

  const QuizTakerPageV2({
    super.key,
    required this.subject,
    required this.examType,
    required this.level,
    this.preloadedQuestions,
    this.questionCount,
    this.triviaCategory,
  });

  @override
  State<QuizTakerPageV2> createState() => _QuizTakerPageV2State();
}

class _QuizTakerPageV2State extends State<QuizTakerPageV2>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _cardController;
  late AnimationController _feedbackController;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _fadeAnimation;

  final QuestionService _questionService = QuestionService();

  List<Question> questions = [];
  int currentQuestionIndex = 0;
  Map<int, String> userAnswers = {};
  bool isLoading = true;
  bool isSubmitting = false;
  String? selectedAnswer;
  bool hasAnswered = false;
  bool showCorrectAnswer = false;

  DateTime? quizStartTime;
  DateTime? quizEndTime;

  int correctAnswers = 0;
  int incorrectAnswers = 0;
  int currentStreak = 0;
  int bestStreak = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadQuestions();
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardSlideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _progressController.dispose();
    _cardController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      setState(() => isLoading = true);

      if (widget.preloadedQuestions != null) {
        questions = widget.preloadedQuestions!;
      } else {
        final subjectEnum = _mapStringToSubject(widget.subject);
        final examTypeEnum = _mapStringToExamType(widget.examType);

        questions = await _questionService.getQuestionsByFilters(
          subject: subjectEnum,
          examType: examTypeEnum,
          level: widget.level,
          triviaCategory: widget.triviaCategory,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => <Question>[],
        );
      }

      questions.shuffle();

      int maxQuestions;
      if (widget.examType.toLowerCase() == 'trivia') {
        maxQuestions = widget.questionCount ?? 20;
      } else {
        maxQuestions = widget.questionCount ?? (questions.length > 50 ? 50 : questions.length);
      }

      if (questions.length > maxQuestions) {
        questions = questions.take(maxQuestions).toList();
      }

      if (questions.isNotEmpty) {
        quizStartTime = DateTime.now();
        _progressController.forward();
        _cardController.forward();
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Error loading questions: $e');
      setState(() {
        questions = [];
        isLoading = false;
      });
    }
  }

  void _selectAnswer(String answer) {
    if (hasAnswered) return;
    setState(() {
      selectedAnswer = answer;
    });
  }

  void _submitAnswer() async {
    if (selectedAnswer == null || hasAnswered) return;

    setState(() {
      isSubmitting = true;
      hasAnswered = true;
      showCorrectAnswer = true;
    });

    final question = questions[currentQuestionIndex];
    final isCorrect = selectedAnswer == question.correctAnswer;

    userAnswers[currentQuestionIndex] = selectedAnswer!;

    if (isCorrect) {
      correctAnswers++;
      currentStreak++;
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
      }
      _showFeedbackAnimation(true);
    } else {
      incorrectAnswers++;
      currentStreak = 0;
      _showFeedbackAnimation(false);
    }

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      isSubmitting = false;
    });
  }

  void _showFeedbackAnimation(bool isCorrect) {
    _feedbackController.reset();
    _feedbackController.forward();
  }

  void _nextQuestion() async {
    if (!hasAnswered) return;

    if (currentQuestionIndex < questions.length - 1) {
      // Slide out animation
      await _cardController.reverse();

      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
        hasAnswered = false;
        showCorrectAnswer = false;
      });

      // Slide in animation
      await _cardController.forward();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    quizEndTime = DateTime.now();

    final quizAnswers = <QuizAnswer>[];
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final userAnswer = userAnswers[i] ?? '';
      final isCorrect = userAnswer == question.correctAnswer;

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
      triviaCategory: widget.triviaCategory,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultsPage(quiz: quiz),
      ),
    );
  }

  void _exitQuiz() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exit Quiz?', style: GoogleFonts.playfairDisplay(
          fontWeight: FontWeight.bold,
        )),
        content: Text(
          'Your progress will be lost. Are you sure?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
            ),
            child: Text('Exit', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Subject _mapStringToSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'trivia':
        return Subject.trivia;
      case 'religious and moral education':
      case 'rme':
        return Subject.religiousMoralEducation;
      case 'mathematics':
        return Subject.mathematics;
      case 'english language':
      case 'english':
        return Subject.english;
      case 'science':
        return Subject.integratedScience;
      case 'social studies':
        return Subject.socialStudies;
      default:
        return Subject.religiousMoralEducation;
    }
  }

  ExamType _mapStringToExamType(String examType) {
    switch (examType.toLowerCase()) {
      case 'trivia':
        return ExamType.trivia;
      case 'bece':
        return ExamType.bece;
      case 'wassce':
        return ExamType.wassce;
      case 'mock':
        return ExamType.mock;
      default:
        return ExamType.bece;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF6B21A8)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Loading questions...',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF6B21A8)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.quiz_outlined, size: 80, color: Colors.white70),
                const SizedBox(height: 24),
                Text(
                  'No Questions Found',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'No questions available for this quiz.\nPlease try a different category.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6B21A8),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Back', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = questions[currentQuestionIndex];
    final progress = (currentQuestionIndex + 1) / questions.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B5CF6), Color(0xFF6B21A8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(_cardSlideAnimation.value, 0),
                      end: Offset.zero,
                    ).animate(_cardController),
                    child: _buildQuestionCard(question, progress),
                  ),
                ),
              ),
              _buildExitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _exitQuiz,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Text(
            widget.triviaCategory ?? widget.subject,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${currentQuestionIndex + 1} / ${questions.length}',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question, double progress) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildProgressRing(progress),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildQuestionText(question),
                  const SizedBox(height: 32),
                  _buildAnswerOptions(question),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentQuestionIndex + 1}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                  Text(
                    'of ${questions.length}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                child: _buildScoreBadge(correctAnswers, Colors.green, Icons.check),
              ),
              Positioned(
                right: 0,
                child: _buildScoreBadge(incorrectAnswers, Colors.red, Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (currentStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$currentStreak Streak!',
                    style: GoogleFonts.montserrat(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(int count, Color color, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: Text(
          '$count',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionText(Question question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image before question (e.g., diagram for context)
        if (question.imageBeforeQuestion != null) ...[
          _buildQuestionImage(question.imageBeforeQuestion!),
          const SizedBox(height: 16),
        ],
        
        // Question text
        Text(
          question.questionText,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
            height: 1.5,
          ),
        ),
        
        // Image after question (e.g., figure to analyze)
        if (question.imageAfterQuestion != null) ...[
          const SizedBox(height: 16),
          _buildQuestionImage(question.imageAfterQuestion!),
        ],
        
        // Legacy imageUrl support
        if (question.imageUrl != null && 
            question.imageBeforeQuestion == null && 
            question.imageAfterQuestion == null) ...[
          const SizedBox(height: 16),
          _buildQuestionImage(question.imageUrl!),
        ],
      ],
    );
  }
  
  Widget _buildQuestionImage(String imageUrl) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey[100],
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: Colors.grey[100],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, 
                  size: 48, 
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerOptions(Question question) {
    final options = question.options ?? [];
    
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final letter = String.fromCharCode(65 + index); // A, B, C, D
        
        final isSelected = selectedAnswer == letter;
        final isCorrect = question.correctAnswer == letter;
        final shouldShowFeedback = hasAnswered && showCorrectAnswer;

        Color backgroundColor;
        Color textColor;
        Color borderColor;
        IconData? icon;

        if (shouldShowFeedback) {
          if (isCorrect) {
            backgroundColor = const Color(0xFF2ECC71);
            textColor = Colors.white;
            borderColor = const Color(0xFF2ECC71);
            icon = Icons.check_circle;
          } else if (isSelected) {
            backgroundColor = const Color(0xFFFFB3BA);
            textColor = Colors.white;
            borderColor = const Color(0xFFFF6B6B);
            icon = Icons.cancel;
          } else {
            backgroundColor = Colors.white;
            textColor = Colors.grey[600]!;
            borderColor = Colors.grey[300]!;
          }
        } else {
          if (isSelected) {
            backgroundColor = const Color(0xFFF3E8FF);
            textColor = const Color(0xFF6B21A8);
            borderColor = const Color(0xFF8B5CF6);
          } else {
            backgroundColor = Colors.white;
            textColor = Colors.grey[800]!;
            borderColor = Colors.grey[300]!;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: hasAnswered ? null : () => _selectAnswer(letter),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: shouldShowFeedback && (isSelected || isCorrect)
                          ? Colors.white24
                          : borderColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: GoogleFonts.montserrat(
                          color: shouldShowFeedback && (isSelected || isCorrect)
                              ? Colors.white
                              : textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.replaceFirst('$letter. ', ''),
                          style: GoogleFonts.montserrat(
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Option image if available
                        if (question.optionImages != null && 
                            question.optionImages!.containsKey(letter)) ...[
                          const SizedBox(height: 8),
                          _buildOptionImage(question.optionImages![letter]!),
                        ],
                      ],
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 12),
                    Icon(icon, color: Colors.white, size: 24),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildOptionImage(String imageUrl) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 150,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            height: 100,
            color: Colors.grey[50],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 100,
            color: Colors.grey[50],
            child: Icon(Icons.image_not_supported, 
              size: 32, 
              color: Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (!hasAnswered)
          Expanded(
            child: ElevatedButton(
              onPressed: selectedAnswer == null ? null : _submitAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21A8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Answer It',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        if (hasAnswered)
          Expanded(
            child: ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                currentQuestionIndex < questions.length - 1 ? 'Next' : 'Finish',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExitButton() {
    return InkWell(
      onTap: _exitQuiz,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.close, color: Color(0xFF6B21A8), size: 28),
      ),
    );
  }
}
