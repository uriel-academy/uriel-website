import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/course_models.dart';
import '../services/course_reader_service.dart';

/// Apple-inspired Lesson Reader Page
class LessonReaderPage extends StatefulWidget {
  final Course course;
  final CourseUnit unit;
  final Lesson lesson;

  const LessonReaderPage({
    super.key,
    required this.course,
    required this.unit,
    required this.lesson,
  });

  @override
  State<LessonReaderPage> createState() => _LessonReaderPageState();
}

class _LessonReaderPageState extends State<LessonReaderPage> {
  final CourseReaderService _service = CourseReaderService();
  final ScrollController _scrollController = ScrollController();
  
  // ignore: unused_field
  bool _loading = true;
  LessonProgress? _progress;
  final Map<String, int> _quizAnswers = {}; // question index -> selected answer
  bool _showVocabulary = false;
  double _readProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _scrollController.addListener(_updateReadProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateReadProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateReadProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _readProgress = maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0.0;
      });
    }
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    final progress = await _service.getLessonProgress(
      widget.course.courseId,
      widget.unit.unitId,
      widget.lesson.lessonId,
    );
    setState(() {
      _progress = progress;
      _loading = false;
    });
  }

  Future<void> _completeLesson() async {
    // Calculate quiz score
    int correctAnswers = 0;
    int totalQuestions = 0;

    if (widget.lesson.interactive?.quickCheck != null) {
      totalQuestions = widget.lesson.interactive!.quickCheck!.length;
      for (int i = 0; i < totalQuestions; i++) {
        final question = widget.lesson.interactive!.quickCheck![i];
        if (_quizAnswers[i.toString()] == question.answerIndex) {
          correctAnswers++;
        }
      }
    }

    final quizScore = totalQuestions > 0 ? (correctAnswers / totalQuestions * 100).round() : 100;

    await _service.updateLessonProgress(
      courseId: widget.course.courseId,
      unitId: widget.unit.unitId,
      lessonId: widget.lesson.lessonId,
      completed: true,
      xpEarned: widget.lesson.xpReward,
      quizScore: quizScore,
    );

    if (mounted) {
      _showCompletionDialog(quizScore);
    }
  }

  void _showCompletionDialog(int quizScore) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 32),
            const SizedBox(width: 12),
            Text(
              'Lesson Complete!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations! You\'ve completed "${widget.lesson.title}"',
              style: GoogleFonts.inter(fontSize: 15),
            ),
            const SizedBox(height: 16),
            _buildStatRow(Icons.star, 'XP Earned', '+${widget.lesson.xpReward}'),
            if (widget.lesson.interactive?.quickCheck != null)
              _buildStatRow(Icons.quiz, 'Quiz Score', '$quizScore%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close lesson
            },
            child: Text(
              'Done',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF8E8E93)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF8E8E93),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final contentWidth = isSmallScreen ? screenWidth : (screenWidth * 0.7).clamp(600.0, 800.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App Bar with Progress
              SliverAppBar(
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1C1C1E)),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lesson.title,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    Text(
                      widget.unit.title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Vocabulary Toggle
                  if (widget.lesson.vocabulary.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.book_outlined,
                        color: _showVocabulary ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
                      ),
                      onPressed: () => setState(() => _showVocabulary = !_showVocabulary),
                    ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: _readProgress,
                    backgroundColor: const Color(0xFFE5E5EA),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                    minHeight: 4,
                  ),
                ),
              ),

              // Lesson Content
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    width: contentWidth,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : 32,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lesson Header
                        _buildLessonHeader(),
                        const SizedBox(height: 32),

                        // Vocabulary Panel (if shown)
                        if (_showVocabulary) ...[
                          _buildVocabularyPanel(),
                          const SizedBox(height: 24),
                        ],

                        // Objectives
                        if (widget.lesson.objectives.isNotEmpty) ...[
                          _buildObjectives(),
                          const SizedBox(height: 32),
                        ],

                        // Content Blocks
                        ...widget.lesson.contentBlocks.map((block) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildContentBlock(block),
                          );
                        }),

                        // Interactive Elements
                        if (widget.lesson.interactive != null) ...[
                          const SizedBox(height: 16),
                          _buildInteractive(widget.lesson.interactive!),
                        ],

                        // Moral Link
                        if (widget.lesson.moralLink != null) ...[
                          const SizedBox(height: 24),
                          _buildMoralLink(),
                        ],

                        // Complete Button
                        const SizedBox(height: 32),
                        _buildCompleteButton(),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book,
              color: Color(0xFF007AFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lesson.title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.lesson.estimatedTimeMin} min',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.star, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.lesson.xpReward} XP',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.book, color: Color(0xFF007AFF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Key Vocabulary',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.lesson.vocabulary.map((vocab) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vocab.word,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vocab.definition,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF1C1C1E),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildObjectives() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Objectives',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.lesson.objectives.map((objective) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      objective,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF1C1C1E),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContentBlock(ContentBlock block) {
    switch (block.type) {
      case 'text':
        return _buildTextBlock(block);
      case 'reading':
        return _buildReadingBlock(block);
      case 'tip':
        return _buildTipBlock(block);
      case 'audio':
        return _buildAudioBlock(block);
      case 'image':
        return _buildImageBlock(block);
      default:
        return _buildTextBlock(block);
    }
  }

  Widget _buildTextBlock(ContentBlock block) {
    return Text(
      block.body ?? '',
      style: GoogleFonts.inter(
        fontSize: 16,
        color: const Color(0xFF1C1C1E),
        height: 1.6,
      ),
    );
  }

  Widget _buildReadingBlock(ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories,
                color: Color(0xFF007AFF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Reading Passage',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            block.body ?? '',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF1C1C1E),
              height: 1.8,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBlock(ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFFFB300), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              block.body ?? '',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF1C1C1E),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBlock(ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Color(0xFF007AFF)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Lesson',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                if (block.caption != null)
                  Text(
                    block.caption!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBlock(ContentBlock block) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            ),
            if (block.caption != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  block.caption!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractive(Interactive interactive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interactive.quickCheck != null && interactive.quickCheck!.isNotEmpty) ...[
          _buildQuickCheck(interactive.quickCheck!),
        ],
        if (interactive.speakingTask != null) ...[
          const SizedBox(height: 24),
          _buildSpeakingTask(interactive.speakingTask!),
        ],
      ],
    );
  }

  Widget _buildQuickCheck(List<QuickCheck> questions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz, color: Color(0xFF007AFF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Check',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            return _buildQuestionCard(index, question);
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, QuickCheck question) {
    final selectedAnswer = _quizAnswers[index.toString()];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${question.question}',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 12),
          ...question.options.asMap().entries.map((optionEntry) {
            final optionIndex = optionEntry.key;
            final option = optionEntry.value;
            final isSelected = selectedAnswer == optionIndex;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _quizAnswers[index.toString()] = optionIndex;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF007AFF).withOpacity(0.1)
                          : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : const Color(0xFFE5E5EA),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF007AFF)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF007AFF)
                                  : const Color(0xFFE5E5EA),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSpeakingTask(SpeakingTask task) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic, color: Color(0xFF007AFF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Speaking Task',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.prompt,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF1C1C1E),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoralLink() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5856D6), Color(0xFF7B79DB)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moral Reflection',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.lesson.moralLink ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton() {
    final isCompleted = _progress?.completed ?? false;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isCompleted ? null : _completeLesson,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          disabledBackgroundColor: const Color(0xFF34C759),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.check,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              isCompleted ? 'Completed' : 'Complete Lesson',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
