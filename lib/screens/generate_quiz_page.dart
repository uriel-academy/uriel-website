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
  final TextEditingController _topicController = TextEditingController();

  ExamType? _selectedExamType;
  Subject? _selectedSubject;
  int _selectedQuestionCount = 10;
  bool _isGenerating = false;
  bool _isGeneratingAI = false;
  bool _useAIGeneration = false; // Toggle between database and AI
  
  // AI-specific options
  String _selectedDifficulty = 'medium';
  String _selectedClassLevel = 'JHS 3';

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  final List<ExamType> _availableExamTypes = [ExamType.bece, ExamType.wassce];
  final List<Subject> _availableSubjects = [
    Subject.mathematics,
    Subject.english,
    Subject.integratedScience,
    Subject.socialStudies,
    Subject.ga,
    Subject.asanteTwi,
    Subject.french,
    Subject.ict,
    Subject.religiousMoralEducation,
    Subject.creativeArts,
  ];
  final List<String> _difficultyLevels = ['easy', 'medium', 'difficult'];
  final List<String> _classLevels = ['JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3'];

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

              SizedBox(height: isSmall ? 20 : 28),

              // AI Generation Options (shown when AI toggle is on)
              if (_useAIGeneration) ...[
                _buildSelectionCard(
                  title: 'AI Generation Options',
                  subtitle: 'Customize your AI-generated questions',
                  child: _buildAIOptionsSelector(isSmall),
                  isSmallScreen: isSmall,
                ),
                SizedBox(height: isSmall ? 20 : 28),
              ],

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
                    // Toggle between Database and AI
                    Column(
                      children: [
                        Text(
                          'Question Source:',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ChoiceChip(
                              label: Text('Database', style: GoogleFonts.montserrat()),
                              selected: !_useAIGeneration,
                              onSelected: (selected) {
                                if (selected) setState(() => _useAIGeneration = false);
                              },
                              selectedColor: const Color(0xFF2ECC71),
                              backgroundColor: Colors.grey[200],
                              labelStyle: TextStyle(
                                color: !_useAIGeneration ? Colors.white : Colors.black87,
                              ),
                            ),
                            ChoiceChip(
                              label: Text('AI Generated', style: GoogleFonts.montserrat()),
                              selected: _useAIGeneration,
                              onSelected: (selected) {
                                if (selected) setState(() => _useAIGeneration = true);
                              },
                              selectedColor: const Color(0xFFD62828),
                              backgroundColor: Colors.grey[200],
                              labelStyle: TextStyle(
                                color: _useAIGeneration ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Info text
                    Text(
                      _useAIGeneration 
                        ? 'AI will generate fresh questions based on BECE/NACCA standards'
                        : 'Questions will be selected from the question bank',
                      style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Generate button
                    (_isGenerating || _isGeneratingAI)
                        ? Column(
                            children: [
                              CircularProgressIndicator(
                                color: _useAIGeneration ? const Color(0xFFD62828) : const Color(0xFF2ECC71),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _useAIGeneration ? 'AI is generating questions...' : 'Loading questions...',
                                style: GoogleFonts.montserrat(color: Colors.grey[600]),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: _useAIGeneration ? _generateAIQuestions : _generateAndShowQuestions,
                            icon: Icon(_useAIGeneration ? Icons.auto_awesome : Icons.folder_open, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _useAIGeneration ? const Color(0xFFD62828) : const Color(0xFF2ECC71),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            label: Text(
                              _useAIGeneration ? 'Generate with AI' : 'Generate from Database',
                              style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildAIOptionsSelector(bool isSmall) {
    return Column(
      children: [
        // Topic input field
        TextField(
          controller: _topicController,
          decoration: InputDecoration(
            labelText: 'Topic (Optional)',
            hintText: 'e.g., Arrays and Loops, Prayer Times, etc.',
            filled: true,
            fillColor: const Color(0xFFF8FAFE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        
        // Difficulty and Class Level dropdowns
        if (isSmall) ...[
          _buildDropdown(
            'Difficulty',
            _selectedDifficulty,
            _difficultyLevels,
            (v) => setState(() => _selectedDifficulty = v!),
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            'Class Level',
            _selectedClassLevel,
            _classLevels,
            (v) => setState(() => _selectedClassLevel = v!),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  'Difficulty',
                  _selectedDifficulty,
                  _difficultyLevels,
                  (v) => setState(() => _selectedDifficulty = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  'Class Level',
                  _selectedClassLevel,
                  _classLevels,
                  (v) => setState(() => _selectedClassLevel = v!),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<String> _getExamTypeOptions() => ['Select Type', ..._availableExamTypes.map((e) => e.name.toUpperCase())];
  List<String> _getSubjectOptions() => ['Select Subject', ..._availableSubjects.map((s) => _getSubjectDisplayName(s))];

  String _getSubjectDisplayName(Subject s) {
    switch (s) {
      case Subject.mathematics: return 'Mathematics';
      case Subject.english: return 'English';
      case Subject.integratedScience: return 'Integrated Science';
      case Subject.socialStudies: return 'Social Studies';
      case Subject.ga: return 'Ga';
      case Subject.asanteTwi: return 'Asante Twi';
      case Subject.french: return 'French';
      case Subject.ict: return 'ICT';
      case Subject.religiousMoralEducation: return 'RME';
      case Subject.creativeArts: return 'Creative Arts';
      case Subject.trivia: return 'Trivia';
    }
  }

  Future<void> _generateAIQuestions() async {
    if (_selectedExamType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select exam type and subject'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() => _isGeneratingAI = true);

    try {
      final customTopic = _topicController.text.trim();
      debugPrint('📝 Calling generateAIQuiz with params: subject=${_selectedSubject!.name}, examType=${_selectedExamType!.name}, count=$_selectedQuestionCount, difficulty=$_selectedDifficulty, classLevel=$_selectedClassLevel, topic=$customTopic');
      
      final callable = FirebaseFunctions.instance.httpsCallable('generateAIQuiz');
      final result = await callable.call({
        'subject': _selectedSubject!.name,
        'examType': _selectedExamType!.name,
        'numQuestions': _selectedQuestionCount, // Changed from questionCount to numQuestions
        'difficultyLevel': _selectedDifficulty,
        'classLevel': _selectedClassLevel,
        'customTopic': customTopic.isNotEmpty ? customTopic : null,
      });

      final data = result.data;
      if (data['success'] != true || data['questions'] == null) {
        throw Exception('Invalid response from AI service');
      }

      // Convert AI-generated questions to Question objects with proper formatting
      final List<Question> aiQuestions = [];
      for (var i = 0; i < (data['questions'] as List).length; i++) {
        final q = data['questions'][i];
        
        // Convert options object to list with letter prefixes (A., B., C., D.)
        final optionsMap = q['options'] as Map<String, dynamic>;
        final optionsList = <String>[
          'A. ${optionsMap['A']?.toString() ?? ''}',
          'B. ${optionsMap['B']?.toString() ?? ''}',
          'C. ${optionsMap['C']?.toString() ?? ''}',
          'D. ${optionsMap['D']?.toString() ?? ''}',
        ];

        // Get the correct answer letter (A, B, C, or D)
        String correctAnswerLetter = (q['correctAnswer'] ?? 'A').toString().toUpperCase();
        // Extract just the letter if it contains a period (e.g., "A." or "A. Text")
        if (correctAnswerLetter.contains('.')) {
          correctAnswerLetter = correctAnswerLetter.split('.')[0].trim();
        }
        // Ensure it's a single letter
        if (correctAnswerLetter.length > 1) {
          correctAnswerLetter = correctAnswerLetter.substring(0, 1);
        }
        
        // Build the full correct answer in the format "A. answer text"
        String correctAnswerFull = optionsList.firstWhere(
          (opt) => opt.startsWith('$correctAnswerLetter.'),
          orElse: () => optionsList[0],
        );
        
        debugPrint('✅ AI Question ${i+1}: correctAnswer="$correctAnswerFull", options=${optionsList.length}');
        
        aiQuestions.add(Question(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}_$i',
          questionText: q['question'] ?? '',
          type: QuestionType.multipleChoice,
          subject: _selectedSubject!,
          examType: _selectedExamType!,
          year: DateTime.now().year.toString(),
          section: 'AI Generated',
          questionNumber: i + 1,
          options: optionsList,
          correctAnswer: correctAnswerFull,
          explanation: q['explanation'],
          marks: 1,
          difficulty: q['difficulty'] ?? _selectedDifficulty,
          topics: [q['topic'] ?? (customTopic.isNotEmpty ? customTopic : 'General')],
          createdAt: DateTime.now(),
          createdBy: 'ai',
          isActive: true,
        ));
      }

      if (aiQuestions.isEmpty) {
        throw Exception('No questions generated');
      }

      // Show the AI-generated questions in a dialog
      if (!mounted) return;
      await _showGeneratedQuestionsDialog(aiQuestions);
      
    } catch (e) {
      debugPrint('Error generating AI questions: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating AI questions: ${e.toString()}'),
          backgroundColor: const Color(0xFFD62828),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAI = false);
      }
    }
  }

  Future<void> _generateAndShowQuestions() async {
    if (_selectedExamType == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select exam type and subject'), backgroundColor: Color(0xFFD62828)));
      return;
    }

    setState(() => _isGenerating = true);
    try {
      // Question Bank Mode
      final all = await _questionService.getQuestionsByFilters(examType: _selectedExamType, subject: _selectedSubject, limit: 500, activeOnly: true);
      if (!mounted) return;
      if (all.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No questions available for selection'), backgroundColor: Color(0xFFD62828)));
        return;
      }

      // shuffle and take desired count
      final list = List<Question>.from(all)..shuffle();
      final selected = list.take(_selectedQuestionCount.clamp(1, all.length)).toList();

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
      await _showGeneratedQuestionsDialog(selected);
    } catch (e) {
      debugPrint('Error generating questions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error generating questions'), backgroundColor: Color(0xFFD62828)));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _showGeneratedQuestionsDialog(List<Question> questions) async {
    // Build copyable strings
    final buffer = StringBuffer();
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
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
              ],
            ),
            content: SizedBox(
              width: 640,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...List.generate(questions.length, (i) {
                    final q = questions[i];
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
  }
}
