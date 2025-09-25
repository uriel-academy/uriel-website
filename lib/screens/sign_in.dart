import 'package:flutter/material.dart';
import 'package:uriel_mainapp/services/auth_service.dart';
import 'package:uriel_mainapp/screens/otp_verification.dart'; // Import OTPVerificationPage
import 'package:shared_preferences/shared_preferences.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Row(
              children: [
                BackButton(), // Replace logo with back button
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: width < 600
                    ? _buildVerticalLayout(context)
                    : _buildHorizontalLayout(context),
              ),
            ),
            const Text(
              '© 2025 Uriel Academy',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    bool rememberMe = false;
    Future<void> loadEmail() async {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('remembered_email') ?? '';
      emailController.text = savedEmail;
      rememberMe = savedEmail.isNotEmpty;
    }
    Future<void> saveEmail(String email) async {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('remembered_email', email);
      } else {
        await prefs.remove('remembered_email');
      }
    }
    Future<void> handleLogin() async {
      await saveEmail(emailController.text.trim());
      final user = await AuthService().signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email sign-in failed')),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationPage(email: emailController.text.trim()),
          ),
        );
      }
    }
    // Load saved email on widget build
    WidgetsBinding.instance.addPostFrameCallback((_) => loadEmail());

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left: Social Buttons
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Log in:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _socialButton(
              'Continue with Google',
              Icons.g_mobiledata,
              onPressed: () async {
                // Google sign in
                final user = await AuthService().signInWithGoogle();
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google sign-in failed')),
                  );
                } else {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
            ),
            const SizedBox(height: 12),
            _socialButton('Continue with Apple', Icons.apple),
            const SizedBox(height: 12),
            _socialButton('Continue with Facebook', Icons.facebook),
            const SizedBox(height: 12),
            _socialButton('Continue with X/Twitter', Icons.alternate_email),
          ],
        ),
        const SizedBox(width: 32),
        Container(width: 1, height: 280, color: Colors.black),
        const SizedBox(width: 32),
        // Right: Email/Password
        SizedBox(
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Email/User name:'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  StatefulBuilder(
                    builder: (context, setState) => Checkbox(
                      value: rememberMe,
                      onChanged: (val) {
                        setState(() {
                          rememberMe = val ?? false;
                        });
                      },
                    ),
                  ),
                  const Text('Remember me'),
                ],
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Password:'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => handleLogin(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                width: 140,
                child: ElevatedButton(
                  onPressed: handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E64),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'log in',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    bool rememberMe = false;
    Future<void> loadEmail() async {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('remembered_email') ?? '';
      emailController.text = savedEmail;
      rememberMe = savedEmail.isNotEmpty;
    }
    Future<void> saveEmail(String email) async {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('remembered_email', email);
      } else {
        await prefs.remove('remembered_email');
      }
    }
    Future<void> handleLogin() async {
      await saveEmail(emailController.text.trim());
      final user = await AuthService().signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email sign-in failed')),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationPage(email: emailController.text.trim()),
          ),
        );
      }
    }
    // Load saved email on widget build
    WidgetsBinding.instance.addPostFrameCallback((_) => loadEmail());
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Log in:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _socialButton(
            'Continue with Google',
            Icons.g_mobiledata,
            onPressed: () async {
              final user = await AuthService().signInWithGoogle();
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Google sign-in failed')),
                );
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          const SizedBox(height: 12),
          _socialButton('Continue with Apple', Icons.apple),
          const SizedBox(height: 12),
          _socialButton('Continue with Facebook', Icons.facebook),
          const SizedBox(height: 12),
          _socialButton('Continue with X/Twitter', Icons.alternate_email),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Email:'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          Row(
            children: [
              StatefulBuilder(
                builder: (context, setState) => Checkbox(
                  value: rememberMe,
                  onChanged: (val) {
                    setState(() {
                      rememberMe = val ?? false;
                    });
                  },
                ),
              ),
              const Text('Remember me'),
            ],
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Password:'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => handleLogin(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            width: 140,
            child: ElevatedButton(
              onPressed: handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004E64),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'log in',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Update _socialButton to use icon instead of asset
  Widget _socialButton(String text, IconData icon, {VoidCallback? onPressed}) {
    return SizedBox(
      width: 260,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
