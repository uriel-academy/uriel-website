import 'package:flutter/material.dart';

class CalmModePage extends StatelessWidget {
  final VoidCallback? onCalmModeActivated;
  const CalmModePage({super.key, this.onCalmModeActivated});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calm Learning Mode'),
        backgroundColor: const Color(0xFF2ECC71),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Focus, relax, and learn better with Uriel.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (onCalmModeActivated != null) onCalmModeActivated!();
              },
              child: const Text('Activate Calm Mode'),
            ),
          ],
        ),
      ),
    );
  }
}
