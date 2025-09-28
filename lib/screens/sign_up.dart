import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uriel_mainapp/services/auth_service.dart';

enum UserType { student, teacher, school }

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final PageController _pageController = PageController();
  int currentStep = 0;
  final int totalSteps = 3;
  
  UserType? selectedUserType;
  bool isLoading = false;
  
  // Form keys for each step
  final _detailsFormKey = GlobalKey<FormState>();
  final _authFormKey = GlobalKey<FormState>();
  
  // Common controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  // Student specific controllers
  final TextEditingController ageController = TextEditingController();
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController guardianEmailController = TextEditingController();
  final TextEditingController guardianPhoneController = TextEditingController();
  
  // Teacher specific controllers
  final TextEditingController teacherSchoolController = TextEditingController();
  final TextEditingController yearsExperienceController = TextEditingController();
  final TextEditingController teacherIdController = TextEditingController();
  
  // School specific controllers
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController schoolEmailController = TextEditingController();
  final TextEditingController schoolPhoneController = TextEditingController();
  final TextEditingController schoolAddressController = TextEditingController();
  final TextEditingController studentCountController = TextEditingController();
  final TextEditingController teacherCountController = TextEditingController();
  final TextEditingController lmsController = TextEditingController();
  
  // Dropdown values
  String? selectedGrade;
  String? selectedSchoolType;
  String? selectedRegion;
  String? selectedHearAbout;
  List<String> selectedSubjects = [];
  List<String> selectedTeachingClasses = [];
  List<String> selectedTeachingSubjects = [];
  
  // Checkboxes
  bool agreeTerms = false;
  bool agreePrivacy = false;
  bool marketingOptIn = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose all controllers
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    ageController.dispose();
    schoolNameController.dispose();
    guardianNameController.dispose();
    guardianEmailController.dispose();
    guardianPhoneController.dispose();
    teacherSchoolController.dispose();
    yearsExperienceController.dispose();
    teacherIdController.dispose();
    contactPersonController.dispose();
    positionController.dispose();
    schoolEmailController.dispose();
    schoolPhoneController.dispose();
    schoolAddressController.dispose();
    studentCountController.dispose();
    teacherCountController.dispose();
    lmsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (currentStep < totalSteps - 1) {
      setState(() {
        currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = await AuthService().signInWithGoogle();
      if (user == null) {
        _showError('Google sign-up failed. Please try again.');
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
      }
    } catch (e) {
      _showError('An error occurred during sign-up.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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

  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0:
        return selectedUserType != null;
      case 1:
        // Don't validate form until user tries to proceed
        return true; // Allow proceeding, validation happens on submit
      case 2:
        return agreeTerms && agreePrivacy;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1E3F)),
          onPressed: () {
            if (currentStep > 0) {
              _previousStep();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Create Account',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              margin: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(totalSteps, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index < totalSteps - 1 ? 8 : 0,
                      ),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= currentStep
                            ? const Color(0xFF1A1E3F)
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Main content - takes remaining space
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  children: [
                    // Main card
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: isSmallScreen ? double.infinity : 500,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Step content
                            Container(
                              constraints: BoxConstraints(
                                minHeight: screenHeight * 0.4,
                              ),
                              child: IndexedStack(
                                index: currentStep,
                                children: [
                                  _buildUserTypeStep(),
                                  _buildDetailsStep(),
                                  _buildAuthStep(),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                            
                            // Navigation buttons
                            _buildNavigationButtons(isSmallScreen),
                            
                            // Google Sign Up Button (only on first step)
                            if (currentStep == 0) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[300])),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'or',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[300])),
                                ],
                              ),
                              const SizedBox(height: 16),
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

            // Fixed Footer
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sign in link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Support information
                  Text(
                    'Need help? Contact support@uriel.academy',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: User Type Selection
  Widget _buildUserTypeStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose Your Account Type',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the option that best describes you',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 32),
          
          // User type cards
          _buildUserTypeCard(
            type: UserType.student,
            title: 'Student',
            subtitle: 'Learn with personalized courses and tracking',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 12),
          _buildUserTypeCard(
            type: UserType.teacher,
            title: 'Teacher',
            subtitle: 'Manage student progress and create courses',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildUserTypeCard(
            type: UserType.school,
            title: 'School/Institution',
            subtitle: 'Manage multiple teachers and students',
            icon: Icons.business_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeCard({
    required UserType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = selectedUserType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedUserType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1E3F).withOpacity(0.05) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? const Color(0xFF1A1E3F) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1A1E3F) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF1A1E3F),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // Step 2: Details Form
  Widget _buildDetailsStep() {
    if (selectedUserType == null) return Container();

    return SingleChildScrollView(
      child: Form(
        key: _detailsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getDetailsTitle(),
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide your details',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),
            
            ..._buildDetailsFields(),
          ],
        ),
      ),
    );
  }

  String _getDetailsTitle() {
    switch (selectedUserType!) {
      case UserType.student:
        return 'Student Information';
      case UserType.teacher:
        return 'Teacher Information';
      case UserType.school:
        return 'School Information';
    }
  }

  List<Widget> _buildDetailsFields() {
    switch (selectedUserType!) {
      case UserType.student:
        return _buildStudentFields();
      case UserType.teacher:
        return _buildTeacherFields();
      case UserType.school:
        return _buildSchoolFields();
    }
  }

  List<Widget> _buildStudentFields() {
    return [
      _buildTextField(
        controller: nameController,
        label: 'Full Name',
        hint: 'Enter your full name',
        icon: Icons.person_outline,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: ageController,
        label: 'Age',
        hint: 'Enter your age',
        icon: Icons.cake_outlined,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Age is required';
          }
          final age = int.tryParse(value);
          if (age == null || age < 5 || age > 100) {
            return 'Please enter a valid age';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildDropdownField(
        value: selectedGrade,
        label: 'Grade/Class',
        hint: 'Select your grade',
        icon: Icons.school_outlined,
        items: ['JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3'],
        onChanged: (value) {
          setState(() {
            selectedGrade = value;
          });
        },
        validator: (value) => value == null ? 'Grade is required' : null,
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: phoneController,
        label: 'Student Phone Number',
        hint: 'Enter your phone number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Phone number is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: schoolNameController,
        label: 'School Name',
        hint: 'Enter your school name',
        icon: Icons.business_outlined,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'School name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 32),
      Text(
        'Parent/Guardian Information',
        style: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1E3F),
        ),
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: guardianNameController,
        label: 'Parent/Guardian Name',
        hint: 'Enter parent/guardian name',
        icon: Icons.family_restroom_outlined,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Parent/Guardian name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: guardianEmailController,
        label: 'Parent/Guardian Email',
        hint: 'Enter parent/guardian email',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Parent/Guardian email is required';
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: guardianPhoneController,
        label: 'Parent/Guardian Phone',
        hint: 'Enter parent/guardian phone',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Parent/Guardian phone is required';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildTeacherFields() {
    return [
      _buildTextField(
        controller: nameController,
        label: 'Full Name',
        hint: 'Enter your full name',
        icon: Icons.person_outline,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: emailController,
        label: 'Email Address',
        hint: 'Enter your email',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Email is required';
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: phoneController,
        label: 'Phone Number',
        hint: 'Enter your phone number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Phone number is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildDropdownField(
        value: selectedTeachingClasses.isNotEmpty ? selectedTeachingClasses.first : null,
        label: 'Grade/Class You Teach',
        hint: 'Select grade you teach',
        icon: Icons.class_outlined,
        items: ['JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3'],
        onChanged: (value) {
          setState(() {
            if (value != null) {
              selectedTeachingClasses = [value];
            }
          });
        },
        validator: (value) => value == null ? 'Teaching grade is required' : null,
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: teacherSchoolController,
        label: 'School/Institution',
        hint: 'Enter your school name',
        icon: Icons.business_outlined,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'School name is required';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildSchoolFields() {
    return [
      _buildTextField(
        controller: nameController,
        label: 'Institution Name',
        hint: 'Enter institution name',
        icon: Icons.business_outlined,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Institution name is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: emailController,
        label: 'School Email',
        hint: 'Enter school email',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'School email is required';
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: contactPersonController,
        label: 'Contact Person Name',
        hint: 'Enter contact person name',
        icon: Icons.person_outline,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Contact person is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildDropdownField(
        value: selectedRegion,
        label: 'Region',
        hint: 'Select school region',
        icon: Icons.location_on_outlined,
        items: [
          'Greater Accra',
          'Ashanti',
          'Western',
          'Eastern',
          'Central',
          'Northern',
          'Upper East',
          'Upper West',
          'Volta',
          'Brong-Ahafo',
          'Western North',
          'Ahafo',
          'Bono East',
          'Oti',
          'North East',
          'Savannah'
        ],
        onChanged: (value) {
          setState(() {
            selectedRegion = value;
          });
        },
        validator: (value) => value == null ? 'Region is required' : null,
      ),
      const SizedBox(height: 20),
      _buildTextField(
        controller: phoneController,
        label: 'Contact Phone Number',
        hint: 'Enter contact phone number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Contact phone number is required';
          }
          return null;
        },
      ),
    ];
  }

  // Step 3: Authentication Setup
  Widget _buildAuthStep() {
    return SingleChildScrollView(
      child: Form(
        key: _authFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Account Setup',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your login credentials',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 32),

            // Only show email for students since teachers/schools already provided them
            if (selectedUserType == UserType.student) ...[
              _buildTextField(
                controller: emailController,
                label: 'Email Address',
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
            ],
            
            _buildTextField(
              controller: passwordController,
              label: 'Password',
              hint: 'Create a strong password',
              icon: Icons.lock_outlined,
              obscureText: obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                return 'Password must contain uppercase, lowercase, and number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_outlined,
            obscureText: obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  obscureConfirmPassword = !obscureConfirmPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Terms and conditions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: agreeTerms,
                onChanged: (value) {
                  setState(() {
                    agreeTerms = value ?? false;
                  });
                },
                activeColor: const Color(0xFF1A1E3F),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      agreeTerms = !agreeTerms;
                    });
                  },
                  child: Text(
                    'I agree to the Terms of Service and Privacy Policy',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: agreePrivacy,
                onChanged: (value) {
                  setState(() {
                    agreePrivacy = value ?? false;
                  });
                },
                activeColor: const Color(0xFF1A1E3F),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      agreePrivacy = !agreePrivacy;
                    });
                  },
                  child: Text(
                    'I consent to the processing of my personal data',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: marketingOptIn,
                onChanged: (value) {
                  setState(() {
                    marketingOptIn = value ?? false;
                  });
                },
                activeColor: const Color(0xFF1A1E3F),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      marketingOptIn = !marketingOptIn;
                    });
                  },
                  child: Text(
                    'I would like to receive updates and promotional content (optional)',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  // Helper method to build text fields
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
      style: GoogleFonts.montserrat(
        fontSize: 14,
        color: const Color(0xFF1A1E3F),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
        suffixIcon: suffixIcon,
        labelStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: const Color(0xFF6B7280),
        ),
        hintStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: const Color(0xFF9CA3AF),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A1E3F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD62828)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD62828), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // Helper method to build dropdown fields
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
      style: GoogleFonts.montserrat(
        fontSize: 14,
        color: const Color(0xFF1A1E3F),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: const Color(0xFF6B7280),
        ),
        hintStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: const Color(0xFF9CA3AF),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A1E3F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD62828)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD62828), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
    );
  }

  // Google Sign Up Button
  Widget _buildGoogleSignUpButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleGoogleSignUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1E3F),
          elevation: 0,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1E3F)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Navigation buttons
  Widget _buildNavigationButtons(bool isSmallScreen) {
    final canProceed = _validateCurrentStep();
    
    return Row(
      children: [
        if (currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A1E3F),
                side: const BorderSide(color: Color(0xFF1A1E3F)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Back',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (currentStep > 0) const SizedBox(width: 16),
        Expanded(
          flex: currentStep == 0 ? 1 : 2,
          child: ElevatedButton(
            onPressed: (isLoading || !canProceed) ? null : _handleNextOrSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed ? const Color(0xFF1A1E3F) : Colors.grey[300],
              foregroundColor: canProceed ? Colors.white : Colors.grey[600],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _getButtonText(),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _getButtonText() {
    switch (currentStep) {
      case 0:
        return 'Continue';
      case 1:
        return 'Continue';
      case 2:
        return 'Create Account';
      default:
        return 'Continue';
    }
  }

  void _handleNextOrSubmit() {
    if (currentStep == 1) {
      // Validate details form before proceeding
      if (!(_detailsFormKey.currentState?.validate() ?? false)) {
        return;
      }
    } else if (currentStep == 2) {
      // Validate auth form and agreements before submitting
      if (!(_authFormKey.currentState?.validate() ?? false) || !agreeTerms || !agreePrivacy) {
        if (!agreeTerms || !agreePrivacy) {
          _showError('Please agree to the terms and privacy policy');
        }
        return;
      }
    } else if (!_validateCurrentStep()) {
      if (currentStep == 0 && selectedUserType == null) {
        _showError('Please select an account type');
      }
      return;
    }

    if (currentStep < totalSteps - 1) {
      _nextStep();
    } else {
      _handleSignUp();
    }
  }

  Future<void> _handleSignUp() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Here you would integrate with your authentication service
      // For now, we'll simulate the signup process
      await Future.delayed(const Duration(seconds: 2));
      
      // Navigate directly to home page (skip OTP verification)
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    } catch (e) {
      _showError('Sign up failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
