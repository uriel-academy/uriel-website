import 'package:flutter/material.dart';

class OnboardingWalkthroughPage extends StatelessWidget {
  const OnboardingWalkthroughPage({super.key});

  @override
  Widget build(BuildContext context) {
  final List<_OnboardingStep> steps = [
      _OnboardingStep(
        icon: Icons.school,
        title: 'Welcome to Uriel Academy!',
        description: 'Uri will guide you through your learning journey. Get ready for a smarter, calmer, and more fun way to learn.',
      ),
      _OnboardingStep(
        icon: Icons.grid_view,
        title: 'Explore Subjects',
        description: 'Access a grid of subjects, textbooks, past questions, and mock exams tailored for you.',
      ),
      _OnboardingStep(
        icon: Icons.psychology,
        title: 'AI Tools & Calm Mode',
        description: 'Use AI-powered tools and calm learning mode to boost your focus and results.',
      ),
      _OnboardingStep(
        icon: Icons.emoji_events,
        title: 'Gamification & Analytics',
        description: 'Earn badges, track your progress, and get personalized insights.',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Meet Uri!'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: PageView.builder(
        itemCount: steps.length,
        itemBuilder: (context, index) {
          final step = steps[index];
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(step.icon, size: 80, color: const Color(0xFF2ECC71)),
                const SizedBox(height: 32),
                Text(step.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(step.description, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 48),
                if (index == steps.length - 1)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/student_dashboard');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD62828),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Start Learning!'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String description;
  _OnboardingStep({required this.icon, required this.title, required this.description});
}
