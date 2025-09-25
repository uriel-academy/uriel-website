import 'package:flutter/material.dart';

class StudentMotivationCard extends StatelessWidget {
  final List<String> messages;
  const StudentMotivationCard({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 120,
        child: PageView.builder(
          itemCount: messages.length,
          itemBuilder: (context, i) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                messages[i],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFFD62828)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
