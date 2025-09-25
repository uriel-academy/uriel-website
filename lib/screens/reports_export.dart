import 'package:flutter/material.dart';

class ReportsExportPage extends StatelessWidget {
  const ReportsExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      {'title': 'Student Performance Report', 'date': '2025-09-10'},
      {'title': 'Subscription Summary', 'date': '2025-09-01'},
      {'title': 'Teacher Feedback Log', 'date': '2025-08-28'},
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Reports'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.file_present, color: Color(0xFFD62828)),
                    title: Text(reports[i]['title'] as String),
                    subtitle: Text('Date: ${reports[i]['date']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download, color: Color(0xFF1A1E3F)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Download Report'),
                            content: Text('Download ${reports[i]['title']}?'),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Download'))],
                          ),
                        );
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
