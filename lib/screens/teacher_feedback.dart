import 'package:flutter/material.dart';

class TeacherFeedbackPage extends StatelessWidget {
  const TeacherFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final feedbacks = [
      {
        'teacher': 'Mrs. Adjei',
        'message': 'Ama is showing great improvement in Math. Keep encouraging her to practice daily.'
      },
      {
        'teacher': 'Mr. Mensah',
        'message': 'Kwame needs to participate more in class discussions. He has potential in Physics.'
      },
      {
        'teacher': 'Ms. Owusu',
        'message': 'Esi is excelling in Biology. Consider enrolling her in the science club.'
      },
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Feedback'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: feedbacks.length,
          itemBuilder: (context, i) => Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.person, color: Color(0xFFD62828)),
              title: Text(feedbacks[i]['teacher'] as String),
              subtitle: Text(feedbacks[i]['message'] as String),
              trailing: IconButton(
                icon: const Icon(Icons.reply, color: Color(0xFF1A1E3F)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reply to Teacher'),
                      content: const TextField(
                        decoration: InputDecoration(hintText: 'Type your reply...'),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Send'))],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
