import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudyGoalsCard extends StatefulWidget {
  const StudyGoalsCard({super.key});

  @override
  State<StudyGoalsCard> createState() => _StudyGoalsCardState();
}

class _StudyGoalsCardState extends State<StudyGoalsCard> {
  bool _isLoading = true;
  Map<String, dynamic>? _studyGoals;
  bool _hasStudyPlan = false;

  @override
  void initState() {
    super.initState();
    _loadStudyGoals();
  }

  Future<void> _loadStudyGoals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_plan')
          .doc('current')
          .get();

      setState(() {
        _hasStudyPlan = doc.exists;
        _studyGoals = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_hasStudyPlan) {
      return _buildCreatePlanPrompt(context);
    }

    return _buildGoalsCard(context);
  }

  Widget _buildCreatePlanPrompt(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFD62828).withValues(alpha: 0.1),
              const Color(0xFF1A1E3F).withValues(alpha: 0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Start Your Smart Study Journey',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1E3F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Create a personalized study plan that adapts to your learning style and helps you make the most of our features:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(Icons.quiz, 'Past Questions Practice'),
            _buildFeatureItem(Icons.menu_book, 'Textbook Reading Goals'),
            _buildFeatureItem(Icons.psychology, 'AI-Powered Revision'),
            _buildFeatureItem(Icons.card_membership, 'Flashcard Mastery'),
            _buildFeatureItem(Icons.sports_esports, 'Interactive Trivia'),
            _buildFeatureItem(Icons.trending_up, 'Progress Tracking'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/study-planner');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create My Study Plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFD62828)),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsCard(BuildContext context) {
    final goals = _studyGoals?['weekly_goals'] as Map<String, dynamic>? ?? {};
    final progress = _studyGoals?['progress'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flag, color: Color(0xFFD62828), size: 24),
                    SizedBox(width: 12),
                    Text(
                      'This Week\'s Study Goals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/study-planner');
                  },
                  child: const Text('Edit Plan'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGoalItem(
              'Past Questions',
              goals['past_questions'] ?? 0,
              progress['past_questions'] ?? 0,
              Icons.quiz,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildGoalItem(
              'Textbook Chapters',
              goals['textbook_chapters'] ?? 0,
              progress['textbook_chapters'] ?? 0,
              Icons.menu_book,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildGoalItem(
              'AI Study Sessions',
              goals['ai_sessions'] ?? 0,
              progress['ai_sessions'] ?? 0,
              Icons.psychology,
              Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildGoalItem(
              'Trivia Games',
              goals['trivia_games'] ?? 0,
              progress['trivia_games'] ?? 0,
              Icons.sports_esports,
              Colors.green,
            ),
            const SizedBox(height: 16),
            _buildMotivationalMessage(progress, goals),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(
    String title,
    int target,
    int current,
    IconData icon,
    Color color,
  ) {
    final percentage = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$current / $target',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: percentage >= 1.0 ? Colors.green : Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationalMessage(
    Map<String, dynamic> progress,
    Map<String, dynamic> goals,
  ) {
    final totalProgress = progress.values.fold<int>(0, (sum, val) => sum + (val as int? ?? 0));
    final totalGoals = goals.values.fold<int>(0, (sum, val) => sum + (val as int? ?? 0));
    final percentage = totalGoals > 0 ? (totalProgress / totalGoals * 100).round() : 0;

    String message;
    Color messageColor;
    IconData messageIcon;

    if (percentage >= 80) {
      message = '🎉 Excellent progress! Keep up the amazing work!';
      messageColor = Colors.green;
      messageIcon = Icons.celebration;
    } else if (percentage >= 50) {
      message = '💪 You\'re on track! Stay consistent!';
      messageColor = Colors.orange;
      messageIcon = Icons.trending_up;
    } else if (percentage >= 25) {
      message = '🚀 Good start! Let\'s accelerate your learning!';
      messageColor = Colors.blue;
      messageIcon = Icons.rocket_launch;
    } else {
      message = '📚 Begin your journey today! Every step counts.';
      messageColor = Colors.grey;
      messageIcon = Icons.school;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: messageColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: messageColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(messageIcon, color: messageColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: messageColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
