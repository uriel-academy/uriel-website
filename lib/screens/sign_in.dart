import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uriel_mainapp/services/auth_service.dart';
import 'package:uriel_mainapp/screens/otp_verification.dart';
import 'package:uriel_mainapp/screens/landing_page.dart';
import 'package:uriel_mainapp/screens/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberMe = false;
  bool isLoading = false;
  bool showEmailForm = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email') ?? '';
    if (savedEmail.isNotEmpty) {
      emailController.text = savedEmail;
      setState(() {
        rememberMe = true;
      });
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('remembered_email', email);
    } else {
      await prefs.remove('remembered_email');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = await AuthService().signInWithGoogle();
      if (user == null) {
        _showError('Google sign-in failed. Please try again.');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showError('An error occurred during sign-in.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (!_validateForm()) return;

    setState(() {
      isLoading = true;
    });

    try {
      await _saveEmail(emailController.text.trim());
      final user = await AuthService().signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      if (user == null) {
        _showError('Invalid email or password. Please try again.');
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationPage(email: emailController.text.trim()),
          ),
        );
      }
    } catch (e) {
      _showError('An error occurred during sign-in.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (emailController.text.trim().isEmpty) {
      _showError('Please enter your email address.');
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
      _showError('Please enter a valid email address.');
      return false;
    }
    if (passwordController.text.trim().isEmpty) {
      _showError('Please enter your password.');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top
            ),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      child: _buildSignInCard(context),
                    ),
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Logo/Brand
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LandingPage()),
            ),
            child: Text(
              'Uriel Academy',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1E3F),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          // Back to landing link (subtle)
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LandingPage()),
            ),
            child: Text(
              '← Back to home',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Welcome message
          Text(
            'Welcome back',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Continue your learning journey',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),

          // Google Sign In Button (Prominent)
          _buildGoogleSignInButton(),
          
          const SizedBox(height: 24),

          // Divider with "or" text
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),

          const SizedBox(height: 24),

          // Email/Password option
          if (!showEmailForm) _buildEmailToggleButton(),
          if (showEmailForm) _buildEmailForm(),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleGoogleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD62828),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Continue with Google',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildEmailToggleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            showEmailForm = true;
          });
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Sign in with email',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1E3F),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email field
        Text(
          'Email address',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: GoogleFonts.montserrat(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD62828)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
        const SizedBox(height: 20),

        // Password field
        Text(
          'Password',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: GoogleFonts.montserrat(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD62828)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
              icon: Icon(
                obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[400],
                size: 20,
              ),
            ),
          ),
          style: GoogleFonts.montserrat(fontSize: 14),
          onSubmitted: (_) => _handleEmailSignIn(),
        ),
        const SizedBox(height: 16),

        // Remember me and forgot password
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: rememberMe,
                onChanged: (value) {
                  setState(() {
                    rememberMe = value ?? false;
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: const Color(0xFFD62828),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Remember me',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                _showError('Forgot password feature coming soon!');
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: const Color(0xFFD62828),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sign in button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleEmailSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1E3F),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Sign in',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Back to Google option
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                showEmailForm = false;
              });
            },
            child: Text(
              '← Back to Google sign-in',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Sign up link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                ),
                child: Text(
                  'Sign up',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: const Color(0xFFD62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Legal links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  // TODO: Show Terms of Service
                },
                child: Text(
                  'Terms of Service',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 1,
                height: 12,
                color: Colors.grey[400],
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Show Privacy Policy
                },
                child: Text(
                  'Privacy Policy',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Copyright
          Text(
            '© 2025 Uriel Academy',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
