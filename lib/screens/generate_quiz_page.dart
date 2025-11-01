import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';

class GenerateQuizPage extends StatefulWidget {
  const GenerateQuizPage({Key? key}) : super(key: key);

  @override
  State<GenerateQuizPage> createState() => _GenerateQuizPageState();
}

class _GenerateQuizPageState extends State<GenerateQuizPage> {
  final QuestionService _questionService = QuestionService();

  ExamType? _selectedExamType;
  Subject? _selectedSubject;
  int _selectedQuestionCount = 10;
  bool _isGenerating = false;
  bool _useAIGeneration = false;
  final TextEditingController _customTopicController = TextEditingController();

  @override
  void dispose() {
    _customTopicController.dispose();
    super.dispose();
  }

  final List<ExamType> _availableExamTypes = [ExamType.bece, ExamType.wassce];
  final List<Subject> _availableSubjects = [Subject.ict, Subject.religiousMoralEducation];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmall ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Generate Quiz', style: GoogleFonts.playfairDisplay(fontSize: isSmall ? 28 : 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Generate printable questions with answers for your students', style: GoogleFonts.montserrat(color: Colors.grey[600])),
              SizedBox(height: isSmall ? 20 : 28),

              _buildSelectionCard(
                title: 'Generate Questions',
                subtitle: 'Choose exam type, subject and how many questions to generate',
                child: _buildSelector(isSmall),
                isSmallScreen: isSmall,
              ),

              const SizedBox(height: 20),

              // AI Generation Toggle
              Container(
                padding: EdgeInsets.all(isSmall ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade50,
                      Colors.deepPurple.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _useAIGeneration ? Colors.purple : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: _useAIGeneration ? Colors.white : Colors.grey.shade600,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI-Generated Questions',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _useAIGeneration 
                                    ? 'Questions will be created by AI based on your criteria'
                                    : 'Questions will be selected from the question bank',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _useAIGeneration,
                          onChanged: (value) {
                            setState(() {
                              _useAIGeneration = value;
                            });
                          },
                          activeColor: Colors.purple,
                        ),
                      ],
                    ),
                    
                    // Custom topic input when AI mode is enabled
                    if (_useAIGeneration) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom Topic (Optional)',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customTopicController,
                            decoration: InputDecoration(
                              hintText: 'e.g., Photosynthesis in plants, Quadratic equations, Computer networks',
                              hintStyle: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.purple, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmall ? 20 : 24),
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
                    Text('When you click Generate the questions and answers will be shown in a printable view.', style: GoogleFonts.montserrat()),
                    const SizedBox(height: 12),
                    _isGenerating
                        ? Column(
                            children: [
                              const CircularProgressIndicator(color: Color(0xFFD62828)),
                              const SizedBox(height: 12),
                              Text(
                                _useAIGeneration ? 'AI is generating questions...' : 'Loading questions...',
                                style: GoogleFonts.montserrat(color: Colors.grey[600]),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _generateAndShowQuestions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _useAIGeneration ? Colors.purple : const Color(0xFF2ECC71),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_useAIGeneration) ...[
                                  const Icon(Icons.auto_awesome, size: 20),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _useAIGeneration ? 'Generate with AI' : 'Generate Quiz',
                                  style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({required String title, required String subtitle, required Widget child, required bool isSmallScreen}) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle, style: GoogleFonts.montserrat(color: Colors.grey[600])),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _buildSelector(bool isSmall) {
    if (isSmall) {
      return Column(children: [
        _buildDropdown('Exam Type', _selectedExamType?.name.toUpperCase() ?? 'Select Type', _getExamTypeOptions(), (v) => setState(() => _selectedExamType = v == 'Select Type' ? null : ExamType.values.firstWhere((e) => e.name.toUpperCase() == v))),
        const SizedBox(height: 10),
        _buildDropdown('Subject', _selectedSubject != null ? _getSubjectDisplayName(_selectedSubject!) : 'Select Subject', _getSubjectOptions(), (v) => setState(() => _selectedSubject = v == 'Select Subject' ? null : _availableSubjects.firstWhere((s) => _getSubjectDisplayName(s) == v))),
        const SizedBox(height: 10),
        _buildDropdown('Count', _selectedQuestionCount.toString(), ['5','10','20','40'], (v) => setState(() => _selectedQuestionCount = int.parse(v!))),
      ]);
    }

    return Row(children: [
      Expanded(child: _buildDropdown('Exam Type', _selectedExamType?.name.toUpperCase() ?? 'Select Type', _getExamTypeOptions(), (v) => setState(() => _selectedExamType = v == 'Select Type' ? null : ExamType.values.firstWhere((e) => e.name.toUpperCase() == v)))),
      const SizedBox(width: 12),
      Expanded(child: _buildDropdown('Subject', _selectedSubject != null ? _getSubjectDisplayName(_selectedSubject!) : 'Select Subject', _getSubjectOptions(), (v) => setState(() => _selectedSubject = v == 'Select Subject' ? null : _availableSubjects.firstWhere((s) => _getSubjectDisplayName(s) == v)))),
      const SizedBox(width: 12),
      SizedBox(width: 140, child: _buildDropdown('Count', _selectedQuestionCount.toString(), ['5','10','20','40'], (v) => setState(() => _selectedQuestionCount = int.parse(v!)))),
    ]);
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFE), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
    );
  }

  List<String> _getExamTypeOptions() => ['Select Type', ..._availableExamTypes.map((e) => e.name.toUpperCase())];
  List<String> _getSubjectOptions() => ['Select Subject', ..._availableSubjects.map((s) => _getSubjectDisplayName(s))];

  String _getSubjectDisplayName(Subject s) {
    switch (s) {
      case Subject.ict: return 'ICT';
      case Subject.religiousMoralEducation: return 'RME';
      default: return s.name;
    }
  }

  Future<void> _generateAndShowQuestions() async {
    if (_selectedExamType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select exam type and subject'), backgroundColor: Color(0xFFD62828)));
      return;
    }

    setState(() => _isGenerating = true);
    try {
      List<Question> selected;

      if (_useAIGeneration) {
        // AI Generation Mode
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        final callable = functions.httpsCallable('generateAIQuiz');
        
        final subjectName = _getSubjectDisplayName(_selectedSubject!);
        final examTypeName = _selectedExamType!.name.toUpperCase();
        final customTopic = _customTopicController.text.trim();
        
        final result = await callable.call({
          'subject': subjectName,
          'examType': examTypeName,
          'numQuestions': _selectedQuestionCount,
          'customTopic': customTopic.isEmpty ? null : customTopic,
        });

        if (!mounted) return;

        final data = result.data as Map<String, dynamic>;
        final questionsData = List<Map<String, dynamic>>.from(data['questions'] as List);
        
        // Convert AI questions to Question model format
        selected = questionsData.map((q) {
          final index = questionsData.indexOf(q);
          return Question(
            id: 'ai_${DateTime.now().millisecondsSinceEpoch}_$index',
            questionText: q['question'] as String,
            type: QuestionType.multipleChoice,
            subject: _selectedSubject!,
            examType: _selectedExamType!,
            year: 'AI-Generated',
            section: 'AI',
            questionNumber: index + 1,
            options: List<String>.from(q['options'].values),
            correctAnswer: q['correctAnswer'] as String,
            explanation: q['explanation'] as String? ?? '',
            marks: 1,
            difficulty: q['difficulty'] as String? ?? 'medium',
            topics: customTopic.isEmpty ? ['General'] : [customTopic],
            createdAt: DateTime.now(),
            createdBy: 'AI',
            isActive: true,
          );
        }).toList();

        // Show AI success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('✨ AI generated ${selected.length} questions successfully!'),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Question Bank Mode
        final all = await _questionService.getQuestionsByFilters(examType: _selectedExamType, subject: _selectedSubject, limit: 500, activeOnly: true);
        if (!mounted) return;
        if (all.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No questions available for selection'), backgroundColor: Color(0xFFD62828)));
          return;
        }

        // shuffle and take desired count
        final list = List<Question>.from(all)..shuffle();
        selected = list.take(_selectedQuestionCount.clamp(1, all.length)).toList();
      }

      // Build copyable strings
      final buffer = StringBuffer();
      for (var i = 0; i < selected.length; i++) {
        final q = selected[i];
        buffer.writeln('Q${i+1}. ${q.questionText}');
        if (q.options != null && q.options!.isNotEmpty) {
          for (var j = 0; j < q.options!.length; j++) {
            final rawOpt = q.options![j];
            // Remove any existing leading letter prefix like "A. " to avoid duplication
            final cleaned = rawOpt.replaceFirst(RegExp(r'^[A-Za-z]\.[\s]*'), '');
            buffer.writeln('   ${String.fromCharCode(65 + j)}. $cleaned');
          }
        }
        buffer.writeln('Answer: ${q.correctAnswer}');
        buffer.writeln();
      }

      // Show dialog with results and copy controls
      // Capture messenger and clipboard handling to avoid using BuildContext across async gaps
      final messenger = ScaffoldMessenger.of(context);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            scrollable: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Generated Questions', style: GoogleFonts.playfairDisplay()),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: buffer.toString()));
                      messenger.showSnackBar(const SnackBar(content: Text('All questions copied to clipboard')));
                    },
                  )
                ]),
                if (_useAIGeneration) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade600],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _customTopicController.text.trim().isEmpty
                              ? 'AI Generated'
                              : 'AI: ${_customTopicController.text.trim()}',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: 640,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(selected.length, (i) {
                    final q = selected[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('Q${i+1}. ${q.questionText}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600))),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: q.questionText));
                              messenger.showSnackBar(const SnackBar(content: Text('Question copied')));
                            },
                          )
                        ]),
                        if (q.options != null && q.options!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...List.generate(
                            q.options!.length,
                            (j) {
                              final rawOpt = q.options![j];
                              final cleaned = rawOpt.replaceFirst(RegExp(r'^[A-Za-z]\.[\s]*'), '');
                              return Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 2),
                                child: Text('${String.fromCharCode(65 + j)}. $cleaned', style: GoogleFonts.montserrat()),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: Text('Answer: ${q.correctAnswer}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600))),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: q.correctAnswer));
                              messenger.showSnackBar(const SnackBar(content: Text('Answer copied')));
                            },
                          )
                        ]),
                        const Divider()
                      ]),
                    );
                  }),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('Close', style: GoogleFonts.montserrat()))],
          );
        },
      );
    } catch (e) {
      debugPrint('Error generating questions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error generating questions'), backgroundColor: Color(0xFFD62828)));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
