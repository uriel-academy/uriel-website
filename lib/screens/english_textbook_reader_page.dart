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

class _EnglishTextbookReaderPageState extends State<EnglishTextbookReaderPage> {
  final _service = EnglishTextbookService();
  
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
  Map<String, String> _selectedAnswers = {};
  Map<String, bool> _submittedAnswers = {};

  @override
  void initState() {
    super.initState();
    _loadTextbook();
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

      // Load section questions
      _currentQuestions = await _service.getSectionQuestions(
        _textbook!['id'],
        section['id'],
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text('English ${widget.year}'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          // Progress indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${_userProgress['totalXP'] ?? 0} XP',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left sidebar: Table of contents
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      right: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: _buildTableOfContents(),
                ),
                
                // Main content area
                Expanded(
                  child: _currentSection == null
                      ? const Center(child: Text('Select a section to begin'))
                      : _buildMainContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildTableOfContents() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Chapters',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        ..._buildChapterList(),
      ],
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
        ExpansionTile(
          leading: Icon(
            Icons.book,
            color: _currentChapterIndex == i
                ? const Color(0xFFD62828)
                : Colors.grey[600],
          ),
          title: Text(
            'Chapter ${i + 1}',
            style: TextStyle(
              fontWeight: _currentChapterIndex == i
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _currentChapterIndex == i
                  ? const Color(0xFFD62828)
                  : Colors.black87,
            ),
          ),
          subtitle: Text(
            chapter['title'] ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: chapterSections.map((section) {
            final sectionIndex = _sections.indexOf(section);
            final isCompleted = (_userProgress['completedSections'] ?? [])
                .contains(section['id']);
            final isCurrent = sectionIndex == _currentSectionIndex;

            return ListTile(
              dense: true,
              leading: Icon(
                isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: isCompleted ? Colors.green : Colors.grey,
                size: 20,
              ),
              title: Text(
                section['title'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? const Color(0xFFD62828) : Colors.black87,
                ),
              ),
              selected: isCurrent,
              selectedTileColor: const Color(0xFFD62828).withOpacity(0.1),
              onTap: () => _loadSection(sectionIndex),
            );
          }).toList(),
        ),
      );
    }

    return widgets;
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentSection!['title'] ?? '',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(
                      'Section ${_currentSection!['sectionNumber']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue[50],
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      '${_currentSection!['estimatedReadingTime']} min read',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green[50],
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      '+${_currentSection!['xpReward']} XP',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.orange[50],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _showingQuestions
                ? _buildQuestionsView()
                : _buildContentView(),
          ),
        ),

        // Bottom navigation
        _buildBottomNavigation(),
      ],
    );
  }

  Widget _buildContentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Markdown(
          data: _currentSection!['content'] ?? '',
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1E3F),
            ),
            h2: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1E3F),
            ),
            h3: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1E3F),
            ),
            p: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
            listBullet: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            setState(() => _showingQuestions = true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD62828),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Take Section Quiz',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.quiz, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Section Quiz - ${_currentQuestions.length} Questions',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _showingQuestions = false);
                },
                child: const Text('Back to Content'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ..._currentQuestions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(index, question);
        }),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _completeSection,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Complete Section',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question) {
    final questionId = question['id'];
    final isSubmitted = _submittedAnswers.containsKey(questionId);
    final isCorrect = _submittedAnswers[questionId] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(
                    '+${question['xpValue']} XP',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.orange[50],
                ),
                if (isSubmitted) ...[
                  const SizedBox(width: 8),
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              question['questionText'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ...['A', 'B', 'C', 'D'].map((option) {
              final optionText = question['options'][option] ?? '';
              final isSelected = _selectedAnswers[questionId] == option;
              final showCorrect = isSubmitted && question['correctAnswer'] == option;
              final showWrong = isSubmitted && isSelected && !isCorrect;

              return RadioListTile<String>(
                title: Text(
                  '$option. $optionText',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: showCorrect || showWrong
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: showCorrect
                        ? Colors.green
                        : showWrong
                            ? Colors.red
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
              );
            }),
            if (!isSubmitted) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _submitAnswer(
                  questionId,
                  question['correctAnswer'],
                  question['xpValue'],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Answer'),
              ),
            ],
            if (isSubmitted) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCorrect ? '✅ Correct!' : '❌ Incorrect',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.green[900] : Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
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

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _currentSectionIndex > 0
                ? () => _loadSection(_currentSectionIndex - 1)
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            'Section ${_currentSectionIndex + 1} of ${_sections.length}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _currentSectionIndex < _sections.length - 1
                ? () => _loadSection(_currentSectionIndex + 1)
                : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
