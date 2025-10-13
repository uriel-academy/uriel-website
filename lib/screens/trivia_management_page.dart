import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';
import 'storage_content_tab.dart';

class TriviaManagementPage extends StatefulWidget {
  const TriviaManagementPage({Key? key}) : super(key: key);

  @override
  State<TriviaManagementPage> createState() => _TriviaManagementPageState();
}

class _TriviaManagementPageState extends State<TriviaManagementPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QuestionService _questionService = QuestionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Trivia Management',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF9C27B0),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Single Question'),
            Tab(text: 'Bulk Import'),
            Tab(text: 'Manage'),
            Tab(text: 'Storage Files'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TriviaSingleQuestionTab(questionService: _questionService),
          TriviaBulkImportTab(questionService: _questionService),
          TriviaManageTab(questionService: _questionService),
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

class TriviaSingleQuestionTab extends StatefulWidget {
  final QuestionService questionService;

  const TriviaSingleQuestionTab({Key? key, required this.questionService}) : super(key: key);

  @override
  State<TriviaSingleQuestionTab> createState() => _TriviaSingleQuestionTabState();
}

class _TriviaSingleQuestionTabState extends State<TriviaSingleQuestionTab> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _categoryController = TextEditingController();
  final _explanationController = TextEditingController();
  
  String _selectedDifficulty = 'medium';
  final List<String> _categories = [];
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
              _buildInstructionsCard(),
              const SizedBox(height: 24),
              _buildQuestionCard(),
              const SizedBox(height: 24),
              _buildAnswerCard(),
              const SizedBox(height: 24),
              _buildMetadataCard(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
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
                const Icon(Icons.lightbulb, color: Color(0xFF9C27B0)),
                const SizedBox(width: 8),
                Text(
                  'Trivia Question Tips',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '• Make questions clear and unambiguous\n'
              '• Use interesting and educational facts\n'
              '• Add categories for better organization\n'
              '• Include explanations for learning value',
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

  Widget _buildQuestionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _questionController,
              decoration: _getInputDecoration('Enter your trivia question...'),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Question is required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerCard() {
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
              controller: _answerController,
              decoration: _getInputDecoration('Correct answer'),
              validator: (value) => value?.isEmpty ?? true ? 'Answer is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _explanationController,
              decoration: _getInputDecoration('Additional explanation (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category & Difficulty',
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
                    controller: _categoryController,
                    decoration: _getInputDecoration('Add Category (e.g., History, Science)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
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
              children: _categories.map((category) {
                return Chip(
                  label: Text(category),
                  onDeleted: () => _removeCategory(category),
                  backgroundColor: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                  deleteIconColor: const Color(0xFF9C27B0),
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
          backgroundColor: const Color(0xFF9C27B0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Add Trivia Question',
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
        borderSide: const BorderSide(color: Color(0xFF9C27B0)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  void _addCategory() {
    if (_categoryController.text.trim().isNotEmpty) {
      setState(() {
        _categories.add(_categoryController.text.trim());
        _categoryController.clear();
      });
    }
  }

  void _removeCategory(String category) {
    setState(() {
      _categories.remove(category);
    });
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final question = Question(
        id: 'trivia_${DateTime.now().millisecondsSinceEpoch}',
        questionText: _questionController.text.trim(),
        type: QuestionType.trivia,
        subject: Subject.trivia,
        examType: ExamType.trivia,
        year: DateTime.now().year.toString(),
        section: 'General',
        questionNumber: DateTime.now().millisecondsSinceEpoch % 10000,
        correctAnswer: _answerController.text.trim(),
        explanation: _explanationController.text.trim().isEmpty 
            ? null 
            : _explanationController.text.trim(),
        marks: 1,
        difficulty: _selectedDifficulty,
        topics: _categories.isEmpty ? ['general'] : _categories,
        createdAt: DateTime.now(),
        createdBy: FirebaseAuth.instance.currentUser?.email ?? 'admin',
      );
      
      await widget.questionService.addQuestion(question);
      
      _showSnackBar('Trivia question added successfully!', Colors.green);
      _clearForm();
      
    } catch (e) {
      _showSnackBar('Failed to add question: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _questionController.clear();
    _answerController.clear();
    _explanationController.clear();
    _categoryController.clear();
    
    setState(() {
      _categories.clear();
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

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _explanationController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
}

class TriviaBulkImportTab extends StatefulWidget {
  final QuestionService questionService;

  const TriviaBulkImportTab({Key? key, required this.questionService}) : super(key: key);

  @override
  State<TriviaBulkImportTab> createState() => _TriviaBulkImportTabState();
}

class _TriviaBulkImportTabState extends State<TriviaBulkImportTab> {
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
                const Icon(Icons.file_upload, color: Color(0xFF9C27B0)),
                const SizedBox(width: 8),
                Text(
                  'Bulk Import - 500 Trivia Questions',
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
              'Perfect for importing your 500 trivia questions! Use this format:',
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

[Geography]
4. What is the highest mountain in the world?
Answer: Mount Everest

[Science]
5. What is the chemical symbol for gold?
Answer: Au''',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 12,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '💡 Tip: Add [Category] before questions to organize them automatically!',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: const Color(0xFF9C27B0),
                fontWeight: FontWeight.w500,
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
              'Paste Your 500 Trivia Questions',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Paste all your trivia questions here...',
                labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF9C27B0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
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
                const Icon(Icons.preview, color: Color(0xFF9C27B0)),
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
                itemCount: _previewQuestions.take(10).length,
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
                          color: const Color(0xFF9C27B0),
                        ),
                      ),
                      if (question.topics.isNotEmpty && question.topics.first != 'general')
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
              backgroundColor: const Color(0xFF9C27B0),
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
                : _uploadTrivia,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Upload All',
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
      
      _showSnackBar('🎉 Uploaded ${_previewQuestions.length} trivia questions successfully!', Colors.green);
      
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

class TriviaManageTab extends StatelessWidget {
  final QuestionService questionService;

  const TriviaManageTab({Key? key, required this.questionService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(),
          const SizedBox(height: 20),
          _buildManagementOptions(),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trivia Statistics',
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
                  child: _buildStatItem('Total Questions', '1,247', Icons.psychology),
                ),
                Expanded(
                  child: _buildStatItem('Categories', '15', Icons.category),
                ),
                Expanded(
                  child: _buildStatItem('This Week', '+89', Icons.trending_up),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF9C27B0), size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildManagementOptions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Management Options',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            
            _buildManagementTile(
              'Browse Questions',
              'View and edit existing trivia questions',
              Icons.list,
              const Color(0xFF3498DB),
              () {
                // Navigate to question browser
              },
            ),
            
            _buildManagementTile(
              'Manage Categories',
              'Organize questions by category',
              Icons.category,
              const Color(0xFF2ECC71),
              () {
                // Navigate to category management
              },
            ),
            
            _buildManagementTile(
              'Export Questions',
              'Download questions for backup',
              Icons.download,
              const Color(0xFFE67E22),
              () {
                // Export functionality
              },
            ),
            
            _buildManagementTile(
              'Question Analytics',
              'View performance and usage stats',
              Icons.analytics,
              const Color(0xFF9B59B6),
              () {
                // Navigate to analytics
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[400],
          size: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: Colors.grey[50],
      ),
    );
  }
}