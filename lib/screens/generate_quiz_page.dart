import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
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

              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmall ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    Text('When you click Generate the questions and answers will be shown in a printable view.', style: GoogleFonts.montserrat()),
                    const SizedBox(height: 12),
                    _isGenerating
                        ? const CircularProgressIndicator(color: Color(0xFFD62828))
                        : ElevatedButton.icon(
                            onPressed: _generateAndShowQuestions,
                            icon: const Icon(Icons.auto_stories),
                            label: Text('Generate', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD62828), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
            buffer.writeln('   ${String.fromCharCode(65 + j)}. ${q.options![j]}');
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
            title: Row(children: [
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
                            (j) => Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 2),
                              child: Text('${String.fromCharCode(65 + j)}. ${q.options![j]}', style: GoogleFonts.montserrat()),
                            ),
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
