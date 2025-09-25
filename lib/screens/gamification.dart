import 'package:flutter/material.dart';

class GamificationPage extends StatefulWidget {
  final int quizzesCompleted;
  final int textbooksRead;
  final int aiToolsUsed;
  final int calmModeActivated;
  const GamificationPage({super.key, required this.quizzesCompleted, required this.textbooksRead, required this.aiToolsUsed, required this.calmModeActivated});
  @override
  State<GamificationPage> createState() => _GamificationPageState();
}

class _GamificationPageState extends State<GamificationPage> {
  final List<Map<String, dynamic>> badges = [
    {'name': 'Quiz Master', 'icon': Icons.emoji_events, 'desc': 'Completed 10 quizzes.', 'unlocked': false},
    {'name': 'Bookworm', 'icon': Icons.menu_book, 'desc': 'Read 5 textbooks.', 'unlocked': false},
    {'name': 'AI Explorer', 'icon': Icons.psychology, 'desc': 'Used 3 AI tools.', 'unlocked': false},
    {'name': 'Calm Learner', 'icon': Icons.self_improvement, 'desc': 'Activated Calm Mode 5 times.', 'unlocked': false},
  ];
  late int quizzesCompleted;
  late int textbooksRead;
  late int aiToolsUsed;
  late int calmModeActivated;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    quizzesCompleted = widget.quizzesCompleted;
    textbooksRead = widget.textbooksRead;
    aiToolsUsed = widget.aiToolsUsed;
    calmModeActivated = widget.calmModeActivated;
  }

  void updateProgress({int? quizzes, int? textbooks, int? aiTools, int? calmMode}) {
    setState(() {
      if (quizzes != null) quizzesCompleted += quizzes;
      if (textbooks != null) textbooksRead += textbooks;
      if (aiTools != null) aiToolsUsed += aiTools;
      if (calmMode != null) calmModeActivated += calmMode;
      // Unlock badges based on thresholds
      if (quizzesCompleted >= 10) badges[0]['unlocked'] = true;
      if (textbooksRead >= 5) badges[1]['unlocked'] = true;
      if (aiToolsUsed >= 3) badges[2]['unlocked'] = true;
      if (calmModeActivated >= 5) badges[3]['unlocked'] = true;
    });
  }
  final leaderboard = [
    {'name': 'Ama', 'points': 1200},
    {'name': 'Kwame', 'points': 1100},
    {'name': 'Esi', 'points': 950},
    {'name': 'You', 'points': 900},
  ];

  // Removed unused _unlockBadge method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamification'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Your Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(badges.length, (i) => ActionChip(
                avatar: Icon(badges[i]['icon'] as IconData, color: badges[i]['unlocked'] ? Colors.green : const Color(0xFFD62828)),
                label: Text(badges[i]['name'] as String),
                backgroundColor: badges[i]['unlocked'] ? Colors.green[50] : const Color(0xFFF0F0F0),
                onPressed: null, // Badges unlock automatically
              )),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Progress:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Quizzes completed: $quizzesCompleted'),
                    Text('Textbooks read: $textbooksRead'),
                    Text('AI tools used: $aiToolsUsed'),
                    Text('Calm Mode activated: $calmModeActivated'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => updateProgress(quizzes: 1),
                          child: const Text('Complete Quiz'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => updateProgress(textbooks: 1),
                          child: const Text('Read Textbook'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => updateProgress(aiTools: 1),
                          child: const Text('Use AI Tool'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => updateProgress(calmMode: 1),
                          child: const Text('Activate Calm Mode'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: leaderboard.map((entry) => ListTile(
                  leading: CircleAvatar(child: Text((entry['name'] ?? '?').toString().isNotEmpty ? (entry['name'] ?? '?').toString()[0] : '?')),
                  title: Text(entry['name'] as String),
                  trailing: Text('${entry['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: const Color(0xFFD62828),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('How to earn more points:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('• Complete quizzes and mock exams', style: TextStyle(color: Colors.white)),
                    Text('• Read textbooks', style: TextStyle(color: Colors.white)),
                    Text('• Use AI tools', style: TextStyle(color: Colors.white)),
                    Text('• Stay focused with Calm Mode', style: TextStyle(color: Colors.white)),
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
