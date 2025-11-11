import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';
import 'quiz_taker_page.dart';

class QuizSetupPage extends StatefulWidget {
  final String? preselectedSubject;
  final String? preselectedExamType;
  final String? preselectedLevel;
  final List<Question>? preloadedQuestions;
  final String? triviaCategory; // New: for trivia category selection

  const QuizSetupPage({
    super.key,
    this.preselectedSubject,
    this.preselectedExamType,
    this.preselectedLevel,
    this.preloadedQuestions,
    this.triviaCategory,
  });

  @override
  State<QuizSetupPage> createState() => _QuizSetupPageState();
}

class _QuizSetupPageState extends State<QuizSetupPage> {
  final QuestionService _questionService = QuestionService();
  
  String? selectedSubject;
  String? selectedExamType;
  String? selectedLevel;
  int selectedQuestionCount = 10;
  bool isPracticeMode = false;
  bool randomizeQuestions = true;
  
  bool isLoadingQuestions = false;
  int availableQuestions = 0;

  final List<String> subjects = [
    'Religious and Moral Education',
    'Mathematics',
    'English Language',
    'Science',
    'Social Studies',
    'Information Technology',
    'Creative Arts',
    'French',
    'Twi',
    'Ga',
    'Ewe',
  ];

  final List<String> examTypes = [
    'BECE',
    'Mock Exam',
    'Class Test',
    'Assignment',
    'Practice Questions',
  ];

  final List<String> levels = [
    'JHS 1',
    'JHS 2',
    'JHS 3',
    'SHS 1',
    'SHS 2',
    'SHS 3',
  ];

  final List<int> questionCounts = [5, 10, 15, 20, 25, 30, 50];

  @override
  void initState() {
    super.initState();
    selectedSubject = widget.preselectedSubject;
    selectedExamType = widget.preselectedExamType;
    selectedLevel = widget.preselectedLevel;
    
    if (selectedSubject != null && selectedExamType != null && selectedLevel != null) {
      _loadAvailableQuestions();
    }
  }

  Future<void> _loadAvailableQuestions() async {
    if (selectedSubject == null || selectedExamType == null || selectedLevel == null) {
      return;
    }

    setState(() => isLoadingQuestions = true);
    
    try {
      final questions = await _questionService.getQuestionsByFilters(
        subject: _mapStringToSubject(selectedSubject!),
        examType: _mapStringToExamType(selectedExamType!),
        level: selectedLevel!,
        triviaCategory: widget.triviaCategory, // Pass trivia category for filtering
      );
      
      setState(() {
        availableQuestions = questions.length;
        // For trivia: cap at 20 questions by default
        // For other exams: cap at 50 questions
        final maxQuestions = selectedExamType?.toLowerCase() == 'trivia' ? 20 : 50;
        selectedQuestionCount = availableQuestions > maxQuestions ? maxQuestions : availableQuestions;
      });
    } catch (e) {
      setState(() => availableQuestions = 0);
    } finally {
      setState(() => isLoadingQuestions = false);
    }
  }

  void _startQuiz() {
    if (selectedSubject == null || selectedExamType == null || selectedLevel == null) {
      _showErrorDialog('Please select all required fields');
      return;
    }

    if (availableQuestions == 0) {
      _showErrorDialog('No questions available for the selected criteria');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizTakerPage(
          subject: selectedSubject!,
          examType: selectedExamType!,
          level: selectedLevel!,
          preloadedQuestions: widget.preloadedQuestions,
          randomizeQuestions: randomizeQuestions,
          questionCount: selectedQuestionCount,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Setup Error',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD62828),
          ),
        ),
        content: Text(message, style: GoogleFonts.montserrat()),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: Text('OK', style: GoogleFonts.montserrat()),
          ),
        ],
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
              expandedHeight: 120,
              pinned: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1E3F),
              elevation: 0,
              title: Text(
                'Quiz Setup',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 700, // 50% width reduction for desktop
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center, // Center content
                      children: [
                        // Header
                        Text(
                          'Configure Your Quiz',
                          textAlign: TextAlign.center, // Center the title
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        Text(
                          'Customize your quiz experience by selecting your preferences below.',
                          textAlign: TextAlign.center, // Center the subtitle
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                          ),
                        ),

                    const SizedBox(height: 32),

                    // Subject Selection
                    _buildSelectionCard(
                      'Subject',
                      'Choose the subject for your quiz',
                      Icons.school,
                      Colors.blue,
                      selectedSubject,
                      subjects,
                      (value) {
                        setState(() {
                          selectedSubject = value;
                          availableQuestions = 0;
                        });
                        _loadAvailableQuestions();
                      },
                      isMobile,
                    ),

                    const SizedBox(height: 16),

                    // Exam Type Selection
                    _buildSelectionCard(
                      'Exam Type',
                      'Select the type of examination',
                      Icons.assignment,
                      Colors.green,
                      selectedExamType,
                      examTypes,
                      (value) {
                        setState(() {
                          selectedExamType = value;
                          availableQuestions = 0;
                        });
                        _loadAvailableQuestions();
                      },
                      isMobile,
                    ),

                    const SizedBox(height: 16),

                    // Level Selection
                    _buildSelectionCard(
                      'Level',
                      'Choose your education level',
                      Icons.grade,
                      Colors.orange,
                      selectedLevel,
                      levels,
                      (value) {
                        setState(() {
                          selectedLevel = value;
                          availableQuestions = 0;
                        });
                        _loadAvailableQuestions();
                      },
                      isMobile,
                    ),

                    const SizedBox(height: 24),

                    // Quiz Options
                    if (availableQuestions > 0) ...[
                      _buildOptionsCard(isMobile),
                      const SizedBox(height: 24),
                    ],

                    // Available Questions Info
                    if (selectedSubject != null && selectedExamType != null && selectedLevel != null) ...[
                      _buildInfoCard(isMobile),
                      const SizedBox(height: 24),
                    ],

                    // Start Quiz Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: availableQuestions > 0 ? _startQuiz : null,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          isLoadingQuestions ? 'Loading...' : 'Start Quiz',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: availableQuestions > 0 
                              ? const Color(0xFF2ECC71) // Accent Green
                              : Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 16 : 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String? selectedValue,
    List<String> options,
    Function(String?) onChanged,
    bool isMobile,
  ) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1E3F),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: selectedValue,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              hint: Text(
                'Select $title',
                style: GoogleFonts.montserrat(
                  color: Colors.grey[600],
                ),
              ),
              dropdownColor: Colors.white,
              items: options.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard(bool isMobile) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Quiz Options',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Show number of questions (non-editable)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD62828).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD62828).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.quiz, color: Color(0xFFD62828)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz Questions',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        Text(
                          '$selectedQuestionCount questions will be included in this quiz',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Practice Mode Toggle
            SwitchListTile(
              title: Text(
                'Practice Mode',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              subtitle: Text(
                'Show explanations after each question',
                style: GoogleFonts.montserrat(
                  fontSize: 12, 
                  color: Colors.grey[600],
                ),
              ),
              value: isPracticeMode,
              onChanged: (value) => setState(() => isPracticeMode = value),
              activeColor: const Color(0xFFD62828),
            ),

            // Randomize Questions Toggle
            SwitchListTile(
              title: Text(
                'Randomize Questions',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              subtitle: Text(
                'Questions will appear in random order',
                style: GoogleFonts.montserrat(
                  fontSize: 12, 
                  color: Colors.grey[600],
                ),
              ),
              value: randomizeQuestions,
              onChanged: (value) => setState(() => randomizeQuestions = value),
              activeColor: const Color(0xFFD62828),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isMobile) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLoadingQuestions 
                    ? Colors.grey.withValues(alpha: 0.1)
                    : availableQuestions > 0 
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoadingQuestions
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      availableQuestions > 0 ? Icons.check_circle : Icons.error,
                      color: availableQuestions > 0 ? Colors.green : Colors.red,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoadingQuestions 
                        ? 'Loading Questions...'
                        : '$availableQuestions Questions Available',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                  if (!isLoadingQuestions) ...[
                    Text(
                      availableQuestions > 0
                          ? 'Ready to start your quiz with $selectedQuestionCount questions'
                          : 'No questions found for the selected criteria',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods to map strings to enums
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
      case 'Asante Twi':
        return Subject.asanteTwi;
      case 'Ga':
        return Subject.ga;
      case 'Ewe':
        return Subject.religiousMoralEducation; // Fallback for Ewe
      default:
        return Subject.religiousMoralEducation; // Default fallback
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
        return ExamType.bece; // Default fallback
    }
  }
}
