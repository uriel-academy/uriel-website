import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz_model.dart';
import 'home_page.dart';

class QuizResultsPage extends StatefulWidget {
  final Quiz quiz;

  const QuizResultsPage({
    super.key,
    required this.quiz,
  });

  @override
  State<QuizResultsPage> createState() => _QuizResultsPageState();
}

class _QuizResultsPageState extends State<QuizResultsPage>
    with TickerProviderStateMixin {
  late AnimationController _scoreAnimationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _slideAnimation;

  bool showDetailedReview = false;

  @override
  void initState() {
    super.initState();
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scoreAnimation = Tween<double>(begin: 0.0, end: widget.quiz.percentage).animate(
      CurvedAnimation(parent: _scoreAnimationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardAnimationController, curve: Curves.easeOutBack),
    );

    _startAnimations();
    _saveQuizResult();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _scoreAnimationController.forward();
    _cardAnimationController.forward();
  }

  Future<void> _saveQuizResult() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Save quiz result to Firestore
      await FirebaseFirestore.instance.collection('quizzes').add({
        'userId': user.uid,
        'subject': widget.quiz.subject,
        'examType': widget.quiz.examType,
        'quizType': widget.quiz.examType, // For filtering (trivia, bece, etc.)
        'level': widget.quiz.level,
        'totalQuestions': widget.quiz.totalQuestions,
        'correctAnswers': widget.quiz.correctAnswers,
        'percentage': widget.quiz.percentage,
        'duration': widget.quiz.duration.inSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'triviaCategory': widget.quiz.triviaCategory,
      });

      print('Quiz result saved successfully');
    } catch (e) {
      print('Error saving quiz result: $e');
      // Don't show error to user, just log it
    }
  }

  @override
  void dispose() {
    _scoreAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  String _getGradeLetter() {
    final percentage = widget.quiz.percentage;
    if (percentage >= 90) return 'A+';
    if (percentage >= 85) return 'A';
    if (percentage >= 80) return 'A-';
    if (percentage >= 75) return 'B+';
    if (percentage >= 70) return 'B';
    if (percentage >= 65) return 'B-';
    if (percentage >= 60) return 'C+';
    if (percentage >= 55) return 'C';
    if (percentage >= 50) return 'C-';
    if (percentage >= 45) return 'D+';
    if (percentage >= 40) return 'D';
    return 'F';
  }

  Color _getGradeColor() {
    final percentage = widget.quiz.percentage;
    if (percentage >= 80) return Colors.green;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 60) return Colors.amber;
    return Colors.red;
  }

  String _getPerformanceMessage() {
    final percentage = widget.quiz.percentage;
    if (percentage >= 90) return 'Outstanding! Exceptional performance!';
    if (percentage >= 80) return 'Excellent work! Keep it up!';
    if (percentage >= 70) return 'Good job! Room for improvement.';
    if (percentage >= 60) return 'Fair performance. More practice needed.';
    return 'Keep studying. You can do better!';
  }

  void _shareResults() {
    final message = '''
🎓 Quiz Results - ${widget.quiz.subject}

📊 Score: ${widget.quiz.correctAnswers}/${widget.quiz.totalQuestions} (${widget.quiz.percentage.toStringAsFixed(1)}%)
🎯 Grade: ${_getGradeLetter()}
⏱️ Time: ${widget.quiz.duration.inMinutes}m ${widget.quiz.duration.inSeconds % 60}s

${_getPerformanceMessage()}

#UrielAcademy #Quiz #${widget.quiz.subject.replaceAll(' ', '')}
    ''';

    Share.share(message);
  }

  void _retakeQuiz() {
    // After quiz completion, return to home page instead of quiz setup
    _backToHome();
  }

  void _backToHome() {
    // Navigate to home page, clearing all quiz-related pages from the stack
    // First try to use named route, if that fails, use direct navigation
    try {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      // Fallback: Direct navigation to StudentHomePage
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const StudentHomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1E3F),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _backToHome,
              ),
              title: Text(
                'Quiz Results',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareResults,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8FAFE)],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  children: [
                    // Score Card
                    AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 100),
                          child: _buildScoreCard(isMobile),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Stats Cards
                    AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 150),
                          child: _buildStatsCards(isMobile),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 200),
                          child: _buildActionButtons(isMobile),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Review Toggle
                    AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 250),
                          child: _buildReviewToggle(),
                        );
                      },
                    ),

                    // Detailed Review
                    if (showDetailedReview) ...[
                      const SizedBox(height: 24),
                      _buildDetailedReview(isMobile),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(bool isMobile) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getGradeColor().withOpacity(0.1),
              _getGradeColor().withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // Circular Score Display
            SizedBox(
              width: isMobile ? 160 : 200,
              height: isMobile ? 160 : 200,
              child: Stack(
                children: [
                  // Background circle
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[200]!,
                      ),
                    ),
                  ),
                  // Animated progress circle
                  SizedBox.expand(
                    child: AnimatedBuilder(
                      animation: _scoreAnimation,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _scoreAnimation.value / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getGradeColor(),
                          ),
                        );
                      },
                    ),
                  ),
                  // Score text
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _scoreAnimation,
                          builder: (context, child) {
                            return Text(
                              '${_scoreAnimation.value.round()}%',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: isMobile ? 28 : 36,
                                fontWeight: FontWeight.bold,
                                color: _getGradeColor(),
                              ),
                            );
                          },
                        ),
                        Text(
                          _getGradeLetter(),
                          style: GoogleFonts.montserrat(
                            fontSize: isMobile ? 16 : 20,
                            fontWeight: FontWeight.w600,
                            color: _getGradeColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Performance message
            Text(
              _getPerformanceMessage(),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),

            const SizedBox(height: 16),

            // Score details
            Text(
              '${widget.quiz.correctAnswers} out of ${widget.quiz.totalQuestions} correct',
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

  Widget _buildStatsCards(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Time Taken',
            '${widget.quiz.duration.inMinutes}m ${widget.quiz.duration.inSeconds % 60}s',
            Icons.timer,
            Colors.blue,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Accuracy',
            '${widget.quiz.percentage.toStringAsFixed(1)}%',
            Icons.track_changes,
            Colors.orange,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _retakeQuiz,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake Quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 32,
                vertical: isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _backToHome,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1E3F),
              side: const BorderSide(color: Color(0xFF1A1E3F)),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 32,
                vertical: isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewToggle() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          setState(() {
            showDetailedReview = !showDetailedReview;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                showDetailedReview ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFFD62828),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  showDetailedReview ? 'Hide Answer Review' : 'Show Answer Review',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ),
              Icon(
                showDetailedReview ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedReview(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Answer Review',
          style: GoogleFonts.playfairDisplay(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 16),
        ...widget.quiz.answers.asMap().entries.map((entry) {
          final index = entry.key;
          final answer = entry.value;
          return _buildReviewCard(index + 1, answer, isMobile);
        }).toList(),
      ],
    );
  }

  Widget _buildReviewCard(int questionNumber, QuizAnswer answer, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: answer.isCorrect ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Question $questionNumber',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: answer.isCorrect 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        answer.isCorrect ? Icons.check : Icons.close,
                        size: 16,
                        color: answer.isCorrect ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        answer.isCorrect ? 'Correct' : 'Incorrect',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: answer.isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Question text
            Text(
              answer.questionText,
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 14 : 16,
                color: const Color(0xFF1A1E3F),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            // User's answer
            if (answer.userAnswer.isNotEmpty) ...[
              _buildAnswerOption(
                'Your Answer',
                answer.userAnswer,
                answer.isCorrect ? Colors.green : Colors.red,
                answer.isCorrect ? Icons.check_circle : Icons.cancel,
              ),
              const SizedBox(height: 8),
            ],

            // Correct answer (if user was wrong)
            if (!answer.isCorrect) ...[
              _buildAnswerOption(
                'Correct Answer',
                answer.correctAnswer,
                Colors.green,
                Icons.check_circle,
              ),
            ],

            // Explanation
            if (answer.explanation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Explanation',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      answer.explanation,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
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

  Widget _buildAnswerOption(String label, String answer, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              answer,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: const Color(0xFF1A1E3F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
