import 'package:flutter/material.dart';

class CommunityModerationPage extends StatefulWidget {
  const CommunityModerationPage({super.key});

  @override
  State<CommunityModerationPage> createState() => _CommunityModerationPageState();
}

class _CommunityModerationPageState extends State<CommunityModerationPage> {
  final List<Map<String, dynamic>> _posts = [
    {
      'user': 'Ama Owusu',
      'content': 'Can someone explain quadratic equations?',
      'flagged': false,
      'timestamp': 'Today, 10:05',
    },
    {
      'user': 'Kofi Mensah',
      'content': 'This app is awesome! Thanks Uriel.',
      'flagged': false,
      'timestamp': 'Yesterday, 18:22',
    },
    {
      'user': 'Akua Boateng',
      'content': 'Spam link: www.fake.com',
      'flagged': true,
      'timestamp': 'Yesterday, 15:10',
    },
    {
      'user': 'School Admin',
      'content': 'Reminder: Mock exams start next week.',
      'flagged': false,
      'timestamp': '2 days ago',
    },
  ];

  void _showModerationDialog(int index) {
    final post = _posts[index];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Moderate Post'),
          content: Text('User: ${post['user']}\n\nContent: ${post['content']}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _posts.removeAt(index);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  post['flagged'] = false;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Unflag'),
            ),
          ],
        );
            // Removed dead code and unused local variables
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Moderation'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            final post = _posts[index];
            return Card(
              elevation: post['flagged'] ? 4 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: post['flagged'] ? Colors.red : Colors.blue,
                  child: Icon(post['flagged'] ? Icons.flag : Icons.person, color: Colors.white),
                ),
                title: Text(post['user'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['content']),
                    const SizedBox(height: 4),
                    Text(post['timestamp'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: post['flagged']
                    ? IconButton(
                        icon: const Icon(Icons.gavel, color: Colors.red),
                        onPressed: () => _showModerationDialog(index),
                        tooltip: 'Moderate',
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
