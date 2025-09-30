import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';

// Bulk Question Import Tab
class BulkQuestionImportTab extends StatefulWidget {
  final QuestionService questionService;

  const BulkQuestionImportTab({Key? key, required this.questionService}) : super(key: key);

  @override
  State<BulkQuestionImportTab> createState() => _BulkQuestionImportTabState();
}

class _BulkQuestionImportTabState extends State<BulkQuestionImportTab> {
  final _textController = TextEditingController();
  final _yearController = TextEditingController();
  Subject _selectedSubject = Subject.mathematics;
  ExamType _selectedExamType = ExamType.bece;
  String _selectedSection = 'A';
  bool _isProcessing = false;
  List<Question> _previewQuestions = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInstructionsCard(),
          const SizedBox(height: 20),
          _buildConfigurationCard(),
          const SizedBox(height: 20),
          _buildInputCard(),
          const SizedBox(height: 20),
          if (_previewQuestions.isNotEmpty) _buildPreviewCard(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF1A1E3F)),
                const SizedBox(width: 8),
                Text(
                  'Bulk Import Instructions',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Format your questions using this structure:',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                '''For Multiple Choice Questions:
Q1. What is 2 + 2?
A) 3
B) 4
C) 5
D) 6
Answer: B
Marks: 1

Q2. What is the capital of Ghana?
A) Kumasi
B) Accra
C) Tamale
D) Cape Coast
Answer: B
Marks: 2

For Essay Questions:
Q1. Explain the water cycle.
Answer: The water cycle is the process by which water moves through the environment...
Marks: 10''',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 12,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exam Configuration',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown<Subject>(
                    'Subject',
                    _selectedSubject,
                    Subject.values.where((s) => s != Subject.trivia).toList(),
                    (value) => setState(() => _selectedSubject = value!),
                    _getSubjectDisplayName,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown<ExamType>(
                    'Exam Type',
                    _selectedExamType,
                    ExamType.values.where((e) => e != ExamType.trivia).toList(),
                    (value) => setState(() => _selectedExamType = value!),
                    _getExamTypeDisplayName,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    decoration: _getInputDecoration('Year (e.g., 2024)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown<String>(
                    'Section',
                    _selectedSection,
                    ['A', 'B', 'C', 'General'],
                    (value) => setState(() => _selectedSection = value!),
                    (section) => 'Section $section',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Data',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: _getInputDecoration('Paste your questions here...'),
              maxLines: 15,
              style: GoogleFonts.sourceCodePro(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview, color: Color(0xFF1A1E3F)),
                const SizedBox(width: 8),
                Text(
                  'Preview (${_previewQuestions.length} questions)',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _previewQuestions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final question = _previewQuestions[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}. ${question.questionText}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (question.options != null) ...[
                        const SizedBox(height: 8),
                        ...question.options!.asMap().entries.map((entry) {
                          final optionIndex = entry.key;
                          final option = entry.value;
                          return Text(
                            '${String.fromCharCode(65 + optionIndex)}) $option',
                            style: GoogleFonts.montserrat(fontSize: 12),
                          );
                        }),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Answer: ${question.correctAnswer} (${question.marks} marks)',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFD62828),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _parseQuestions,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Parse Questions',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _previewQuestions.isEmpty || _isProcessing 
                ? null 
                : _uploadQuestions,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1E3F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Upload Questions',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T value,
    List<T> items,
    void Function(T?) onChanged,
    String Function(T) displayName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          decoration: _getInputDecoration('Select $label'),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(displayName(item)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD62828)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  Future<void> _parseQuestions() async {
    if (_textController.text.trim().isEmpty) {
      _showSnackBar('Please enter question data', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final questions = await widget.questionService.parseQuestionsFromText(
        _textController.text.trim(),
        subject: _selectedSubject,
        examType: _selectedExamType,
        year: _yearController.text.trim(),
        section: _selectedSection,
      );

      setState(() => _previewQuestions = questions);
      _showSnackBar('Parsed ${questions.length} questions successfully!', Colors.green);
      
    } catch (e) {
      _showSnackBar('Failed to parse questions: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _uploadQuestions() async {
    setState(() => _isProcessing = true);

    try {
      await widget.questionService.addQuestionsBatch(_previewQuestions);
      
      _showSnackBar('Uploaded ${_previewQuestions.length} questions successfully!', Colors.green);
      
      // Clear the form
      _textController.clear();
      setState(() => _previewQuestions = []);
      
    } catch (e) {
      _showSnackBar('Failed to upload questions: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getSubjectDisplayName(Subject subject) {
    switch (subject) {
      case Subject.mathematics: return 'Mathematics';
      case Subject.english: return 'English Language';
      case Subject.integratedScience: return 'Integrated Science';
      case Subject.socialStudies: return 'Social Studies';
      case Subject.ghanaianLanguage: return 'Ghanaian Language';
      case Subject.french: return 'French';
      case Subject.ict: return 'ICT';
      case Subject.religiousMoralEducation: return 'Religious & Moral Education';
      case Subject.creativeArts: return 'Creative Arts';
      case Subject.trivia: return 'Trivia';
    }
  }

  String _getExamTypeDisplayName(ExamType examType) {
    switch (examType) {
      case ExamType.bece: return 'BECE';
      case ExamType.wassce: return 'WASSCE';
      case ExamType.mock: return 'Mock Exam';
      case ExamType.practice: return 'Practice';
      case ExamType.trivia: return 'Trivia';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _yearController.dispose();
    super.dispose();
  }
}

// Trivia Import Tab
class TriviaImportTab extends StatefulWidget {
  final QuestionService questionService;

  const TriviaImportTab({Key? key, required this.questionService}) : super(key: key);

  @override
  State<TriviaImportTab> createState() => _TriviaImportTabState();
}

class _TriviaImportTabState extends State<TriviaImportTab> {
  final _textController = TextEditingController();
  bool _isProcessing = false;
  List<Question> _previewQuestions = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInstructionsCard(),
          const SizedBox(height: 20),
          _buildInputCard(),
          const SizedBox(height: 20),
          if (_previewQuestions.isNotEmpty) _buildPreviewCard(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.quiz, color: Color(0xFF1A1E3F)),
                const SizedBox(width: 8),
                Text(
                  'Trivia Import Instructions',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Paste your trivia questions in this format:',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                '''1. What is the capital of France?
Answer: Paris

2. Who wrote Romeo and Juliet?
Answer: William Shakespeare

3. What is the largest planet in our solar system?
Answer: Jupiter

OR with categories:

[Geography]
1. What is the capital of France?
Answer: Paris

[Literature]
2. Who wrote Romeo and Juliet?
Answer: William Shakespeare''',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 12,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trivia Questions Data',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: _getInputDecoration('Paste your 500 trivia questions here...'),
              maxLines: 20,
              style: GoogleFonts.sourceCodePro(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview, color: Color(0xFF1A1E3F)),
                const SizedBox(width: 8),
                Text(
                  'Preview (${_previewQuestions.length} trivia questions)',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _previewQuestions.take(10).length, // Show first 10
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final question = _previewQuestions[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}. ${question.questionText}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Answer: ${question.correctAnswer}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFD62828),
                        ),
                      ),
                      if (question.topics.isNotEmpty)
                        Text(
                          'Category: ${question.topics.first}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (_previewQuestions.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${_previewQuestions.length - 10} more questions',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _parseTrivia,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Parse Trivia',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _previewQuestions.isEmpty || _isProcessing 
                ? null 
                : _uploadTrivia,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1E3F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Upload Trivia',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD62828)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  Future<void> _parseTrivia() async {
    if (_textController.text.trim().isEmpty) {
      _showSnackBar('Please enter trivia data', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final questions = await widget.questionService.parseTriviaQuestions(
        _textController.text.trim(),
      );

      setState(() => _previewQuestions = questions);
      _showSnackBar('Parsed ${questions.length} trivia questions successfully!', Colors.green);
      
    } catch (e) {
      _showSnackBar('Failed to parse trivia: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _uploadTrivia() async {
    setState(() => _isProcessing = true);

    try {
      await widget.questionService.addQuestionsBatch(_previewQuestions);
      
      _showSnackBar('Uploaded ${_previewQuestions.length} trivia questions successfully!', Colors.green);
      
      // Clear the form
      _textController.clear();
      setState(() => _previewQuestions = []);
      
    } catch (e) {
      _showSnackBar('Failed to upload trivia: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

// Exam Management Tab
class ExamManagementTab extends StatefulWidget {
  final QuestionService questionService;

  const ExamManagementTab({Key? key, required this.questionService}) : super(key: key);

  @override
  State<ExamManagementTab> createState() => _ExamManagementTabState();
}

class _ExamManagementTabState extends State<ExamManagementTab> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAutoExamCard(),
          const SizedBox(height: 20),
          _buildManualExamCard(),
        ],
      ),
    );
  }

  Widget _buildAutoExamCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF1A1E3F)),
                const SizedBox(width: 8),
                Text(
                  'Auto-Generate BECE Exams',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Automatically create complete BECE exams with proper structure:\n'
              '• Section A: 40 Multiple Choice Questions\n'
              '• Section B: 6-8 Essay Questions\n'
              '• Organized by subject and year',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _createBECEExam(Subject.mathematics),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1E3F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Mathematics',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _createBECEExam(Subject.english),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1E3F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'English',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _createBECEExam(Subject.integratedScience),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1E3F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Science',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _createBECEExam(Subject.socialStudies),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1E3F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Social Studies',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualExamCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Color(0xFF1A1E3F)),
                const SizedBox(width: 8),
                Text(
                  'Manual Exam Creation',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Coming soon: Create custom exams by selecting specific questions.',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBECEExam(Subject subject) async {
    setState(() => _isLoading = true);

    try {
      final exam = await widget.questionService.createBECEExam(subject, '2024');
      
      _showSnackBar(
        'Created ${_getSubjectDisplayName(subject)} BECE exam with ${exam.questionIds.length} questions!',
        Colors.green,
      );
      
    } catch (e) {
      _showSnackBar('Failed to create exam: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getSubjectDisplayName(Subject subject) {
    switch (subject) {
      case Subject.mathematics: return 'Mathematics';
      case Subject.english: return 'English Language';
      case Subject.integratedScience: return 'Integrated Science';
      case Subject.socialStudies: return 'Social Studies';
      case Subject.ghanaianLanguage: return 'Ghanaian Language';
      case Subject.french: return 'French';
      case Subject.ict: return 'ICT';
      case Subject.religiousMoralEducation: return 'Religious & Moral Education';
      case Subject.creativeArts: return 'Creative Arts';
      case Subject.trivia: return 'Trivia';
    }
  }
}