import 'package:flutter/material.dart';
import 'mock_exam_session.dart';

class MockExamDetailPage extends StatelessWidget {
  final String examTitle;
  final String subject;
  final String duration;
  const MockExamDetailPage({super.key, required this.examTitle, required this.subject, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(examTitle),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject: $subject', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Duration: $duration', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            const Text('Instructions:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Answer all questions. Time yourself. Submit when done.'),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MockExamSessionPage(
                      examTitle: examTitle,
                      subject: subject,
                      duration: duration,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Exam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
