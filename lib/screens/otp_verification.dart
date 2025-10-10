import 'package:flutter/material.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  const OTPVerificationPage({super.key, required this.email});

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  String? error;

  Future<void> verifyOTP() async {
    setState(() { isLoading = true; error = null; });
    // TODO: Replace with real OTP verification logic
    await Future.delayed(const Duration(seconds: 1));
    if (otpController.text == '123456') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OnboardingWalkthroughPage(),
        ),
      );
    } else {
      setState(() { error = 'Invalid OTP. Please try again.'; });
    }
    setState(() { isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the 6-digit code sent to your email:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'OTP Code'),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : verifyOTP,
                child: isLoading ? const CircularProgressIndicator() : const Text('Verify'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // TODO: Resend OTP logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('OTP resent!')),
                );
              },
              child: const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingWalkthroughPage extends StatelessWidget {
  const OnboardingWalkthroughPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding Walkthrough')),
      body: const Center(
        child: Text('Welcome to the Onboarding Walkthrough!', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
