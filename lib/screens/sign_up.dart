import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uriel_mainapp/services/auth_service.dart';
import 'package:uriel_mainapp/services/user_service.dart';
import 'package:uriel_mainapp/screens/home_page.dart';
import 'package:uriel_mainapp/screens/landing_page.dart';

/// A simplified, student-only sign up page.
class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  String? selectedGrade;
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController schoolNameController = TextEditingController();

  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController guardianEmailController = TextEditingController();
  final TextEditingController guardianPhoneController = TextEditingController();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool agreeTerms = false;
  bool agreePrivacy = false;
  bool marketingOptIn = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;
  bool showEmailForm = false;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    schoolNameController.dispose();
    guardianNameController.dispose();
    guardianEmailController.dispose();
    guardianPhoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
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

  Future<void> _handleGoogleSignUp() async {
    setState(() => isLoading = true);
    try {
      final user = await AuthService().signInWithGoogle();
      if (user == null) {
        _showError('Google sign-up failed.');
        return;
      }

      // If an existing account with a role exists, route accordingly
      final existingRole = await UserService().getUserRoleByEmail(user.email!);
      if (existingRole != null) {
        UserService.navigateToHomePage(context, existingRole);
        return;
      }

      // Create a minimal student profile and send user to complete profile
      await UserService().createUserProfile(
        userId: user.uid,
        email: user.email!,
        role: UserRole.student,
        name: user.displayName,
      );

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentHomePage(showProfileOnInit: true)));
    } catch (e) {
      _showError('An error occurred during Google sign up.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showError('Please fill in all required fields correctly.');
      return;
    }
    
    if (!agreeTerms || !agreePrivacy) {
      _showError('Please agree to Terms of Service and Privacy Policy.');
      return;
    }

    setState(() => isLoading = true);
    
    try {
      final user = await AuthService().registerWithEmail(
        emailController.text.trim(), 
        passwordController.text.trim()
      );
      
      if (user == null) {
        _showError('Sign up failed. Please try again.');
        return;
      }

      // Persist student data
      await UserService().storeStudentData(
        userId: user.uid,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        name: '${firstNameController.text.trim()} ${lastNameController.text.trim()}'.trim(),
        email: emailController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        schoolName: schoolNameController.text.trim(),
        grade: selectedGrade ?? 'JHS FORM 1',
        age: int.tryParse(ageController.text.trim()) ?? 0,
        guardianName: guardianNameController.text.trim(),
        guardianEmail: guardianEmailController.text.trim(),
        guardianPhone: guardianPhoneController.text.trim(),
      );

      if (!mounted) return;
      UserService.navigateToHomePage(context, UserRole.student);
    } catch (e) {
      _showError('Sign up failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
                      constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 500),
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 0),
                      child: _buildSignUpCard(context, isSmallScreen),
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
          // Back to landing link
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

  Widget _buildSignUpCard(BuildContext context, bool isSmallScreen) {
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
            'Create your account',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            'Join thousands of students learning with Uriel',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 24 : 32),

          // Google sign-up button
          if (!showEmailForm) ...[
            _buildGoogleSignUpButton(),
            SizedBox(height: isSmallScreen ? 16 : 20),
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
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildEmailToggleButton(),
          ],

          // Email form
          if (showEmailForm) _buildEmailForm(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildGoogleSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleGoogleSignUp,
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
          'Sign up with email',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1E3F),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(bool isSmallScreen) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Section
          Text(
            'Personal Information',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),

          // First & Last Name Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'First Name',
                  controller: firstNameController,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  label: 'Last Name',
                  controller: lastNameController,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Age & Grade Row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Age',
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final age = int.tryParse(v);
                    if (age == null || age < 5) return 'Invalid age';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildGradeDropdown()),
            ],
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Phone Number',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'School Name',
            controller: schoolNameController,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 24),

          // Guardian Information Section
          Text(
            'Guardian / Parent Information',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Required for students under 18',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Guardian Name',
            controller: guardianNameController,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Guardian Email',
            controller: guardianEmailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w]{2,4}$').hasMatch(v)) {
                return 'Invalid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Guardian Phone',
            controller: guardianPhoneController,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 24),

          // Account Credentials Section
          Text(
            'Account Credentials',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Email Address',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w]{2,4}$').hasMatch(v)) {
                return 'Invalid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Password',
            controller: passwordController,
            obscureText: obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Confirm Password',
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v != passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Agreements
          _buildCheckbox(
            value: agreeTerms,
            onChanged: (v) => setState(() => agreeTerms = v ?? false),
            label: 'I agree to the Terms of Service and Privacy Policy',
          ),
          const SizedBox(height: 12),

          _buildCheckbox(
            value: agreePrivacy,
            onChanged: (v) => setState(() => agreePrivacy = v ?? false),
            label: 'I consent to processing of my personal data',
          ),
          const SizedBox(height: 12),

          _buildCheckbox(
            value: marketingOptIn,
            onChanged: (v) => setState(() => marketingOptIn = v ?? false),
            label: 'Send me updates and learning tips (optional)',
          ),
          const SizedBox(height: 24),

          // Sign Up Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleSignUp,
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
                      'Create Account',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: 'Enter $label',
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD62828)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: suffixIcon,
          ),
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildGradeDropdown() {
    final grades = [
      'JHS FORM 1',
      'JHS FORM 2',
      'JHS FORM 3',
      'SHS FORM 1',
      'SHS FORM 2',
      'SHS FORM 3'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grade/Class',
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
            child: DropdownButtonFormField<String>(
              value: selectedGrade,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const Color(0xFF1A1E3F),
              ),
              hint: Text(
                'Select grade',
                style: GoogleFonts.montserrat(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              validator: (v) => v == null ? 'Required' : null,
              items: grades.map((String grade) {
                return DropdownMenuItem<String>(
                  value: grade,
                  child: Text(grade),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() => selectedGrade = newValue);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required Function(bool?) onChanged,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFD62828),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            child: Text(
              'Sign In',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD62828),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
