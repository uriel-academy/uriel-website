import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';
import 'quiz_taker_page.dart';

class RevisionPage extends StatefulWidget {
  const RevisionPage({Key? key}) : super(key: key);

  @override
  State<RevisionPage> createState() => _RevisionPageState();
}

class _RevisionPageState extends State<RevisionPage> {
  final QuestionService _questionService = QuestionService();

  // Selection states
  ExamType? _selectedExamType;
  Subject? _selectedSubject;
  int _selectedQuestionCount = 20;

  // Available options
  List<ExamType> _availableExamTypes = [ExamType.bece, ExamType.wassce];
  List<Subject> _availableSubjects = [Subject.ict, Subject.religiousMoralEducation]; // Only ICT and RME as per questions page
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    // No need to load subjects anymore - they're hardcoded
  }

  Future<void> _generateMockExam() async {
    if (_selectedExamType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both exam type and subject'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() => _isGeneratingQuiz = true);

    try {
      // Get all questions for the selected subject and exam type
      final allQuestions = await _questionService.getQuestionsByFilters(
        examType: _selectedExamType,
        subject: _selectedSubject,
        activeOnly: true,
      );

      if (allQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No questions found for ${_getSubjectDisplayName(_selectedSubject!)} (${_selectedExamType!.name.toUpperCase()})'),
            backgroundColor: Color(0xFFD62828),
          ),
        );
        return;
      }

      // Generate robust random selection
      final selectedQuestions = _selectRandomQuestions(allQuestions, _selectedQuestionCount);

      if (selectedQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to generate quiz. Please try again.'),
            backgroundColor: Color(0xFFD62828),
          ),
        );
        return;
      }

      // Navigate to quiz taker
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizTakerPage(
            subject: _getSubjectDisplayName(_selectedSubject!),
            examType: _selectedExamType!.name.toUpperCase(),
            level: 'JHS 3', // Default level
            preloadedQuestions: selectedQuestions,
            questionCount: _selectedQuestionCount,
            randomizeQuestions: false, // Already randomized
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error generating mock exam: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error generating quiz. Please try again.'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
    } finally {
      setState(() => _isGeneratingQuiz = false);
    }
  }

  List<Question> _selectRandomQuestions(List<Question> allQuestions, int count) {
    if (allQuestions.length <= count) {
      // Return all questions if we don't have enough
      return List.from(allQuestions);
    }

    // Create a robust randomization algorithm
    final random = DateTime.now().millisecondsSinceEpoch;
    final selectedQuestions = <Question>[];

    // Shuffle the questions using a seed based on current time and user selections
    final shuffledQuestions = List<Question>.from(allQuestions);
    shuffledQuestions.shuffle();

    // Take the first 'count' questions from the shuffled list
    selectedQuestions.addAll(shuffledQuestions.take(count));

    // Sort by question number for consistent ordering within the quiz
    selectedQuestions.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));

    return selectedQuestions;
  }

  String _getSubjectDisplayName(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English';
      case Subject.integratedScience:
        return 'Integrated Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.ghanaianLanguage:
        return 'Ghanaian Language';
      case Subject.french:
        return 'French';
      case Subject.ict:
        return 'ICT';
      case Subject.religiousMoralEducation:
        return 'Religious and Moral Education';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.trivia:
        return 'Trivia';
    }
  }

  String _getExamTypeDisplayName(ExamType examType) {
    switch (examType) {
      case ExamType.bece:
        return 'BECE';
      case ExamType.wassce:
        return 'WASSCE';
      case ExamType.mock:
        return 'Mock Exam';
      case ExamType.practice:
        return 'Practice';
      case ExamType.trivia:
        return 'Trivia';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Revision',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 28 : 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create personalized mock exams to test your knowledge',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),

              // Exam Type, Subject & Question Count Selection (Combined)
              _buildSelectionCard(
                title: 'Create Mock Exam',
                subtitle: 'Choose your exam type, subject, and number of questions',
                child: _buildExamTypeSubjectAndCountSelector(isSmallScreen),
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 32 : 40),

              // Generate Quiz Button
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Ready to start your revision?',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _isGeneratingQuiz
                        ? const CircularProgressIndicator(color: Color(0xFFD62828))
                        : ElevatedButton.icon(
                            onPressed: _generateMockExam,
                            icon: const Icon(Icons.play_arrow, size: 20),
                            label: Text(
                              'Generate Mock Exam',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2ECC71),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                  ],
                ),
              ),

              // Add bottom padding for mobile
              if (isSmallScreen) const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildExamTypeSubjectAndCountSelector(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter dropdowns
        if (isSmallScreen)
          Column(
            children: [
              _buildFilterDropdown('Exam Type', _selectedExamType?.name.toUpperCase() ?? 'Select Type', _getExamTypeOptions(), (value) {
                final examType = value == 'Select Type' ? null : ExamType.values.firstWhere((e) => e.name.toUpperCase() == value);
                setState(() => _selectedExamType = examType);
              }),
              const SizedBox(height: 12),
              _buildFilterDropdown('Subject', _selectedSubject != null ? _getSubjectDisplayName(_selectedSubject!) : 'Select Subject', _getSubjectOptions(), (value) {
                final subject = value == 'Select Subject' ? null : _availableSubjects.firstWhere((s) => _getSubjectDisplayName(s) == value);
                setState(() => _selectedSubject = subject);
              }),
              const SizedBox(height: 12),
              _buildFilterDropdown('Question Count', _selectedQuestionCount.toString(), ['10', '20', '40'], (value) {
                setState(() => _selectedQuestionCount = int.parse(value!));
              }),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown('Exam Type', _selectedExamType?.name.toUpperCase() ?? 'Select Type', _getExamTypeOptions(), (value) {
                  final examType = value == 'Select Type' ? null : ExamType.values.firstWhere((e) => e.name.toUpperCase() == value);
                  setState(() => _selectedExamType = examType);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Subject', _selectedSubject != null ? _getSubjectDisplayName(_selectedSubject!) : 'Select Subject', _getSubjectOptions(), (value) {
                  final subject = value == 'Select Subject' ? null : _availableSubjects.firstWhere((s) => _getSubjectDisplayName(s) == value);
                  setState(() => _selectedSubject = subject);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Question Count', _selectedQuestionCount.toString(), ['10', '20', '40'], (value) {
                  setState(() => _selectedQuestionCount = int.parse(value!));
                }),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF8FAFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownColor: Colors.white,
      style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
      items: options.map((option) {
        return DropdownMenuItem(value: option, child: Text(option));
      }).toList(),
    );
  }

  List<String> _getExamTypeOptions() {
    return ['Select Type', ..._availableExamTypes.map((e) => e.name.toUpperCase())];
  }

  List<String> _getSubjectOptions() {
    return ['Select Subject', ..._availableSubjects.map((s) => _getSubjectDisplayName(s))];
  }
}