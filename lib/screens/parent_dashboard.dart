import 'package:flutter/material.dart';

class ParentDashboardPage extends StatelessWidget {
  const ParentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildStudentOverviewCard(),
            const SizedBox(height: 24),
            _buildWeeklyReportCard(),
            const SizedBox(height: 24),
            _buildPerformanceHeatmapCard(),
            const SizedBox(height: 24),
            _buildNotificationsCard(),
            const SizedBox(height: 24),
            _buildMotivationalMessageCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentOverviewCard() {
    final students = [
      {
        'name': 'Ama Mensah',
        'avatar': 'A',
        'progress': 'Math: 85%, English: 78%',
      },
      {
        'name': 'Kwame Boateng',
        'avatar': 'K',
        'progress': 'Biology: 92%, Physics: 80%',
      },
    ];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.school, color: Color(0xFFD62828)),
                SizedBox(width: 8),
                Text('Student Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...students.map((student) => ListTile(
              leading: CircleAvatar(child: Text(student['avatar'] as String)),
              title: Text(student['name'] as String),
              subtitle: Text(student['progress'] as String),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyReportCard() {
    final reports = [
      {
        'name': 'Ama Mensah',
        'improved': 'Math (+7%), English (+4%)',
        'focus': 'Needs more practice in Science',
      },
      {
        'name': 'Kwame Boateng',
        'improved': 'Biology (+5%), Physics (+3%)',
        'focus': 'Focus on essay writing',
      },
    ];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.bar_chart, color: Color(0xFFD62828)),
                SizedBox(width: 8),
                Text('Weekly AI Progress Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...reports.map((report) => ListTile(
              leading: CircleAvatar(child: Text((report['name'] as String)[0])),
              title: Text(report['name'] as String),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Improved: ${report['improved']}'),
                  Text('Focus: ${report['focus']}'),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceHeatmapCard() {
    final heatmap = [
      {
        'name': 'Ama Mensah',
        'strengths': ['Math', 'English'],
        'weaknesses': ['Science'],
      },
      {
        'name': 'Kwame Boateng',
        'strengths': ['Biology', 'Physics'],
        'weaknesses': ['Literature'],
      },
    ];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.grid_on, color: Color(0xFFD62828)),
                SizedBox(width: 8),
                Text('Performance Heatmap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...heatmap.map((student) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Strengths: '),
                    ...List<Widget>.from((student['strengths'] as List).map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Chip(label: Text(s), backgroundColor: Colors.green[100]),
                    ))),
                  ],
                ),
                Row(
                  children: [
                    const Text('Weaknesses: '),
                    ...List<Widget>.from((student['weaknesses'] as List).map((w) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Chip(label: Text(w), backgroundColor: Colors.red[100]),
                    ))),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    final notifications = [
      'Ama completed a Math quiz with 90%.',
      'Kwame unlocked the "Quiz Master" badge.',
      'Ama started Calm Mode session.',
      'Kwame submitted Biology assignment.',
    ];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.notifications, color: Color(0xFFD62828)),
                SizedBox(width: 8),
                Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...notifications.map((note) => ListTile(
              leading: const Icon(Icons.circle, size: 12, color: Color(0xFFD62828)),
              title: Text(note),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationalMessageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.emoji_emotions, color: Color(0xFFD62828)),
        title: const Text('Motivational Messages'),
        subtitle: const Text('Encourage your child with positive feedback'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {},
      ),
    );
  }
}
