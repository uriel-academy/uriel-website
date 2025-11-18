import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../models/passage_model.dart';
import '../services/question_service.dart';
import 'quiz_results_page.dart';

class QuizTakerPage extends StatefulWidget {
  final String subject;
  final String examType;
  final String level;
  final List<Question>? preloadedQuestions;
  final int? questionCount;
  final String? triviaCategory;
  final bool randomizeQuestions;
  final String? customTitle;
  final bool isRevisionQuiz;

  const QuizTakerPage({
    super.key,
    required this.subject,
    required this.examType,
    required this.level,
    this.preloadedQuestions,
    this.questionCount,
    this.triviaCategory,
    this.randomizeQuestions = false,
    this.customTitle,
    this.isRevisionQuiz = false,
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
  
  // Passage support
  Map<String, Passage> passageCache = {}; // Cache passages by ID to avoid refetching
  bool isPassageExpanded = true; // Start with passage expanded

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
        questions = List<Question>.from(widget.preloadedQuestions!);
      } else {
        // Map display name to Firestore field name
        final subjectEnum = _mapStringToSubject(widget.subject);
        final examTypeEnum = _mapStringToExamType(widget.examType);
        
        debugPrint('🎯 QuizTaker: Loading questions for subject=${subjectEnum.name}, examType=${examTypeEnum.name}, level=${widget.level}, triviaCategory=${widget.triviaCategory}');
        
        questions = await _questionService.getQuestionsByFilters(
          subject: subjectEnum,
          examType: examTypeEnum,
          level: widget.level,
          triviaCategory: widget.triviaCategory,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('⏰ QuizTaker: Timeout loading questions after 30 seconds');
            return <Question>[];
          },
        );
        
        debugPrint('📊 QuizTaker: Loaded ${questions.length} questions');
        
        if (questions.isEmpty) {
          debugPrint('⚠️ QuizTaker: NO QUESTIONS LOADED! Check:');
          debugPrint('   - Firestore rules allow reading questions');
          debugPrint('   - User is authenticated');
          debugPrint('   - Questions exist for subject=${subjectEnum.name}, examType=${examTypeEnum.name}, triviaCategory=${widget.triviaCategory}');
        }
      }
      
      // Shuffle questions for randomization (only if enabled)
      if (widget.randomizeQuestions) {
        questions.shuffle();
      } else {
        // Ensure deterministic ordering when not randomizing: sort by questionNumber only
        // Handle null-safe comparison
        questions.sort((a, b) {
          final aNum = a.questionNumber;
          final bNum = b.questionNumber;
          if (aNum == bNum) return 0;
          return aNum.compareTo(bNum);
        });
      }
      
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
      
      debugPrint('📊 QuizTaker: Final question count: ${questions.length} (max: $maxQuestions for ${widget.examType})');
      
      // Pre-load all passages for questions that have them
      await _preloadPassages();
      
      // If no questions loaded, create a fallback or just continue silently
      if (questions.isNotEmpty) {
        quizStartTime = DateTime.now();
        _animationController.forward();
      }
      
    } catch (e) {
      // Silent fallback - don't show error dialog to user
      debugPrint('Quiz questions loading error (handled gracefully): $e');
      setState(() {
        questions = [];
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _preloadPassages() async {
    // Collect unique passage IDs from all questions
    final passageIds = questions
        .where((q) => q.passageId != null)
        .map((q) => q.passageId!)
        .toSet();
    
    if (passageIds.isEmpty) {
      debugPrint('📖 No passages to preload');
      return;
    }

    debugPrint('📖 Preloading ${passageIds.length} passages...');
    
    // Fetch all passages in parallel
    await Future.wait(
      passageIds.map((passageId) async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('passages')
              .doc(passageId)
              .get();

          if (doc.exists) {
            final passage = Passage.fromJson({...doc.data()!, 'id': doc.id});
            passageCache[passageId] = passage;
            debugPrint('✅ Loaded passage: $passageId');
          } else {
            debugPrint('⚠️ Passage not found: $passageId');
          }
        } catch (e) {
          debugPrint('❌ Error loading passage $passageId: $e');
        }
      }),
    );
    
    debugPrint('📖 Preloaded ${passageCache.length} passages successfully');
  }

  void _selectAnswer(String answer) {
    setState(() {
      selectedAnswer = answer;
    });
  }

  Passage? _getPassage(String passageId) {
    // Simply return from cache (already pre-loaded)
    return passageCache[passageId];
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
      // Ensure it's uppercase for comparison
      userAnswerLetter = userAnswerLetter.toUpperCase();
      
      // Also handle if correctAnswer has the full text
      String correctAnswerLetter = question.correctAnswer;
      if (correctAnswerLetter.contains('.')) {
        correctAnswerLetter = correctAnswerLetter.split('.')[0].trim();
      }
      // Ensure it's uppercase for comparison
      correctAnswerLetter = correctAnswerLetter.toUpperCase();
      
      final isCorrect = userAnswerLetter == correctAnswerLetter;
      
      debugPrint('🎯 Quiz Result: Q${i+1} - User: "$userAnswerLetter" vs Correct: "$correctAnswerLetter" = ${isCorrect ? "✅" : "❌"}');
      debugPrint('   Raw user answer: "$userAnswer"');
      debugPrint('   Raw correct answer: "${question.correctAnswer}"');
      
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
      triviaCategory: widget.triviaCategory,
    );
    
    // Navigate to results
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultsPage(
          quiz: quiz,
          isRevisionQuiz: widget.isRevisionQuiz,
        ),
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
  // Determine a descriptive header including year when available so users
  // remember which year's questions they're solving.
  final String headerTitle = widget.customTitle ?? (widget.triviaCategory != null
    ? widget.triviaCategory!
    : (currentQuestion.year.isNotEmpty)
      ? '${widget.subject} (${currentQuestion.year}) Quiz'
      : '${widget.subject} Quiz');
    final progress = (currentQuestionIndex + 1) / questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _exitQuiz();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        body: SafeArea(
          child: Column(
            children: [
              // Header with progress
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 19), // Reduced by 20% (16→12.8≈12, 24→19.2≈19)
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
                                headerTitle,
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
                            color: const Color(0xFFD62828).withValues(alpha: 0.1),
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 800, // 40% width reduction for desktop
                      ),
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
                ),
              ),

              // Navigation buttons
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 19), // Reduced by 20% (16→12.8≈12, 24→19.2≈19)
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

  Widget _buildQuestionImageWidget(String imageUrl) {
    // If the imageUrl looks like a packaged asset path, load from assets.
    try {
      if (imageUrl.startsWith('assets/') || !imageUrl.startsWith('http')) {
        // Support SVG packaged assets as well as raster images.
        if (imageUrl.toLowerCase().endsWith('.svg')) {
          return SvgPicture.asset(
            imageUrl,
            fit: BoxFit.contain,
            placeholderBuilder: (context) => Container(
              color: Colors.grey[100],
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return Image.asset(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey[200],
            height: 120,
            child: const Center(child: Icon(Icons.broken_image)),
          ),
        );
      }
    } catch (e) {
      // fall through to network
    }

    // Otherwise assume network URL
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => Container(
        color: Colors.grey[100],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        height: 120,
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }

  /// Helper that checks if a bundled asset exists.
  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Small wrapper that builds the tappable image section used in questions.
  Widget _buildImageSection(String imgPath, bool isMobile, {bool expand = false}) {
    final double height = expand ? (isMobile ? 280 : 380) : (isMobile ? 220 : 320);
    return Center(
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                child: _buildQuestionImageWidget(imgPath),
              ),
            ),
          );
        },
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? MediaQuery.of(context).size.width : 700),
                child: _buildQuestionImageWidget(imgPath),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassageSection(Passage passage, bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFF5F5F5), // Light background for readability
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
          InkWell(
            onTap: () {
              setState(() => isPassageExpanded = !isPassageExpanded);
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1E3F).withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    isPassageExpanded ? Icons.menu_book : Icons.menu_book_outlined,
                    color: const Color(0xFF1A1E3F),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      passage.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ),
                  Icon(
                    isPassageExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF1A1E3F),
                  ),
                ],
              ),
            ),
          ),
          // Passage content (collapsible)
          if (isPassageExpanded) ...[
            Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Text(
                passage.content,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 14 : 16,
                  color: const Color(0xFF2C2C2C),
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionInstructions(String instructions, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6), // Soft yellow for instructions
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: const Color(0xFFD97706),
            size: isMobile ? 20 : 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instructions,
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 13 : 15,
                color: const Color(0xFF78350F),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question, bool isMobile) {
    // Priority order for images:
    // 1. imageBeforeQuestion - shown at the very top
    // 2. imageAfterQuestion - shown after question text
    // 3. imageUrl (legacy) - shown after question text if no imageAfterQuestion
    // 4. optionImages - shown with each option
    
    final String? imageBeforeQ = (question.imageBeforeQuestion != null && question.imageBeforeQuestion!.isNotEmpty) 
        ? question.imageBeforeQuestion 
        : null;
    final String? imageAfterQ = (question.imageAfterQuestion != null && question.imageAfterQuestion!.isNotEmpty) 
        ? question.imageAfterQuestion 
        : (question.imageUrl != null && question.imageUrl!.isNotEmpty) 
            ? question.imageUrl 
            : null;
    final String guessedAssetPath = 'assets/bece_ict/bece_ict_${question.year}_q_${question.questionNumber}.png';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Passage section (if question has a passage)
        if (question.passageId != null) ...[
          Builder(
            builder: (context) {
              final passage = _getPassage(question.passageId!);
              if (passage != null) {
                return _buildPassageSection(passage, isMobile);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        
        // Section instructions (if present)
        if (question.sectionInstructions != null && question.sectionInstructions!.isNotEmpty) ...[
          _buildSectionInstructions(question.sectionInstructions!, isMobile),
        ],
        
        // Question card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1A1E3F), // Uriel blue background
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image before question (for context/diagrams shown above)
                if (imageBeforeQ != null) ...[
                  _buildImageSection(imageBeforeQ, isMobile),
                  const SizedBox(height: 16),
                ],
                
                // Question text with underline support
                _buildQuestionText(question.questionText, isMobile),
            
                const SizedBox(height: 24),

                // Image after question (for figures/graphs shown below question text)
                if (imageAfterQ != null) ...[
                  _buildImageSection(imageAfterQ, isMobile),
                  const SizedBox(height: 24),
                ] else if (question.subject == Subject.ict && question.year == '2024' && question.questionNumber == 38) ...[
                  // Fallback: Only attempt to show the guessed packaged ICT asset for this specific
                  // known question (ICT 2024 Q38). This avoids introducing guessed
                  // image placeholders/thumbnails for other ICT questions.
                  FutureBuilder<bool>(
                    future: _assetExists(guessedAssetPath),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox();
                      }
                      if (snapshot.hasData && snapshot.data == true) {
                        // For this specific case, expand the image area so it is visible on mobile.
                        return _buildImageSection(guessedAssetPath, isMobile, expand: true);
                      }
                      return const SizedBox();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
            
            // Answer options
            ...(question.options ?? []).map((option) {
              final isSelected = selectedAnswer == option;
              
              // Extract letter from option for comparison (e.g., "B. Yaren" -> "B")
              String optionLetter = option;
              if (option.contains('.')) {
                optionLetter = option.split('.')[0].trim().toUpperCase();
              }
              
              // Extract letter from correct answer for comparison
              String correctLetter = question.correctAnswer;
              if (correctLetter.contains('.')) {
                correctLetter = correctLetter.split('.')[0].trim().toUpperCase();
              } else {
                correctLetter = correctLetter.toUpperCase();
              }
              
              final isCorrect = optionLetter == correctLetter;
              final showCorrect = showExplanation && isCorrect;
              final showIncorrect = showExplanation && isSelected && !isCorrect;
              
              // Check if this option has an image
              final String? optionImageUrl = question.optionImages?[optionLetter];
              
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
                                    : Colors.white.withValues(alpha: 0.3),
                        width: isSelected || showCorrect || showIncorrect ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: showCorrect 
                          ? Colors.green.withValues(alpha: 0.2)
                          : showIncorrect 
                              ? Colors.red.withValues(alpha: 0.2)
                              : isSelected 
                                  ? const Color(0xFFD62828) // Uriel red for selected
                                  : Colors.white.withValues(alpha: 0.9), // White with slight transparency
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                              ? Colors.white 
                                              : Colors.grey[400]!,
                                  width: 2,
                                ),
                                color: isSelected || showCorrect 
                                    ? (showCorrect ? Colors.green : Colors.white)
                                    : Colors.white,
                              ),
                              child: isSelected || showCorrect 
                                  ? Icon(
                                      showCorrect ? Icons.check : Icons.circle,
                                      size: 12,
                                      color: showCorrect ? Colors.white : const Color(0xFFD62828),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option,
                                style: GoogleFonts.montserrat(
                                  fontSize: isMobile ? 14 : 16,
                                  color: isSelected ? Colors.white : const Color(0xFF1A1E3F), // White text when selected
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
                        // Option image (if present)
                        if (optionImageUrl != null && optionImageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  insetPadding: const EdgeInsets.all(12),
                                  child: InteractiveViewer(
                                    child: _buildQuestionImageWidget(optionImageUrl),
                                  ),
                                ),
                              );
                            },
                            child: SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildQuestionImageWidget(optionImageUrl),
                              ),
                            ),
                          ),
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
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
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
    ),
      ],
    );
  }

  /// Build question text with underline support
  /// Parses <u>text</u> markers and displays underlined text
  Widget _buildQuestionText(String questionText, bool isMobile) {
    // Check if the text contains underline markers
    if (!questionText.contains('<u>') && !questionText.contains('</u>')) {
      // No underlines, return simple Text widget
      return Text(
        questionText,
        style: GoogleFonts.playfairDisplay(
          fontSize: isMobile ? 18 : 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        ),
      );
    }

    // Parse the text and create TextSpans with underlines
    final List<TextSpan> spans = [];
    final RegExp underlineRegex = RegExp(r'<u>(.*?)</u>');
    int lastIndex = 0;

    for (final match in underlineRegex.allMatches(questionText)) {
      // Add text before the underlined part
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: questionText.substring(lastIndex, match.start),
        ));
      }

      // Add the underlined text
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
          decorationThickness: 2,
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text after the last underlined part
    if (lastIndex < questionText.length) {
      spans.add(TextSpan(
        text: questionText.substring(lastIndex),
      ));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.playfairDisplay(
          fontSize: isMobile ? 18 : 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }

  // Helper methods to map string display names to enums
  Subject _mapStringToSubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'trivia':
        return Subject.trivia;
      case 'religious and moral education':
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
      case 'information technology':
      case 'ict':
        return Subject.ict;
      case 'creative arts':
        return Subject.creativeArts;
      case 'french':
        return Subject.french;
      case 'twi':
      case 'asante twi':
        return Subject.asanteTwi;
      case 'ga':
        return Subject.ga;
      case 'ewe':
        return Subject.religiousMoralEducation; // Fallback for Ewe
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
      case 'mock exam':
      case 'mock':
        return ExamType.mock;
      case 'class test':
      case 'assignment':
      case 'practice questions':
      case 'practice':
        return ExamType.practice;
      default:
        return ExamType.bece;
    }
  }
}
