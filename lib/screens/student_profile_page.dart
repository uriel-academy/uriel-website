import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({
    Key? key,
  }) : super(key: key);

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
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
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEditingPassword = false;
  String? _profileImageUrl;
  String _selectedClass = 'JHS Form 1';
  String? _selectedPresetAvatar; // Track selected preset avatar
  
  final List<String> _classes = [
    'JHS Form 1',
    'JHS Form 2',
    'JHS Form 3',
    'SHS Form 1',
    'SHS Form 2',
    'SHS Form 3'
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
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
            _phoneController.text = data['phone'] ?? '';
            _schoolController.text = data['school'] ?? '';
            _selectedClass = data['class'] ?? 'JHS Form 1';
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
          'profileImageUrl': null, // Clear custom photo
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
          'presetAvatar': null,
          'profileImageUrl': null,
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
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields correctly');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isLoading = false);
        return;
      }
      
      debugPrint('Saving profile for user: ${user.uid}');
      debugPrint('Data: ${_firstNameController.text}, ${_lastNameController.text}');
      
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'school': _schoolController.text.trim(),
        'class': _selectedClass,
        'profileImageUrl': _profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('Firestore update completed');
      
      // Update Auth profile
      await user.updateDisplayName(
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      );
      
      debugPrint('Auth profile update completed');
      _showSuccessSnackBar('Profile updated successfully!');
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _showErrorSnackBar('Failed to update profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
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
            const SizedBox(height: 8),
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
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your last name';
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
