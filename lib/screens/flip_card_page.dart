import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';

class FlipCardPage extends StatefulWidget {
  final String subject;
  final String examType;
  final List<Question> questions;

  const FlipCardPage({
    Key? key,
    required this.subject,
    required this.examType,
    required this.questions,
  }) : super(key: key);

  @override
  State<FlipCardPage> createState() => _FlipCardPageState();
}

class _FlipCardPageState extends State<FlipCardPage> with TickerProviderStateMixin {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  bool _showAnswer = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    // Questions are passed directly, no need to load them
    _questions = widget.questions;
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_showAnswer) {
      _flipController.reverse().then((_) {
        setState(() => _showAnswer = false);
      });
    } else {
      setState(() => _showAnswer = true);
      _flipController.forward();
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      // Reset flip state
      if (_showAnswer) {
        _flipController.reverse().then((_) {
          setState(() {
            _showAnswer = false;
            _currentQuestionIndex++;
          });
        });
      } else {
        setState(() => _currentQuestionIndex++);
      }
    } else {
      // Quiz completed
      _showCompletionDialog();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      // Reset flip state
      if (_showAnswer) {
        _flipController.reverse().then((_) {
          setState(() {
            _showAnswer = false;
            _currentQuestionIndex--;
          });
        });
      } else {
        setState(() => _currentQuestionIndex--);
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Flip Card Session Complete!',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        content: Text(
          'You\'ve reviewed all ${_questions.length} questions. Great job!',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to revision page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
            ),
            child: Text('Back to Revision', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1E3F)),
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
                  Icons.flip_camera_android_outlined,
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
                  'No questions available for ${widget.examType} ${widget.subject}.\nPlease try different selections.',
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
                  child: Text('Back to Revision', style: GoogleFonts.montserrat()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1E3F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.subject} Flip Cards',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD62828).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${(_currentQuestionIndex + 1)}/${_questions.length}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD62828),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
                minHeight: 6,
              ),
            ),

            // Flip card content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 600,
                    ),
                    child: GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          final isFlipped = _flipAnimation.value > 0.5;
                          return Transform(
                            transform: Matrix4.rotationY(_flipAnimation.value * 3.14159),
                            alignment: Alignment.center,
                            child: Container(
                              width: double.infinity,
                              height: isMobile ? 400 : 500,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Transform(
                                transform: Matrix4.rotationY(isFlipped ? 3.14159 : 0),
                                alignment: Alignment.center,
                                child: isFlipped ? _buildAnswerCard(currentQuestion, isMobile) : _buildQuestionCard(currentQuestion, isMobile),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
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
              child: Column(
                children: [
                  // Flip instruction
                  Text(
                    _showAnswer ? 'Tap to see question' : 'Tap card to reveal answer',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Navigation buttons
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _previousQuestion,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A1E3F),
                              side: const BorderSide(color: Color(0xFF1A1E3F)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        const Spacer(),
                      ],

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _nextQuestion,
                          icon: Icon(
                            _currentQuestionIndex == _questions.length - 1
                                ? Icons.check
                                : Icons.arrow_forward,
                          ),
                          label: Text(
                            _currentQuestionIndex == _questions.length - 1
                                ? 'Finish'
                                : 'Next',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD62828),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Question number badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD62828).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Question ${question.questionNumber}',
              style: GoogleFonts.montserrat(
                color: const Color(0xFFD62828),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),

          // Question content
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                question.questionText,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 16 : 18,
                  color: const Color(0xFF1A1E3F),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tap instruction
          Text(
            'Tap to reveal answer',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(Question question, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Answer icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF2ECC71),
              size: 32,
            ),
          ),
          const SizedBox(height: 24),

          // Answer text
          Text(
            'Answer',
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),

          // Correct answer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              question.correctAnswer,
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2ECC71),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Explanation (if available)
          if (question.explanation?.isNotEmpty == true) ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Explanation',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.explanation!,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Tap instruction
          Text(
            'Tap to see next question',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
