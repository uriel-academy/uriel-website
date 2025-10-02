import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';

class RMEQuestionsDebugPage extends StatefulWidget {
  const RMEQuestionsDebugPage({Key? key}) : super(key: key);

  @override
  State<RMEQuestionsDebugPage> createState() => _RMEQuestionsDebugPageState();
}

class _RMEQuestionsDebugPageState extends State<RMEQuestionsDebugPage> {
  final QuestionService _questionService = QuestionService();
  List<Question> _rmeQuestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRMEQuestions();
  }

  Future<void> _loadRMEQuestions() async {
    try {
      print('🔍 Loading RME questions for debug...');
      final questions = await _questionService.getRMEQuestions();
      print('📊 Debug: Got ${questions.length} RME questions');
      
      setState(() {
        _rmeQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading RME questions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'RME Questions Debug',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1A1E3F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RME Questions Debugging',
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading RME questions...'),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _rmeQuestions.isNotEmpty ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(
                    color: _rmeQuestions.isNotEmpty ? Colors.green : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _rmeQuestions.isNotEmpty ? Icons.check_circle : Icons.error,
                          color: _rmeQuestions.isNotEmpty ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Found ${_rmeQuestions.length} RME Questions',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _rmeQuestions.isNotEmpty ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                    if (_rmeQuestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Questions imported successfully from Firestore!',
                        style: GoogleFonts.montserrat(
                          color: Colors.green.shade700,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'No RME questions found in the database. Please check the import.',
                        style: GoogleFonts.montserrat(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              if (_rmeQuestions.isNotEmpty) ...[
                Text(
                  'Sample Questions:',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: _rmeQuestions.length,
                    itemBuilder: (context, index) {
                      final question = _rmeQuestions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Q${question.questionNumber}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${question.examType.name.toUpperCase()} ${question.year}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                question.questionText,
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...(question.options ?? []).map((option) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  option,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: option == question.correctAnswer 
                                        ? Colors.green.shade700 
                                        : Colors.grey.shade700,
                                    fontWeight: option == question.correctAnswer 
                                        ? FontWeight.w600 
                                        : FontWeight.normal,
                                  ),
                                ),
                              )).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}