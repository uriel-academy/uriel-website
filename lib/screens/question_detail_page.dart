import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import 'quiz_setup_page.dart';

class QuestionDetailPage extends StatefulWidget {
  final Question question;

  const QuestionDetailPage({Key? key, required this.question}) : super(key: key);

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  String? selectedAnswer;
  bool showAnswer = false;

  Color _getSubjectColor(Subject subject) {
    switch (subject) {
      case Subject.religiousMoralEducation:
        return const Color(0xFF8E24AA);
      case Subject.mathematics:
        return const Color(0xFF1976D2);
      case Subject.english:
        return const Color(0xFF388E3C);
      case Subject.integratedScience:
        return const Color(0xFFD32F2F);
      case Subject.socialStudies:
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF455A64);
    }
  }

  Widget _buildDifficultyBadge(String difficulty) {
    int difficultyLevel;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        difficultyLevel = 2;
        break;
      case 'medium':
        difficultyLevel = 3;
        break;
      case 'hard':
        difficultyLevel = 4;
        break;
      default:
        difficultyLevel = 3;
    }
    
    final stars = '★' * difficultyLevel + '☆' * (5 - difficultyLevel);
    Color color;
    
    if (difficultyLevel <= 2) {
      color = Colors.green;
    } else if (difficultyLevel <= 3) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        stars,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _startQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizSetupPage(
          preselectedSubject: widget.question.subject.name,
          preselectedExamType: widget.question.examType.name,
          preselectedLevel: 'JHS 3',
        ),
      ),
    );
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
              expandedHeight: 100,
              pinned: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1E3F),
              elevation: 0,
              title: Text(
                'Question Details',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.quiz),
                  onPressed: _startQuiz,
                  tooltip: 'Start Quiz',
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Header
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getSubjectColor(widget.question.subject),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${widget.question.questionNumber}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
                                        widget.question.subject.name,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: isMobile ? 16 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1A1E3F),
                                        ),
                                      ),
                                      Text(
                                        '${widget.question.examType.name.toUpperCase()} ${widget.question.year}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    widget.question.type.name,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Level: JHS',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                                _buildDifficultyBadge(widget.question.difficulty),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Question Content
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1E3F),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.question.questionText,
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 14 : 16,
                                color: const Color(0xFF1A1E3F),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Options
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Options',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1E3F),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (widget.question.options != null) 
                              ...widget.question.options!.map((option) {
                              final isSelected = selectedAnswer == option;
                              final isCorrect = showAnswer && option == widget.question.correctAnswer;
                              final isIncorrect = showAnswer && isSelected && option != widget.question.correctAnswer;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: showAnswer ? null : () {
                                    setState(() {
                                      selectedAnswer = option;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isCorrect 
                                            ? Colors.green 
                                            : isIncorrect 
                                                ? Colors.red
                                                : isSelected 
                                                    ? const Color(0xFFD62828) 
                                                    : Colors.grey[300]!,
                                        width: isSelected || isCorrect || isIncorrect ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      color: isCorrect 
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : isIncorrect 
                                              ? Colors.red.withValues(alpha: 0.1)
                                              : isSelected 
                                                  ? const Color(0xFFD62828).withValues(alpha: 0.1) 
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
                                              color: isCorrect 
                                                  ? Colors.green 
                                                  : isIncorrect 
                                                      ? Colors.red
                                                      : isSelected 
                                                          ? const Color(0xFFD62828) 
                                                          : Colors.grey[400]!,
                                              width: 2,
                                            ),
                                            color: isSelected || isCorrect 
                                                ? (isCorrect ? Colors.green : const Color(0xFFD62828))
                                                : Colors.white,
                                          ),
                                          child: isSelected || isCorrect 
                                              ? Icon(
                                                  isCorrect ? Icons.check : Icons.circle,
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
                                        if (isCorrect) ...[
                                          const Icon(Icons.check_circle, color: Colors.green),
                                        ] else if (isIncorrect) ...[
                                          const Icon(Icons.cancel, color: Colors.red),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Column(
                      children: [
                        if (!showAnswer) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: selectedAnswer != null ? () {
                                setState(() {
                                  showAnswer = true;
                                });
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedAnswer != null 
                                    ? const Color(0xFFD62828) 
                                    : Colors.grey[400],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 14 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Show Answer',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 12),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startQuiz,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              'Start Quiz on ${widget.question.subject}',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 14 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        if (showAnswer && widget.question.explanation?.isNotEmpty == true) ...[
                          const SizedBox(height: 24),
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 16 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.lightbulb, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Explanation',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: isMobile ? 16 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.question.explanation!,
                                    style: GoogleFonts.montserrat(
                                      fontSize: isMobile ? 14 : 16,
                                      color: const Color(0xFF1A1E3F),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
