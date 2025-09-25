import 'package:flutter/material.dart';
import 'question_detail.dart';

class PastQuestionsPage extends StatelessWidget {
  final VoidCallback? onQuizCompleted;
  const PastQuestionsPage({super.key, this.onQuizCompleted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Questions'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by keyword, subject, or year...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                // TODO: Implement search logic
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 10, // TODO: Replace with filtered question count
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text('Question ${i + 1}'),
                    subtitle: const Text('Subject: Math | Year: 2023'),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuestionDetailPage(
                                question: 'What is 2 + 2?',
                                subject: 'Math',
                                year: '2023',
                              ),
                            ),
                          ).then((value) {
                            if (value == true && onQuizCompleted != null) {
                              onQuizCompleted!();
                            }
                          });
                        },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
