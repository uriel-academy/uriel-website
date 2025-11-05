import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uriel_mainapp/services/auth_service.dart';
import 'package:uriel_mainapp/services/user_service.dart';
import 'package:uriel_mainapp/screens/student_profile_page.dart';

/// A simplified, student-only sign up page.
/// Two steps: 0 = Details (personal + guardian), 1 = Auth (email/password + agreements).
class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _authFormKey = GlobalKey<FormState>();

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

  int currentStep = 0;
  final int totalSteps = 2;

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

  void _nextStep() => setState(() => currentStep = (currentStep + 1).clamp(0, totalSteps - 1));
  void _previousStep() => setState(() => currentStep = (currentStep - 1).clamp(0, totalSteps - 1));

  bool _validateCurrentStep() {
    if (currentStep == 0) return true; // We'll validate details when Next pressed
    return agreeTerms && agreePrivacy;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFFD62828)));
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentProfilePage()));
    } catch (e) {
      _showError('An error occurred during Google sign up.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    setState(() => isLoading = true);
    try {
      if (!(_detailsFormKey.currentState?.validate() ?? false)) return;
      if (!(_authFormKey.currentState?.validate() ?? false)) return;
      if (!agreeTerms || !agreePrivacy) {
        _showError('Please agree to terms and privacy');
        return;
      }

      final user = await AuthService().registerWithEmail(emailController.text.trim(), passwordController.text.trim());
      if (user == null) {
        _showError('Sign up failed.');
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
      _showError('Sign up failed.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey[50]),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
    );
  }

  Widget _buildDetailsStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading (use same Montserrat family as sign-in for harmony)
          Text('Student information', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1A1E3F))),
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all( isSmallScreen ? 16 : 20 ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0,6)),
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                // First + Last name fields side-by-side on wide screens, stacked on small screens
                LayoutBuilder(builder: (ctx, constraints) {
                  final wide = constraints.maxWidth > 420;
                  return wide
                      ? Row(
                          children: [
                            Expanded(child: _buildTextField(controller: firstNameController, label: 'First name', hint: 'First name', icon: Icons.person_outline, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(controller: lastNameController, label: 'Last name', hint: 'Last name', icon: Icons.person_outline, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildTextField(controller: firstNameController, label: 'First name', hint: 'First name', icon: Icons.person_outline, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                            const SizedBox(height: 12),
                            _buildTextField(controller: lastNameController, label: 'Last name', hint: 'Last name', icon: Icons.person_outline, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                          ],
                        );
                }),
                const SizedBox(height: 12),
                _buildTextField(controller: ageController, label: 'Age', hint: 'Enter age', icon: Icons.cake_outlined, keyboardType: TextInputType.number, validator: (v) {
                  if (v == null || v.isEmpty) return 'Age required';
                  final a = int.tryParse(v);
                  if (a == null || a < 5) return 'Enter valid age';
                  return null;
                }),
                const SizedBox(height: 12),
                _buildDropdownField(value: selectedGrade, label: 'Grade/Class', hint: 'Select grade', icon: Icons.school_outlined, items: ['JHS FORM 1', 'JHS FORM 2', 'JHS FORM 3', 'SHS FORM 1', 'SHS FORM 2', 'SHS FORM 3'], onChanged: (v) => setState(() => selectedGrade = v), validator: (v) => v == null ? 'Grade required' : null),
                const SizedBox(height: 12),
                _buildTextField(controller: phoneController, label: 'Student Phone', hint: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: (v) => (v == null || v.isEmpty) ? 'Phone required' : null),
                const SizedBox(height: 12),
                _buildTextField(controller: schoolNameController, label: 'School Name', hint: 'School', icon: Icons.business_outlined, validator: (v) => (v == null || v.isEmpty) ? 'School required' : null),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('Parent / Guardian Information', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _buildTextField(controller: guardianNameController, label: 'Guardian Name', hint: 'Guardian full name', icon: Icons.family_restroom_outlined, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
              const SizedBox(height: 12),
                _buildTextField(controller: guardianEmailController, label: 'Guardian Email', hint: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                // Basic email validation
                  if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w]{2,4}$').hasMatch(v)) return 'Invalid email';
                return null;
              }),
              const SizedBox(height: 12),
              _buildTextField(controller: guardianPhoneController, label: 'Guardian Phone', hint: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthStep() {
    return Form(
      key: _authFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Setup', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildTextField(controller: emailController, label: 'Email Address', hint: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) {
            if (v == null || v.isEmpty) return 'Email required';
            // Basic email validation
              if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w]{2,4}$').hasMatch(v)) return 'Invalid email';
            return null;
          }),
          const SizedBox(height: 12),
          _buildTextField(controller: passwordController, label: 'Password', hint: 'Password', icon: Icons.lock_outlined, obscureText: obscurePassword, suffixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscurePassword = !obscurePassword)), validator: (v) {
            if (v == null || v.isEmpty) return 'Password required';
            if (v.length < 8) return 'At least 8 chars';
            return null;
          }),
          const SizedBox(height: 12),
          _buildTextField(controller: confirmPasswordController, label: 'Confirm Password', hint: 'Confirm', icon: Icons.lock_outlined, obscureText: obscureConfirmPassword, suffixIcon: IconButton(icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword)), validator: (v) {
            if (v == null || v.isEmpty) return 'Confirm password';
            if (v != passwordController.text) return 'Passwords do not match';
            return null;
          }),

          const SizedBox(height: 12),
          Row(children: [
            Checkbox(value: agreeTerms, onChanged: (v) => setState(() => agreeTerms = v ?? false)),
            const SizedBox(width: 8),
            Expanded(child: Text('I agree to the Terms of Service and Privacy Policy'))
          ]),
          Row(children: [
            Checkbox(value: agreePrivacy, onChanged: (v) => setState(() => agreePrivacy = v ?? false)),
            const SizedBox(width: 8),
            const Expanded(child: Text('I consent to processing of my personal data'))
          ]),
          Row(children: [
            Checkbox(value: marketingOptIn, onChanged: (v) => setState(() => marketingOptIn = v ?? false)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Receive updates (optional)'))
          ]),
        ],
      ),
    );
  }

  Widget _buildGoogleSignUpButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: isLoading ? null : _handleGoogleSignUp, child: isLoading ? const CircularProgressIndicator() : const Text('Continue with Google')),
    );
  }

  Widget _buildNavigationButtons(bool isSmallScreen) {
    final canProceed = _validateCurrentStep();
    return Row(children: [
      if (currentStep > 0) Expanded(child: OutlinedButton(onPressed: _previousStep, child: const Text('Back'))),
      if (currentStep > 0) const SizedBox(width: 12),
      Expanded(child: ElevatedButton(onPressed: (isLoading || !canProceed) ? null : () async {
        if (currentStep == 0) {
          if (!(_detailsFormKey.currentState?.validate() ?? false)) return;
          _nextStep();
        } else {
          await _handleSignUp();
        }
      }, child: Text(currentStep == 0 ? 'Continue' : 'Create Account'))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              margin: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(
                  totalSteps,
                  (index) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < totalSteps - 1 ? 8 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= currentStep ? const Color(0xFF1A1E3F) : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 600),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IndexedStack(index: currentStep, children: [_buildDetailsStep(), _buildAuthStep()]),
                            const SizedBox(height: 20),
                            _buildNavigationButtons(isSmallScreen),
                            if (currentStep == 0) ...[
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(child: Divider(color: Colors.grey[300])),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')),
                                Expanded(child: Divider(color: Colors.grey[300])),
                              ]),
                              const SizedBox(height: 12),
                              _buildGoogleSignUpButton(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Need help? Contact support@uriel.academy'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
