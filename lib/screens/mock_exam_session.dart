import 'package:flutter/material.dart';
import 'dart:async';

class MockExamSessionPage extends StatefulWidget {
  final String examTitle;
  final String subject;
  final String duration;
  const MockExamSessionPage({super.key, required this.examTitle, required this.subject, required this.duration});

  @override
  State<MockExamSessionPage> createState() => _MockExamSessionPageState();
}

class _MockExamSessionPageState extends State<MockExamSessionPage> {
  int _currentQuestion = 0;
  final List<String> _questions = [
    'What is 2 + 2?',
    'Define photosynthesis.',
    'Who wrote Macbeth?',
    'What is the capital of Ghana?',
    'Solve for x: 2x + 3 = 7.',
  ];
  final Map<int, String> _answers = {};
  bool _submitted = false;
  int _remainingSeconds = 60 * 60; // 60 minutes default
  Timer? _timer;
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0 && !_submitted) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds == 60 && !_warningShown) {
          _warningShown = true;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('1 Minute Left!'),
              content: const Text('You have 1 minute remaining. Please submit your answers soon.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        timer.cancel();
        if (!_submitted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Time Up!'),
              content: const Text('Your exam time has ended. Submitting your answers now.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _submitted = true;
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examTitle),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _submitted ? _buildResult() : _buildExam(),
      ),
    );
  }

  Widget _buildExam() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject: ${widget.subject}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Duration: ${widget.duration}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.timer, color: Color(0xFFD62828)),
            const SizedBox(width: 8),
            Text('Time Left: ${_formatTime(_remainingSeconds)}', style: const TextStyle(fontSize: 16, color: Color(0xFFD62828))),
          ],
        ),
        const SizedBox(height: 24),
        Text('Question ${_currentQuestion + 1} of ${_questions.length}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Text(_questions[_currentQuestion], style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Your answer...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _answers[_currentQuestion] = value;
          },
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _currentQuestion > 0 ? () {
                setState(() {
                  _currentQuestion--;
                });
              } : null,
              child: const Text('Previous'),
            ),
            ElevatedButton(
              onPressed: _currentQuestion < _questions.length - 1 ? () {
                setState(() {
                  _currentQuestion++;
                });
              } : null,
              child: const Text('Next'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _submitted = true;
            });
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Submit Exam'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD62828),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Exam Submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text('You answered ${_answers.length} out of ${_questions.length} questions.'),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _questions.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(_questions[i]),
              subtitle: Text('Your answer: ${_answers[i] ?? "Not answered"}'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Return to Dashboard'),
        ),
      ],
    );
  }
}
