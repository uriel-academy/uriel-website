import 'package:flutter/material.dart';

class SubjectDetailPage extends StatelessWidget {
  final String subject;
  const SubjectDetailPage({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subject),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Center(
        child: Text('Welcome to $subject!', style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
