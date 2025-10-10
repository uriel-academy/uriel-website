import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uriel_mainapp/services/auth_service.dart';
import 'package:uriel_mainapp/services/user_service.dart';
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
        return;
      }
      
      // Check if it's the admin email - bypass database lookup for admin
      if (user.email == 'studywithuriel@gmail.com') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin');
        }
        return;
      }
      
      // For non-admin users, check role and route
      await _checkUserRoleAndRoute(user);
      
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      _showError('An error occurred during sign-in: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  Future<void> _checkUserRoleAndRoute(user) async {
    try {
      debugPrint('Checking user role for: ${user.email}');
      
      // Check user role with timeout
      final userRole = await UserService()
          .getUserRoleByEmail(user.email!)
          .timeout(const Duration(seconds: 10));
      
      debugPrint('User role found: $userRole');
      
      if (userRole != null) {
        // Update last login time asynchronously (don't wait for it)
        UserService().updateLastLogin(user.uid).catchError((e) {
          debugPrint('Failed to update last login: $e');
        });
        
        // Route based on role
        if (mounted) {
          _routeUserBasedOnRole(userRole);
        }
      } else {
        debugPrint('No user role found, creating new student profile');
        
        // New user - create default student profile asynchronously
        UserService().createUserProfile(
          userId: user.uid,
          email: user.email!,
          role: UserRole.student,
          name: user.displayName,
        ).catchError((e) {
          debugPrint('Failed to create user profile: $e');
        });
        
        // Route to student home immediately
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      // If role check fails, default to student dashboard
      debugPrint('Role check failed: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  void _routeUserBasedOnRole(UserRole role) {
    if (!mounted) return;
    
    try {
      switch (role) {
        case UserRole.teacher:
          debugPrint('Routing to teacher dashboard');
          Navigator.pushReplacementNamed(context, '/teacher');
          break;
        case UserRole.school:
          debugPrint('Routing to school dashboard');
          Navigator.pushReplacementNamed(context, '/school');
          break;
        case UserRole.student:
        default:
          debugPrint('Routing to student dashboard');
          Navigator.pushReplacementNamed(context, '/home');
          break;
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      // Fallback navigation
      Navigator.pushReplacementNamed(context, '/home');
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
        // Skip OTP verification and route based on user role
        final userRole = await UserService().getUserRoleByEmail(user.email!);
        
        if (!mounted) return;
        
        if (userRole != null) {
          // Update last login time
          await UserService().updateLastLogin(user.uid);
          
          // Route based on role
          _routeUserBasedOnRole(userRole);
        } else {
          // Fallback to student home if no role found
          Navigator.pushReplacementNamed(context, '/home');
        }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
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
                _buildHeader(context, isSmallScreen),
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 400),
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 0),
                      child: _buildSignInCard(context, isSmallScreen),
                    ),
                  ),
                ),
                _buildFooter(context, isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20, 
        vertical: 16
      ),
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
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1E3F),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          // Back to landing link (subtle)
          if (!isSmallScreen) TextButton(
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

  Widget _buildSignInCard(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
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
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            'Continue your learning journey',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: isSmallScreen ? 24 : 32),

          // Google Sign In Button (Prominent)
          _buildGoogleSignInButton(),
          
          SizedBox(height: isSmallScreen ? 16 : 24),

          // Divider with "or" text
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                child: Text(
                  'or',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),

          SizedBox(height: isSmallScreen ? 16 : 24),

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

  Widget _buildFooter(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Column(
        children: [
          // Sign up link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 13 : 14,
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
                    fontSize: isSmallScreen ? 13 : 14,
                    color: const Color(0xFFD62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          
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
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12),
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
                    fontSize: isSmallScreen ? 11 : 12,
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
