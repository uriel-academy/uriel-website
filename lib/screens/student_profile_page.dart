import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
class StudentProfilePage extends StatefulWidget {
  /// Accept an injectable user service (useful for tests).
  final IUserService userService;

  /// Optional test overrides to avoid touching Firebase in widget tests.
  final String? testUserId;
  final String? testUserEmail;

  /// If [isNewUser] is true the form will be non-blocking (fields are optional)
  /// and the page will display helpful guidance for first-time users.
  final bool isNewUser;

  const StudentProfilePage({
    Key? key,
    IUserService? userService,
    this.testUserId,
    this.testUserEmail,
    this.isNewUser = false,
  })  : userService = userService ?? const _DefaultUserService(),
        super(key: key);

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

// Default concrete implementation wrapper so widget can accept a const default.
class _DefaultUserService implements IUserService {
  const _DefaultUserService();

  @override
  Future<void> storeStudentData({
    required String userId,
    String? firstName,
    String? lastName,
    String? name,
    required String email,
    required String phoneNumber,
    required String schoolName,
    required String grade,
    required int age,
    required String guardianName,
    required String guardianEmail,
    required String guardianPhone,
  }) {
    return UserService().storeStudentData(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      schoolName: schoolName,
      grade: grade,
      age: age,
      guardianName: guardianName,
      guardianEmail: guardianEmail,
      guardianPhone: guardianPhone,
    );
  }
}

class _StudentProfilePageState extends State<StudentProfilePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _schoolController = TextEditingController();
  final _ageController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianEmailController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEditingPassword = false;
  String? _profileImageUrl;
  String _selectedClass = 'JHS FORM 1';
  String? _selectedPresetAvatar; // Track selected preset avatar
  
  final List<String> _classes = [
    'JHS FORM 1',
    'JHS FORM 2',
    'JHS FORM 3',
    'SHS FORM 1',
    'SHS FORM 2',
    'SHS FORM 3'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _ageController.dispose();
    _guardianNameController.dispose();
    _guardianEmailController.dispose();
    _guardianPhoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // If testUserId provided, skip Firestore load and use test overrides
    if (widget.testUserId != null) {
      setState(() {
        _emailController.text = widget.testUserEmail ?? '';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Set a timeout for the Firestore operation
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw Exception('Connection timeout');
              },
            );
            
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _firstNameController.text = data['firstName'] ?? '';
            _lastNameController.text = data['lastName'] ?? '';
            _emailController.text = user.email ?? '';
            _phoneController.text = data['phoneNumber'] ?? data['phone'] ?? '';
            _schoolController.text = data['school'] ?? data['schoolName'] ?? '';
            _selectedClass = data['class'] ?? data['grade'] ?? 'JHS FORM 1';
            // Only set age if it exists and is not 0
            final age = data['age'];
            _ageController.text = (age != null && age != 0) ? age.toString() : '';
            _guardianNameController.text = data['guardianName'] ?? '';
            _guardianEmailController.text = data['guardianEmail'] ?? '';
            _guardianPhoneController.text = data['guardianPhone'] ?? '';
            _profileImageUrl = data['profileImageUrl'];
            _selectedPresetAvatar = data['presetAvatar'];
          });
        } else {
          // Set default values from auth
          setState(() {
            _emailController.text = user.email ?? '';
            if (user.displayName != null) {
              final names = user.displayName!.split(' ');
              _firstNameController.text = names.first;
              if (names.length > 1) {
                _lastNameController.text = names.sublist(1).join(' ');
              }
            }
            _profileImageUrl = user.photoURL;
          });
        }
      } catch (e) {
        // Handle offline or connection errors gracefully
        // Set default values from auth instead of showing error
        setState(() {
          _emailController.text = user.email ?? '';
          if (user.displayName != null) {
            final names = user.displayName!.split(' ');
            _firstNameController.text = names.first;
            if (names.length > 1) {
              _lastNameController.text = names.sublist(1).join(' ');
            }
          }
          _profileImageUrl = user.photoURL;
        });
        
        // Only log the error, don't show error message to user for connectivity issues
        debugPrint('Unable to load user profile data (offline or connection issue): $e');
      }
    }
  }

  Future<void> _showAvatarPicker() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Profile Picture',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preset Avatars
              Text(
                'Choose from presets:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildPresetAvatar('assets/profile_pic_1.png'),
                  _buildPresetAvatar('assets/profile_pic_2.png'),
                  _buildPresetAvatar('assets/profile_pic_3.png'),
                  _buildPresetAvatar('assets/profile_pic_4.png'),
                ],
              ),
              const SizedBox(height: 16),
              // Use Default (Initial)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _useDefaultAvatar();
                },
                icon: const Icon(Icons.person),
                label: Text(
                  'Use Default (Name Initial)',
                  style: GoogleFonts.montserrat(),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPresetAvatar(String assetPath) {
    final isSelected = _selectedPresetAvatar == assetPath;
    
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _selectPresetAvatar(assetPath);
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFFD62828) : Colors.grey[300]!,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: CircleAvatar(
          radius: 30,
          backgroundImage: AssetImage(assetPath),
        ),
      ),
    );
  }
  
  Future<void> _selectPresetAvatar(String assetPath) async {
    setState(() {
      _selectedPresetAvatar = assetPath;
      _profileImageUrl = null;
    });
    
    // Save to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'presetAvatar': assetPath,
          'profileImageUrl': FieldValue.delete(), // Delete custom photo field
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        // Clear Auth photo URL since we're using preset
        await user.updatePhotoURL(null);
        
        _showSuccessSnackBar('Profile picture updated!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update profile picture: $e');
    }
  }
  
  Future<void> _useDefaultAvatar() async {
    setState(() {
      _selectedPresetAvatar = null;
      _profileImageUrl = null;
    });
    
    // Save to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'presetAvatar': FieldValue.delete(),
          'profileImageUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        await user.updatePhotoURL(null);
        
        _showSuccessSnackBar('Using default profile picture!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update profile picture: $e');
    }
  }



  Future<void> _saveProfile() async {
    // If this is a new user we don't enforce required-field validation here.
    if (!widget.isNewUser && !_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields correctly');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Determine user id and email (allow test overrides)
      final userId = widget.testUserId ?? FirebaseAuth.instance.currentUser?.uid;
      final userEmail = widget.testUserEmail ?? FirebaseAuth.instance.currentUser?.email;

      if (userId == null || userEmail == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('Saving profile for user: $userId');

      final newSchool = _schoolController.text.trim();
      final newClass = _selectedClass;

      // Parse age
      final ageText = _ageController.text.trim();
      final age = int.tryParse(ageText) ?? 0;

      // Call the injected service to persist student-specific data (handles linking)
      await widget.userService.storeStudentData(
        userId: userId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: userEmail,
        phoneNumber: _phoneController.text.trim(),
        schoolName: newSchool,
        grade: newClass,
        age: age,
        guardianName: _guardianNameController.text.trim(),
        guardianEmail: _guardianEmailController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
      );

      // Update Auth display name if available
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null) {
          await authUser.updateDisplayName(
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
          );
        }
      } catch (_) {}

      _showSuccessSnackBar('Profile updated successfully!');
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _showErrorSnackBar('Failed to update profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignTeacher(String studentUid, String school, String className) async {
    try {
      debugPrint('Reassigning student to new teacher. School: $school, class: $className');
      
      // STEP 1: Remove from old teacher if exists
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUid)
          .get();
      
      final oldTeacherId = studentDoc.data()?['teacherId'];
      if (oldTeacherId != null) {
        debugPrint('Removing student from old teacher: $oldTeacherId');
        
        // Remove from old teacher's students subcollection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(oldTeacherId)
            .collection('students')
            .doc(studentUid)
            .delete();
        
        // Remove from studentSummaries collection
        await FirebaseFirestore.instance
            .collection('studentSummaries')
            .doc(studentUid)
            .delete();
      }
      
      // STEP 2: Find new teacher with matching school and grade
      debugPrint('Looking for new teacher with school: $school, class: $className');
      
      // Try with 'schoolName' field first
      var teachersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('isTeacher', isEqualTo: true)
          .where('schoolName', isEqualTo: school)
          .where('grade', isEqualTo: className)
          .limit(1)
          .get();
      
      // If not found, try with 'school' field
      if (teachersQuery.docs.isEmpty) {
        teachersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('isTeacher', isEqualTo: true)
            .where('school', isEqualTo: school)
            .where('grade', isEqualTo: className)
            .limit(1)
            .get();
      }
      
      // STEP 3: Link to new teacher if found
      if (teachersQuery.docs.isNotEmpty) {
        final newTeacherId = teachersQuery.docs.first.id;
        await _linkStudentToTeacher(studentUid, newTeacherId, school, className);
        debugPrint('✅ Student successfully assigned to new teacher: $newTeacherId');
      } else {
        // No teacher found - clear teacherId from student
        await FirebaseFirestore.instance
            .collection('users')
            .doc(studentUid)
            .update({
          'teacherId': FieldValue.delete(),
          'teacherAssignedAt': FieldValue.delete(),
        });
        debugPrint('⚠️ No teacher found for school: $school, class: $className. Cleared teacher assignment.');
      }
    } catch (e) {
      debugPrint('❌ Error assigning teacher: $e');
      // Don't show error to user, this is a background operation
    }
  }

  Future<void> _linkStudentToTeacher(String studentUid, String teacherId, String school, String className) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // Update student's document with new teacher reference
    final studentRef = FirebaseFirestore.instance.collection('users').doc(studentUid);
    batch.update(studentRef, {
      'teacherId': teacherId,
      'teacherAssignedAt': FieldValue.serverTimestamp(),
      'school': school,
      'class': className,
    });
    
    // Add student to new teacher's students subcollection
    final teacherStudentRef = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherId)
        .collection('students')
        .doc(studentUid);
    
    // Get fresh student data first
    final studentDocForSubcollection = await FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .get();
    final studentDataForSubcollection = studentDocForSubcollection.data() ?? {};
    
    batch.set(teacherStudentRef, {
      'firstName': studentDataForSubcollection['firstName'] ?? '',
      'lastName': studentDataForSubcollection['lastName'] ?? '',
      'email': studentDataForSubcollection['email'] ?? '',
      'school': school,
      'grade': className,
      'addedAt': FieldValue.serverTimestamp(),
      'autoAssigned': true,
    }, SetOptions(merge: true));
    
    // Create/update studentSummaries entry for the new teacher
    final summaryRef = FirebaseFirestore.instance
        .collection('studentSummaries')
        .doc(studentUid);
    
    // Get student data for summary
    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .get();
    
    final studentData = studentDoc.data() ?? {};
    final firstName = studentData['firstName'] ?? '';
    final lastName = studentData['lastName'] ?? '';
    final email = studentData['email'] ?? '';
    
    batch.set(summaryRef, {
      'teacherId': teacherId,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': '$firstName $lastName'.trim(),
      'email': email,
      'school': school,
      'class': className,
      'normalizedSchool': _normalizeText(school),
      'normalizedClass': _normalizeText(className),
      // Include full performance data
      'totalXP': studentData['totalXP'] ?? studentData['xp'] ?? 0,
      'totalQuestions': studentData['totalQuestions'] ?? studentData['questionsSolved'] ?? 0,
      'subjectsCount': studentData['subjectsCount'] ?? studentData['subjectsSolved'] ?? 0,
      'avgPercent': studentData['avgPercent'] ?? studentData['accuracy'] ?? 0,
      'avatar': studentData['profileImageUrl'] ?? studentData['avatar'] ?? studentData['presetAvatar'],
      'rank': studentData['currentRankName'] ?? studentData['rankName'] ?? studentData['rank'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Commit all changes atomically
    await batch.commit();
  }
  
  String _normalizeText(String text) {
    // Normalize text for matching (lowercase, remove special chars)
    return text.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please fill all password fields');
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }
    
    if (_newPasswordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(_newPasswordController.text);
      
      // Clear password fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      
      setState(() => _isEditingPassword = false);
      
      _showSuccessSnackBar('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to change password';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'The password provided is too weak';
      }
      _showErrorSnackBar(message);
    } catch (e) {
      _showErrorSnackBar('Failed to change password: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.35,
          vertical: MediaQuery.of(context).size.height * 0.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.35,
          vertical: MediaQuery.of(context).size.height * 0.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Profile Settings',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            // Informational note for first-time users
            if (widget.isNewUser) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow[200]!),
                ),
                child: Text(
                  'Note: For legal reasons, students under 18 years need to update guardian information. You may fill it now or later in your profile.',
                  style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            Text(
              'Manage your account information and preferences',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[600],
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            // Profile Picture Section
            _buildProfilePictureSection(isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            // Profile Information Form
            _buildProfileForm(isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            // Guardian/Parent Information Section
            _buildGuardianInfoSection(isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            // Password Section
            _buildPasswordSection(isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 32 : 48),
            
            // Action Buttons
            _buildActionButtons(isSmallScreen),
            
            // Add extra bottom padding for mobile
            if (isSmallScreen) const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Profile Picture',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 24),
          
          // Profile Picture
          Stack(
            children: [
              CircleAvatar(
                radius: isSmallScreen ? 50 : 60,
                backgroundColor: const Color(0xFF1A1E3F),
                backgroundImage: _selectedPresetAvatar != null
                    ? AssetImage(_selectedPresetAvatar!)
                    : (_profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null) as ImageProvider?,
                child: (_profileImageUrl == null && _selectedPresetAvatar == null)
                    ? Text(
                        _firstNameController.text.isNotEmpty
                            ? _firstNameController.text[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 24 : 28,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              
              // Edit button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Tap the camera icon to change your profile picture',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // First Name
            _buildTextField(
              controller: _firstNameController,
              label: 'First Name',
              icon: Icons.person,
              validator: (value) {
                if (widget.isNewUser) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Last Name
            _buildTextField(
              controller: _lastNameController,
              label: 'Last Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (widget.isNewUser) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your last name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Age
            _buildTextField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (widget.isNewUser) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your age';
                }
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed <= 0 || parsed > 120) {
                  return 'Please enter a valid age';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Email (read-only)
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              readOnly: true,
              enabled: false,
            ),
            
            const SizedBox(height: 16),
            
            // Phone
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number (Optional)',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 16),
            
            // School
            _buildTextField(
              controller: _schoolController,
              label: 'School',
              icon: Icons.school,
              validator: (value) {
                if (widget.isNewUser) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your school name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Class Dropdown
            Text(
              'Class',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedClass,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: Icon(
                    Icons.class_,
                    color: Colors.grey[600],
                  ),
                ),
                dropdownColor: Colors.white,
                style: GoogleFonts.montserrat(
                  color: Colors.black87,
                ),
                items: _classes.map((String className) {
                  return DropdownMenuItem<String>(
                    value: className,
                    child: Text(className),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedClass = newValue);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardianInfoSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guardian / Parent Information',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'For students under 18 years old',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Guardian Name
          _buildTextField(
            controller: _guardianNameController,
            label: 'Guardian Name',
            icon: Icons.person,
            validator: (value) {
              if (widget.isNewUser) return null;
              if (value == null || value.trim().isEmpty) {
                return 'Please enter guardian name';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Guardian Email
          _buildTextField(
            controller: _guardianEmailController,
            label: 'Guardian Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (widget.isNewUser) return null;
              if (value == null || value.trim().isEmpty) {
                return 'Please enter guardian email';
              }
              final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Guardian Phone
          _buildTextField(
            controller: _guardianPhoneController,
            label: 'Guardian Phone (Optional)',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (cleaned.length < 7) return 'Please enter a valid phone number';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              
              TextButton(
                onPressed: () {
                  setState(() => _isEditingPassword = !_isEditingPassword);
                  if (!_isEditingPassword) {
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  }
                },
                child: Text(
                  _isEditingPassword ? 'Cancel' : 'Change Password',
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (_isEditingPassword) ...[
            const SizedBox(height: 16),
            
            // Current Password
            _buildTextField(
              controller: _currentPasswordController,
              label: 'Current Password',
              icon: Icons.lock,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // New Password
            _buildTextField(
              controller: _newPasswordController,
              label: 'New Password',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Confirm Password
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Update Password',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Password is hidden for security',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildActionButtons(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save Profile',
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    bool readOnly = false,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        
        TextFormField(
          key: Key('field_${label.replaceAll(' ', '_')}'),
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          keyboardType: keyboardType,
          style: GoogleFonts.montserrat(
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD62828)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: enabled 
                ? (Colors.grey[50])
                : Colors.grey[200],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
