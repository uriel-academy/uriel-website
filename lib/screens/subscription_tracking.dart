import 'package:flutter/material.dart';

class SubscriptionTrackingPage extends StatelessWidget {
  const SubscriptionTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptions = [
      {'school': 'St. Mary School', 'students': 120, 'commission': 'GHS 500'},
      {'school': 'Bright Future Academy', 'students': 80, 'commission': 'GHS 320'},
      {'school': 'Unity College', 'students': 150, 'commission': 'GHS 600'},
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription & Commission Tracking'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('School Subscriptions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: subscriptions.length,
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.school, color: Color(0xFFD62828)),
                    title: Text(subscriptions[i]['school'] as String),
                    subtitle: Text('Students: ${(subscriptions[i]['students'] as int).toString()}'),
                    trailing: Text('Commission: ${subscriptions[i]['commission'] as String}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
