import 'package:flutter/material.dart';

class ProfileAnalyticsPage extends StatelessWidget {
  const ProfileAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Analytics'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: const Center(
        child: Text('Track your progress and insights.'),
      ),
    );
  }
}
