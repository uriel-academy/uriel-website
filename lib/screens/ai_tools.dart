import 'package:flutter/material.dart';

class AIToolsPage extends StatelessWidget {
  final VoidCallback? onAIToolUsed;
  const AIToolsPage({super.key, this.onAIToolUsed});

  @override
  Widget build(BuildContext context) {
    final tools = [
      {'name': 'Instant Question Solver', 'icon': Icons.question_answer, 'desc': 'Get instant solutions to any question.'},
      {'name': 'Revision Planner', 'icon': Icons.calendar_today, 'desc': 'Personalized revision plans for exams.'},
      {'name': 'Summary Generator', 'icon': Icons.summarize, 'desc': 'Summarize textbooks and notes.'},
      {'name': 'Voice Input', 'icon': Icons.mic, 'desc': 'Ask questions by speaking.'},
      {'name': 'Multilingual Support', 'icon': Icons.language, 'desc': 'Learn in English, Twi, Ewe, and more.'},
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tools Hub'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: tools.length,
          itemBuilder: (context, i) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Icon(tools[i]['icon'] as IconData, color: const Color(0xFFD62828)),
              title: Text(tools[i]['name'] as String),
              subtitle: Text(tools[i]['desc'] as String),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                if (onAIToolUsed != null) onAIToolUsed!();
                if (tools[i]['name'] == 'Instant Question Solver') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InstantQuestionSolverPage()));
                } else if (tools[i]['name'] == 'Summary Generator') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryGeneratorPage()));
                } else {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(tools[i]['name'] as String),
                      content: Text(tools[i]['desc'] as String),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class InstantQuestionSolverPage extends StatefulWidget {
  const InstantQuestionSolverPage({super.key});
  @override
  State<InstantQuestionSolverPage> createState() => _InstantQuestionSolverPageState();
}

class _InstantQuestionSolverPageState extends State<InstantQuestionSolverPage> {
  final TextEditingController _controller = TextEditingController();
  String _answer = '';
  bool _loading = false;

  void _solveQuestion() async {
    setState(() { _loading = true; });
    await Future.delayed(const Duration(seconds: 2)); // Simulate AI call
    setState(() {
      _answer = 'AI Answer: The solution to your question is 4.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instant Question Solver'), backgroundColor: const Color(0xFF1A1E3F)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your question:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'e.g. What is 2 + 2?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _solveQuestion,
              child: _loading ? const CircularProgressIndicator() : const Text('Solve'),
            ),
            const SizedBox(height: 24),
            if (_answer.isNotEmpty)
              Card(
                color: const Color(0xFFF0F0F0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_answer, style: const TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SummaryGeneratorPage extends StatefulWidget {
  const SummaryGeneratorPage({super.key});
  @override
  State<SummaryGeneratorPage> createState() => _SummaryGeneratorPageState();
}

class _SummaryGeneratorPageState extends State<SummaryGeneratorPage> {
  final TextEditingController _controller = TextEditingController();
  String _summary = '';
  bool _loading = false;

  void _generateSummary() async {
    setState(() { _loading = true; });
    await Future.delayed(const Duration(seconds: 2)); // Simulate AI call
    setState(() {
      _summary = 'AI Summary: This topic covers the basics of addition.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Summary Generator'), backgroundColor: const Color(0xFF1A1E3F)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste textbook or notes:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Paste content here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _generateSummary,
              child: _loading ? const CircularProgressIndicator() : const Text('Generate Summary'),
            ),
            const SizedBox(height: 24),
            if (_summary.isNotEmpty)
              Card(
                color: const Color(0xFFF0F0F0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_summary, style: const TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
