import 'dart:async';
import 'package:flutter/material.dart';

class QuestionDetailPage extends StatelessWidget {
  final String question;
  final String subject;
  final String year;
  const QuestionDetailPage({super.key, required this.question, required this.subject, required this.year});

  @override
  Widget build(BuildContext context) {
    return _QuestionSessionView(question: question, subject: subject, year: year);
  }
}

class _QuestionSessionView extends StatefulWidget {
  final String question;
  final String subject;
  final String year;
  const _QuestionSessionView({required this.question, required this.subject, required this.year});

  @override
  State<_QuestionSessionView> createState() => _QuestionSessionViewState();
}

class _QuestionSessionViewState extends State<_QuestionSessionView> {
  int _remainingSeconds = 60 * 5; // 5 minutes per question
  Timer? _timer;
  bool _submitted = false;
  String _answer = '';
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
              content: const Text('You have 1 minute remaining. Please submit your answer soon.'),
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
              content: const Text('Your time for this question has ended. Submitting your answer now.'),
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
        title: const Text('Question Detail'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _submitted ? _buildResult() : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subject: ${widget.subject}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Year: ${widget.year}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.timer, color: Color(0xFFD62828)),
            const SizedBox(width: 8),
            Text('Time Left: ${_formatTime(_remainingSeconds)}', style: const TextStyle(fontSize: 16, color: Color(0xFFD62828))),
          ],
        ),
        const SizedBox(height: 24),
        Text(widget.question, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Your answer...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _answer = value;
          },
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _submitted = true;
            });
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Submit Answer'),
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
        const Text('Answer Submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text('Your answer: ${_answer.isEmpty ? "Not answered" : _answer}'),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Return to Questions'),
        ),
      ],
    );
  }
}
