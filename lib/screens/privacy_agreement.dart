import 'package:flutter/material.dart';

class PrivacyAgreementModal extends StatelessWidget {
  final VoidCallback onAgree;
  const PrivacyAgreementModal({super.key, required this.onAgree});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy Policy & Terms'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uriel Academy values your privacy and data security.'),
            SizedBox(height: 16),
            Text('By creating an account, you agree to our Privacy Policy and Terms of Service.'),
            SizedBox(height: 16),
            Text('We use your data to personalize your learning experience, provide analytics, and improve our services. Your information will never be sold or shared without your consent.'),
            SizedBox(height: 16),
            Text('You can review our full Privacy Policy and Terms at any time in the app settings.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onAgree,
          child: const Text('I Agree'),
        ),
      ],
    );
  }
}
