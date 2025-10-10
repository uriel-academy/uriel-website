import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';
import 'admin_tabs.dart';
import 'storage_content_tab.dart';

class AdminQuestionManagementPage extends StatefulWidget {
  const AdminQuestionManagementPage({Key? key}) : super(key: key);

  @override
  State<AdminQuestionManagementPage> createState() => _AdminQuestionManagementPageState();
}

class _AdminQuestionManagementPageState extends State<AdminQuestionManagementPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QuestionService _questionService = QuestionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Question Management',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A1E3F),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFD62828),
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Single Question'),
            Tab(text: 'Bulk Import'),
            Tab(text: 'Trivia Import'),
            Tab(text: 'Manage Exams'),
            Tab(text: 'Storage Files'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleQuestionInputTab(questionService: _questionService),
          BulkQuestionImportTab(questionService: _questionService),
          TriviaImportTab(questionService: _questionService),
          ExamManagementTab(questionService: _questionService),
          const StorageContentTab(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class SingleQuestionInputTab extends StatefulWidget {
  final QuestionService questionService;

  const SingleQuestionInputTab({Key? key, required this.questionService}) : super(key: key);

  @override
  State<SingleQuestionInputTab> createState() => _SingleQuestionInputTabState();
}

class _SingleQuestionInputTabState extends State<SingleQuestionInputTab> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  final _explanationController = TextEditingController();
  final _marksController = TextEditingController();
  final _yearController = TextEditingController();
  final _questionNumberController = TextEditingController();
  final _sectionController = TextEditingController();
  
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  
  QuestionType _selectedType = QuestionType.multipleChoice;
  Subject _selectedSubject = Subject.mathematics;
  ExamType _selectedExamType = ExamType.bece;
  String _selectedDifficulty = 'medium';
  final List<String> _topics = [];
  final _topicController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildQuestionContentSection(),
              const SizedBox(height: 24),
              if (_selectedType == QuestionType.multipleChoice) 
                _buildMultipleChoiceSection(),
              const SizedBox(height: 24),
              _buildAnswerSection(),
              const SizedBox(height: 24),
              _buildMetadataSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
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
                    Subject.values,
                    (value) => setState(() => _selectedSubject = value!),
                    (subject) => _getSubjectDisplayName(subject),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown<ExamType>(
                    'Exam Type',
                    _selectedExamType,
                    ExamType.values,
                    (value) => setState(() => _selectedExamType = value!),
                    (examType) => _getExamTypeDisplayName(examType),
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
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _sectionController,
                    decoration: _getInputDecoration('Section (A, B, C, General)'),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _questionNumberController,
                    decoration: _getInputDecoration('Question Number'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContentSection() {
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
                Text(
                  'Question Content',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                const Spacer(),
                _buildDropdown<QuestionType>(
                  'Question Type',
                  _selectedType,
                  QuestionType.values,
                  (value) => setState(() => _selectedType = value!),
                  (type) => _getQuestionTypeDisplayName(type),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _questionController,
              decoration: _getInputDecoration('Question Text'),
              maxLines: 4,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multiple Choice Options',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _optionControllers[index],
                  decoration: _getInputDecoration('Option ${String.fromCharCode(65 + index)}'),
                  validator: _selectedType == QuestionType.multipleChoice
                      ? (value) => value?.isEmpty ?? true ? 'Required' : null
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answer & Explanation',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _correctAnswerController,
              decoration: _getInputDecoration(
                _selectedType == QuestionType.multipleChoice 
                    ? 'Correct Answer (A, B, C, or D)'
                    : 'Correct Answer'
              ),
              maxLines: _selectedType == QuestionType.multipleChoice ? 1 : 3,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _explanationController,
              decoration: _getInputDecoration('Explanation (Optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _marksController,
              decoration: _getInputDecoration('Marks'),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            _buildDropdown<String>(
              'Difficulty',
              _selectedDifficulty,
              ['easy', 'medium', 'hard'],
              (value) => setState(() => _selectedDifficulty = value!),
              (difficulty) => difficulty.toUpperCase(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _topicController,
                    decoration: _getInputDecoration('Add Topic'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTopic,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topics.map((topic) {
                return Chip(
                  label: Text(topic),
                  onDeleted: () => _removeTopic(topic),
                  backgroundColor: Colors.grey[200],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitQuestion,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1E3F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Add Question',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
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

  void _addTopic() {
    if (_topicController.text.trim().isNotEmpty) {
      setState(() {
        _topics.add(_topicController.text.trim());
        _topicController.clear();
      });
    }
  }

  void _removeTopic(String topic) {
    setState(() {
      _topics.remove(topic);
    });
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final question = Question(
        id: 'q_${DateTime.now().millisecondsSinceEpoch}',
        questionText: _questionController.text.trim(),
        type: _selectedType,
        subject: _selectedSubject,
        examType: _selectedExamType,
        year: _yearController.text.trim(),
        section: _sectionController.text.trim(),
        questionNumber: int.parse(_questionNumberController.text.trim()),
        options: _selectedType == QuestionType.multipleChoice
            ? _optionControllers.map((c) => c.text.trim()).toList()
            : null,
        correctAnswer: _correctAnswerController.text.trim(),
        explanation: _explanationController.text.trim().isEmpty 
            ? null 
            : _explanationController.text.trim(),
        marks: int.parse(_marksController.text.trim()),
        difficulty: _selectedDifficulty,
        topics: _topics,
        createdAt: DateTime.now(),
        createdBy: FirebaseAuth.instance.currentUser?.email ?? 'admin',
      );
      
      await widget.questionService.addQuestion(question);
      
      _showSnackBar('Question added successfully!', Colors.green);
      _clearForm();
      
    } catch (e) {
      _showSnackBar('Failed to add question: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _questionController.clear();
    _correctAnswerController.clear();
    _explanationController.clear();
    _marksController.clear();
    _yearController.clear();
    _questionNumberController.clear();
    _sectionController.clear();
    _topicController.clear();
    
    for (var controller in _optionControllers) {
      controller.clear();
    }
    
    setState(() {
      _topics.clear();
      _selectedType = QuestionType.multipleChoice;
      _selectedSubject = Subject.mathematics;
      _selectedExamType = ExamType.bece;
      _selectedDifficulty = 'medium';
    });
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
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English Language';
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
        return 'Religious & Moral Education';
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

  String _getQuestionTypeDisplayName(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.shortAnswer:
        return 'Short Answer';
      case QuestionType.essay:
        return 'Essay';
      case QuestionType.calculation:
        return 'Calculation';
      case QuestionType.trivia:
        return 'Trivia';
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _correctAnswerController.dispose();
    _explanationController.dispose();
    _marksController.dispose();
    _yearController.dispose();
    _questionNumberController.dispose();
    _sectionController.dispose();
    _topicController.dispose();
    
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }
}