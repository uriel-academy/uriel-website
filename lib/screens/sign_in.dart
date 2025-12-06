import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uriel_mainapp/services/auth_service.dart';
import 'package:uriel_mainapp/services/user_service.dart';
import 'package:uriel_mainapp/screens/landing_page.dart';
import 'package:uriel_mainapp/screens/sign_up.dart';
import 'package:uriel_mainapp/screens/student_profile_page.dart';
import 'package:uriel_mainapp/screens/home_page.dart';
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
  String selectedRole = 'Student'; // Default role
  final List<String> roles = ['Student', 'Teacher', 'School Admin'];
  // Sign-in extra fields for School Admin
  final TextEditingController signInSchoolController = TextEditingController();
  final TextEditingController signInSchoolCodeController = TextEditingController();

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
      
      // Brief delay to allow Firestore to stabilize after authentication
      // This prevents internal state errors in Firebase SDK 11.x
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if it's the admin email - bypass database lookup for admin
      if (user.email == 'studywithuriel@gmail.com') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin');
        }
        return;
      }
      
      // For non-admin users, check if they already have a role assigned in Firestore
      // Retry with exponential backoff if Firestore operation fails
      final existingRole = await _retryFirestoreOperation(
        () => UserService().getUserRoleByEmail(user.email!),
        'get user role',
      );
      
      if (existingRole != null) {
        // Existing user - update last login and route them
        await _retryFirestoreOperation(
          () => UserService().updateLastLogin(user.uid),
          'update last login',
        );
        if (mounted) UserService.navigateToHomePage(context, existingRole);
        return;
      }

      // New user created by Google sign-in: create a minimal student profile and navigate to student homepage with profile open
      await _retryFirestoreOperation(
        () => UserService().createUserProfile(
          userId: user.uid,
          email: user.email!,
          role: UserRole.student,
          name: user.displayName,
        ),
        'create user profile',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomePage(showProfileOnInit: true)),
      );
      
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
  
  // Retry Firestore operations with exponential backoff to handle transient errors
  Future<T?> _retryFirestoreOperation<T>(
    Future<T?> Function() operation,
    String operationName,
  ) async {
    int attempts = 0;
    const maxAttempts = 3;
    const initialDelay = Duration(milliseconds: 300);
    
    while (attempts < maxAttempts) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        debugPrint('Firestore operation "$operationName" failed (attempt $attempts/$maxAttempts): $e');
        
        if (attempts >= maxAttempts) {
          rethrow;
        }
        
        // Exponential backoff: 300ms, 600ms, 1200ms
        final delay = initialDelay * (1 << (attempts - 1));
        await Future.delayed(delay);
      }
    }
    
    return null;
  }
  
  

  void _routeUserBasedOnRole(UserRole role) {
    if (!mounted) return;
    
    try {
      switch (role) {
        case UserRole.superAdmin:
          debugPrint('Routing to super admin dashboard');
          Navigator.pushReplacementNamed(context, '/admin');
          break;
        case UserRole.teacher:
          debugPrint('Routing to teacher dashboard');
          Navigator.pushReplacementNamed(context, '/teacher');
          break;
        case UserRole.schoolAdmin:
          debugPrint('Routing to school admin dashboard');
          Navigator.pushReplacementNamed(context, '/school-admin');
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
        // After auth, verify the user's role in Firestore before routing
        final profile = await UserService().getUserProfile(user.uid);

        // If user selected School Admin, require school code to be provided
        if (selectedRole == 'School Admin') {
          if (signInSchoolCodeController.text.trim().isEmpty) {
            _showError('Please provide your school code to sign in as School Admin');
            return;
          }
        }

        if (profile == null || profile['role'] == null) {
          // No role assigned — only allow Student sign in by default
          if (selectedRole != 'Student') {
            _showError('Your account is not registered as $selectedRole. Contact admin.');
            return;
          }
          // New student record — navigate to profile settings so they can complete optional info
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentProfilePage(isNewUser: true)));
          return;
        }

        final roleString = profile['role'] as String;
        if (selectedRole == 'Teacher' && roleString != UserRole.teacher.name) {
          _showError('This account is not a Teacher account');
          return;
        }
        if (selectedRole == 'School Admin' && roleString != UserRole.schoolAdmin.name) {
          _showError('This account is not a School Admin account');
          return;
        }

        // If School Admin, verify institution code matches
        if (selectedRole == 'School Admin') {
          final storedCode = (profile['institutionCode'] ?? profile['institution_code'] ?? '').toString();
          final provided = signInSchoolCodeController.text.trim();
          if (storedCode.isEmpty || provided.isEmpty || storedCode != provided) {
            _showError('Invalid school code for this account');
            return;
          }
        }

        // All checks passed — route user
        final role = roleString == UserRole.teacher.name
            ? UserRole.teacher
            : roleString == UserRole.schoolAdmin.name
                ? UserRole.schoolAdmin
                : UserRole.student;
        _routeUserBasedOnRole(role);
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

          // Role selector (prominent)
          _buildRoleSelector(),

          SizedBox(height: isSmallScreen ? 12 : 16),

          // If Student: show Google sign-in button. If Teacher or School Admin: show small explanatory text and hide Google option.
          if (selectedRole == 'Student') ...[
            SizedBox(height: isSmallScreen ? 8 : 12),
            _buildGoogleSignInButton(),
            SizedBox(height: isSmallScreen ? 12 : 20),
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
            SizedBox(height: isSmallScreen ? 12 : 20),
          ] else ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Teachers and School Admin cannot sign in with Google. Use email and school credentials below.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 20),
          ],

          // Email/Password option
          if (!showEmailForm) _buildEmailToggleButton(),
          if (showEmailForm) _buildEmailForm(),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: roles.map((role) {
          final isSelected = selectedRole == role;
          IconData icon;
          switch (role) {
            case 'Teacher':
              icon = Icons.school;
              break;
            case 'School Admin':
              icon = Icons.admin_panel_settings;
              break;
            default:
              icon = Icons.person;
          }
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedRole = role;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : [],
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isSelected ? const Color(0xFFD62828) : Colors.grey[600],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF1A1E3F) : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
        const SizedBox(height: 20),

        // Role selector
        Text(
          'Sign in as',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const Color(0xFF1A1E3F),
              ),
              items: roles.map((String role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Row(
                    children: [
                      Icon(
                        role == 'Teacher' ? Icons.school :
                        role == 'School Admin' ? Icons.admin_panel_settings :
                        Icons.person,
                        size: 20,
                        color: const Color(0xFFD62828),
                      ),
                      const SizedBox(width: 12),
                      Text(role),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedRole = newValue;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // If signing in as School Admin or Teacher, require school and school code fields
        if (selectedRole == 'School Admin' || selectedRole == 'Teacher') ...[
          Text(
            'School Name',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: signInSchoolController,
            decoration: InputDecoration(
              hintText: 'Enter your school name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.montserrat(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            'School Code',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: signInSchoolCodeController,
            decoration: InputDecoration(
              hintText: 'Enter your school code',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.montserrat(fontSize: 14),
          ),
          const SizedBox(height: 16),
        ],

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

        // Note: removed 'Back to Google sign-in' button per requirements
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
    signInSchoolController.dispose();
    signInSchoolCodeController.dispose();
    super.dispose();
  }
}
