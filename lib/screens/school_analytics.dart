import 'package:flutter/material.dart';

class SchoolAnalyticsPage extends StatelessWidget {
  const SchoolAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final analytics = [
      {'metric': 'Average Score', 'value': '82%'},
      {'metric': 'Active Students', 'value': '320'},
      {'metric': 'Completed Quizzes', 'value': '1,200'},
      {'metric': 'Top Subject', 'value': 'Math'},
      {'metric': 'Most Improved', 'value': 'English'},
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Analytics'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Key Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: analytics.length,
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.bar_chart, color: Color(0xFFD62828)),
                    title: Text(analytics[i]['metric'] as String),
                    trailing: Text(analytics[i]['value'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Performance Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Math scores have increased by 5% this term.'),
                    SizedBox(height: 8),
                    Text('English participation up 12% compared to last month.'),
                    SizedBox(height: 8),
                    Text('Science quiz completion rate steady at 78%.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
