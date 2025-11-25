import 'package:flutter/material.dart';
import 'package:uriel_mainapp/services/english_textbook_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class EnglishTextbookReaderPage extends StatefulWidget {
  final String year;
  final String? textbookId;

  const EnglishTextbookReaderPage({
    super.key,
    required this.year,
    this.textbookId,
  });

  @override
  State<EnglishTextbookReaderPage> createState() => _EnglishTextbookReaderPageState();
}

class _EnglishTextbookReaderPageState extends State<EnglishTextbookReaderPage> with SingleTickerProviderStateMixin {
  final _service = EnglishTextbookService();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = true;
  Map<String, dynamic>? _textbook;
  List<Map<String, dynamic>> _chapters = [];
  List<Map<String, dynamic>> _sections = [];
  Map<String, dynamic>? _currentSection;
  List<Map<String, dynamic>> _currentQuestions = [];
  Map<String, dynamic> _userProgress = {};
  
  int _currentChapterIndex = 0;
  int _currentSectionIndex = 0;
  bool _showingQuestions = false;
  bool _showFAB = true;
  final Map<String, String> _selectedAnswers = {};
  final Map<String, bool> _submittedAnswers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTextbook();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Hide FAB when scrolling down, show when scrolling up
    if (_scrollController.position.userScrollDirection.toString().contains('forward')) {
      if (!_showFAB) setState(() => _showFAB = true);
    } else if (_scrollController.position.userScrollDirection.toString().contains('reverse')) {
      if (_showFAB) setState(() => _showFAB = false);
    }
  }

  Future<void> _loadTextbook() async {
    setState(() => _isLoading = true);

    try {
      // Get or use provided textbook ID
      String? bookId = widget.textbookId;
      
      if (bookId == null) {
        final textbook = await _service.getTextbook(widget.year);
        if (textbook == null) {
          _showError('No textbook found for ${widget.year}');
          return;
        }
        bookId = textbook['id'];
        _textbook = textbook;
      } else {
        _textbook = {'id': bookId};
      }

      // Ensure bookId is not null
      if (bookId == null) {
        _showError('Textbook ID is required');
        return;
      }

      // Load chapters and sections
      _chapters = await _service.getChapters(bookId);
      _sections = await _service.getSections(bookId);
      _userProgress = await _service.getUserProgress(bookId);

      // Load first section
      if (_sections.isNotEmpty) {
        await _loadSection(0);
      }
    } catch (e) {
      _showError('Error loading textbook: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSection(int index) async {
    if (index < 0 || index >= _sections.length) return;

    setState(() {
      _isLoading = true;
      _currentSectionIndex = index;
      _showingQuestions = false;
      _selectedAnswers.clear();
      _submittedAnswers.clear();
    });

    try {
      final section = _sections[index];
      _currentSection = section;
      _currentChapterIndex = section['chapterIndex'] ?? 0;

      // Load section questions from section data (already in JSON)
      if (section.containsKey('questions') && section['questions'] is List) {
        _currentQuestions = (section['questions'] as List)
            .map((q) => q as Map<String, dynamic>)
            .toList();
      } else {
        // Fallback to Firestore if questions not in section
        _currentQuestions = await _service.getSectionQuestions(
          _textbook!['id'],
          section['id'],
        );
      }
    } catch (e) {
      _showError('Error loading section: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAnswer(String questionId, String correctAnswer, int xpValue) async {
    final selected = _selectedAnswers[questionId];
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an answer')),
      );
      return;
    }

    final result = await _service.submitAnswer(
      textbookId: _textbook!['id'],
      questionId: questionId,
      selectedAnswer: selected,
      correctAnswer: correctAnswer,
      xpValue: xpValue,
      questionType: 'section',
    );

    setState(() {
      _submittedAnswers[questionId] = result['isCorrect'];
    });

    if (result['isCorrect']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Correct! +${result['xpEarned']} XP'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Incorrect. Try again!'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Reload progress
    _userProgress = await _service.getUserProgress(_textbook!['id']);
    setState(() {});
  }

  Future<void> _completeSection() async {
    // Check if all questions answered correctly
    final allCorrect = _submittedAnswers.values.every((correct) => correct);
    
    if (!allCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions correctly to complete this section'),
        ),
      );
      return;
    }

    final result = await _service.completionSection(
      textbookId: _textbook!['id'],
      sectionId: _currentSection!['id'],
      xpReward: _currentSection!['xpReward'] ?? 50,
    );

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Section Complete! +${result['xpEarned']} XP'),
          backgroundColor: Colors.green,
        ),
      );

      // Move to next section
      if (_currentSectionIndex < _sections.length - 1) {
        await _loadSection(_currentSectionIndex + 1);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
            ))
          : isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      floatingActionButton: isMobile && _showFAB && !_isLoading
          ? _buildFloatingActionButton()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1E3F),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'English ${widget.year}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isMobile && _currentSection != null)
            Text(
              _currentSection!['title'] ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),
        ],
      ),
      actions: [
        if (!isMobile)
          TextButton.icon(
            onPressed: _showTableOfContents,
            icon: const Icon(Icons.menu_book, size: 18),
            label: const Text('Contents'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD62828),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD62828).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.stars,
                size: 18,
                color: Color(0xFFD62828),
              ),
              const SizedBox(width: 6),
              Text(
                '${_userProgress['totalXP'] ?? 0} XP',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD62828),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showTableOfContents,
      backgroundColor: const Color(0xFF2ECC71),
      icon: const Icon(Icons.menu_book),
      label: const Text('Contents'),
    );
  }

  void _showTableOfContents() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Table of Contents',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _buildTableOfContentsList(scrollController),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            height: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Table of Contents',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _buildTableOfContentsList(null),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMobileLayout() {
    return _currentSection == null
        ? _buildEmptyState()
        : CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSectionHeader(true),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: _showingQuestions
                      ? _buildQuestionsView(true)
                      : _buildContentView(true),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildBottomNavigation(true),
              ),
            ],
          );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar for desktop
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Table of Contents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _buildTableOfContentsList(null),
              ),
            ],
          ),
        ),
        
        // Main content area
        Expanded(
          child: _currentSection == null
              ? _buildEmptyState()
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    _buildSectionHeader(false),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 40,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _showingQuestions
                              ? _buildQuestionsView(false)
                              : _buildContentView(false),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildBottomNavigation(false),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Select a section to begin',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showTableOfContents,
            icon: const Icon(Icons.list),
            label: const Text('Browse Contents'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isMobile) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentSection!['title'] ?? '',
              style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: Icons.book_outlined,
                  label: 'Section ${_currentSection!['sectionNumber']}',
                  color: Colors.blue,
                ),
                _buildInfoChip(
                  icon: Icons.access_time,
                  label: '${_currentSection!['estimatedReadingTime']} min',
                  color: Colors.green,
                ),
                _buildInfoChip(
                  icon: Icons.stars,
                  label: '+${_currentSection!['xpReward']} XP',
                  color: Colors.orange,
                ),
                if ((_userProgress['completedSections'] ?? [])
                    .contains(_currentSection!['id']))
                  _buildInfoChip(
                    icon: Icons.check_circle,
                    label: 'Completed',
                    color: Colors.teal,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableOfContentsList(ScrollController? scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _buildChapterList(),
    );
  }

  List<Widget> _buildChapterList() {
    final widgets = <Widget>[];
    
    for (var i = 0; i < _chapters.length; i++) {
      final chapter = _chapters[i];
      final chapterSections = _sections
          .where((s) => s['chapterIndex'] == i)
          .toList();

      widgets.add(
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _currentChapterIndex == i
                    ? const Color(0xFFD62828).withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.book,
                size: 20,
                color: _currentChapterIndex == i
                    ? const Color(0xFFD62828)
                    : Colors.grey[600],
              ),
            ),
            title: Text(
              'Chapter ${i + 1}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: _currentChapterIndex == i
                    ? FontWeight.bold
                    : FontWeight.w600,
                color: _currentChapterIndex == i
                    ? const Color(0xFFD62828)
                    : Colors.black87,
              ),
            ),
            subtitle: Text(
              chapter['title'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            initiallyExpanded: _currentChapterIndex == i,
            children: chapterSections.map((section) {
              final sectionIndex = _sections.indexOf(section);
              final isCompleted = (_userProgress['completedSections'] ?? [])
                  .contains(section['id']);
              final isCurrent = sectionIndex == _currentSectionIndex;

              return InkWell(
                onTap: () {
                  _loadSection(sectionIndex);
                  if (MediaQuery.of(context).size.width < 768) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFFD62828).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: isCompleted
                            ? Colors.green
                            : Colors.grey[400],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section['title'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isCurrent
                                ? const Color(0xFFD62828)
                                : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    // Add Year-End Assessment button at the end
    widgets.add(
      Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () => _loadYearEndAssessment(),
          icon: const Icon(Icons.assessment, color: Colors.white),
          label: const Text('Year-End Assessment (40 Questions)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD62828),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );

    return widgets;
  }

  Future<void> _loadYearEndAssessment() async {
    setState(() {
      _isLoading = true;
      _showingQuestions = true;
      _currentSection = {
        'title': 'Year-End Assessment',
        'content': '# Year-End Assessment\n\nComplete this comprehensive 40-question assessment to test your understanding of all chapters.',
      };
      _selectedAnswers.clear();
      _submittedAnswers.clear();
    });

    try {
      // Load year-end questions from the textbook data
      if (_textbook != null) {
        final textbookData = await _service.getTextbook(widget.year);
        if (textbookData != null && textbookData.containsKey('yearEndQuestions')) {
          _currentQuestions = (textbookData['yearEndQuestions'] as List)
              .map((q) => q as Map<String, dynamic>)
              .toList();
        } else {
          // Fallback to Firestore
          _currentQuestions = await _service.getYearEndQuestions(_textbook!['id']);
        }
      }
    } catch (e) {
      _showError('Error loading year-end assessment: $e');
    } finally {
      setState(() => _isLoading = false);
    }
    
    // Close TOC on mobile
    if (MediaQuery.of(context).size.width < 768) {
      Navigator.pop(context);
    }
  }

  Widget _buildContentView(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownBody(
          data: _currentSection!['content'] ?? '',
          styleSheet: MarkdownStyleSheet(
            h1: TextStyle(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
              height: 1.3,
            ),
            h2: TextStyle(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
              height: 1.3,
            ),
            h3: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1E3F),
              height: 1.3,
            ),
            p: TextStyle(
              fontSize: isMobile ? 16 : 18,
              height: 1.7,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
            listBullet: TextStyle(
              fontSize: isMobile ? 16 : 18,
              height: 1.7,
            ),
            code: TextStyle(
              fontSize: isMobile ? 14 : 16,
              backgroundColor: Colors.grey[100],
              fontFamily: 'monospace',
            ),
            blockquote: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
            ),
            blockquotePadding: const EdgeInsets.all(16),
            blockquoteDecoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: Colors.blue[300]!,
                  width: 4,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        if (_currentQuestions.isNotEmpty)
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD62828).withOpacity(0.1),
                  const Color(0xFFD62828).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFD62828).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD62828),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.quiz,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ready to Test Your Knowledge?',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1E3F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_currentQuestions.length} questions • Earn up to ${_currentQuestions.fold<int>(0, (sum, q) => sum + (q['xpValue'] as int))} XP',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _showingQuestions = true);
                    if (isMobile) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Take Section Quiz',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: isMobile ? 80 : 40),
      ],
    );
  }

  Widget _buildQuestionsView(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue[50]!,
                Colors.blue[100]!,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Section Quiz',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentQuestions.length} questions',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _showingQuestions = false);
                  if (isMobile) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                icon: const Icon(Icons.article, size: 18),
                label: const Text('Content'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ..._currentQuestions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(index, question, isMobile);
        }),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _completeSection,
          icon: const Icon(Icons.check_circle),
          label: const Text('Complete Section'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 14 : 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        SizedBox(height: isMobile ? 80 : 40),
      ],
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question, bool isMobile) {
    final questionId = question['id'];
    final isSubmitted = _submittedAnswers.containsKey(questionId);
    final isCorrect = _submittedAnswers[questionId] ?? false;

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD62828), Color(0xFFB71C1C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${question['xpValue']} XP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSubmitted) ...[
                  const SizedBox(width: 8),
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text(
              question['questionText'] ?? '',
              style: TextStyle(
                fontSize: isMobile ? 15 : 17,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 20),
            ...['A', 'B', 'C', 'D'].map((option) {
              final optionText = question['options'][option] ?? '';
              final isSelected = _selectedAnswers[questionId] == option;
              final showCorrect = isSubmitted && question['correctAnswer'] == option;
              final showWrong = isSubmitted && isSelected && !isCorrect;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: showCorrect
                      ? Colors.green[50]
                      : showWrong
                          ? Colors.red[50]
                          : isSelected
                              ? const Color(0xFFD62828).withOpacity(0.1)
                              : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showCorrect
                        ? Colors.green
                        : showWrong
                            ? Colors.red
                            : isSelected
                                ? const Color(0xFFD62828)
                                : Colors.grey[300]!,
                    width: showCorrect || showWrong ? 2 : 1,
                  ),
                ),
                child: RadioListTile<String>(
                  title: Text(
                    '$option. $optionText',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: showCorrect || showWrong
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: showCorrect
                          ? Colors.green[900]
                          : showWrong
                              ? Colors.red[900]
                              : Colors.black87,
                    ),
                  ),
                  value: option,
                  groupValue: _selectedAnswers[questionId],
                  onChanged: isSubmitted
                      ? null
                      : (value) {
                          setState(() {
                            _selectedAnswers[questionId] = value!;
                          });
                        },
                  activeColor: const Color(0xFFD62828),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              );
            }),
            if (!isSubmitted && _selectedAnswers.containsKey(questionId)) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _submitAnswer(
                    questionId,
                    question['correctAnswer'],
                    question['xpValue'],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 12 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit Answer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (isSubmitted) ...[
              const SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 16),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCorrect ? Colors.green[300]! : Colors.red[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.error,
                          color: isCorrect ? Colors.green[700] : Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCorrect ? 'Correct!' : 'Incorrect',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 15 : 16,
                            color: isCorrect ? Colors.green[900] : Colors.red[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      question['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        height: 1.5,
                        color: isCorrect ? Colors.green[900] : Colors.red[900],
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

  Widget _buildBottomNavigation(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentSectionIndex > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _loadSection(_currentSectionIndex - 1),
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  label: Text(
                    isMobile ? 'Previous' : 'Previous Section',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1E3F),
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 20,
                      vertical: isMobile ? 10 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentSectionIndex + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD62828),
                    ),
                  ),
                  Text(
                    'of ${_sections.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (_currentSectionIndex < _sections.length - 1)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _loadSection(_currentSectionIndex + 1),
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  label: Text(
                    isMobile ? 'Next' : 'Next Section',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 20,
                      vertical: isMobile ? 10 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}
