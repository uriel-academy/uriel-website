import 'package:flutter/material.dart';
import 'package:uriel_mainapp/screens/otp_verification.dart';
import 'package:uriel_mainapp/screens/privacy_agreement.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String _role = 'Student';
  final _formKey = GlobalKey<FormState>();

  // Controllers for each field
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController schoolController = TextEditingController();
  final TextEditingController guardianController = TextEditingController();
  final TextEditingController studentCountController = TextEditingController();

  bool agreed = false;

  List<Widget> _roleFields() {
    switch (_role) {
      case 'Student':
        return [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: ageController,
            decoration: const InputDecoration(labelText: 'Age'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: classController,
            decoration: const InputDecoration(labelText: 'Class'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: schoolController,
            decoration: const InputDecoration(labelText: 'School'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: guardianController,
            decoration: const InputDecoration(labelText: 'Guardian Contact'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ];
      case 'Parent':
        return [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email/WhatsApp'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: guardianController,
            decoration: const InputDecoration(labelText: 'Link Student'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ];
      case 'School':
        return [
          TextFormField(
            controller: schoolController,
            decoration: const InputDecoration(labelText: 'Institution Name'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Admin Email'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: studentCountController,
            decoration: const InputDecoration(labelText: 'Number of Students'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose your role:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Student'),
                  selected: _role == 'Student',
                  onSelected: (_) => setState(() => _role = 'Student'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Parent'),
                  selected: _role == 'Parent',
                  onSelected: (_) => setState(() => _role = 'Parent'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('School'),
                  selected: _role == 'School',
                  onSelected: (_) => setState(() => _role = 'School'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  ..._roleFields(),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: agreed,
                        onChanged: (v) => setState(() => agreed = v ?? false),
                      ),
                      const Expanded(
                        child: Text('I agree to Privacy Policy & Terms'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => PrivacyAgreementModal(
                            onAgree: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sign up successful! Please verify OTP.')),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OTPVerificationPage(email: emailController.text.trim()),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62828),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: const [
                  Icon(Icons.emoji_emotions, size: 48, color: Color(0xFF2ECC71)),
                  SizedBox(height: 8),
                  Text('Uri will guide you through your learning journey!', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
