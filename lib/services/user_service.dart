import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum UserRole { student, teacher, school }

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for users
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Create or update user profile with role
  Future<void> createUserProfile({
    required String userId,
    required String email,
    required UserRole role,
    String? name,
    String? schoolName,
    String? phoneNumber,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('UserService: Creating profile for user: $userId, email: $email, role: $role');
      
      final userData = {
        'userId': userId,
        'email': email.toLowerCase(),
        'role': role.name,
        'name': name,
        'schoolName': schoolName,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await _usersCollection.doc(userId).set(userData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
          
      print('UserService: Profile created successfully');
    } catch (e) {
      print('UserService Error creating user profile: $e');
      rethrow;
    }
  }

  /// Get user profile by user ID
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Get user role by user ID
  Future<UserRole?> getUserRole(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile != null && profile['role'] != null) {
        final roleString = profile['role'] as String;
        return UserRole.values.firstWhere(
          (role) => role.name == roleString,
          orElse: () => UserRole.student, // Default to student
        );
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Get user role by email (for Google sign-in routing)
  Future<UserRole?> getUserRoleByEmail(String email) async {
    try {
      print('UserService: Looking up role for email: $email');
      
      final querySnapshot = await _usersCollection
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      print('UserService: Query returned ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final roleString = userData['role'] as String?;
        
        print('UserService: Found role string: $roleString');
        
        if (roleString != null) {
          final role = UserRole.values.firstWhere(
            (role) => role.name == roleString,
            orElse: () => UserRole.student,
          );
          print('UserService: Parsed role: $role');
          return role;
        }
      } else {
        print('UserService: No user found with email: $email');
      }
      return null;
    } catch (e) {
      print('UserService Error getting user role by email: $e');
      return null;
    }
  }

  /// Update user's last login time
  Future<void> updateLastLogin(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  /// Update user role
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      await _usersCollection.doc(userId).update({
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  /// Check if user exists by email
  Future<bool> userExistsByEmail(String email) async {
    try {
      final querySnapshot = await _usersCollection
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

  /// Get current user's role
  Future<UserRole?> getCurrentUserRole() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return await getUserRole(currentUser.uid);
    }
    return null;
  }

  /// Store teacher-specific data
  Future<void> storeTeacherData({
    required String userId,
    required String name,
    required String email,
    required String phoneNumber,
    required String schoolName,
    String? teachingGrade,
    List<String>? subjects,
    int? yearsExperience,
    String? teacherId,
  }) async {
    try {
      final teacherData = {
        'name': name,
        'email': email.toLowerCase(),
        'phoneNumber': phoneNumber,
        'schoolName': schoolName,
        'teachingGrade': teachingGrade,
        'subjects': subjects ?? [],
        'yearsExperience': yearsExperience,
        'teacherId': teacherId,
        'role': UserRole.teacher.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await _usersCollection.doc(userId).set(teacherData, SetOptions(merge: true));
    } catch (e) {
      print('Error storing teacher data: $e');
      rethrow;
    }
  }

  /// Store student-specific data
  Future<void> storeStudentData({
    required String userId,
    required String name,
    required String email,
    required String phoneNumber,
    required String schoolName,
    required String grade,
    required int age,
    required String guardianName,
    required String guardianEmail,
    required String guardianPhone,
  }) async {
    try {
      final studentData = {
        'name': name,
        'email': email.toLowerCase(),
        'phoneNumber': phoneNumber,
        'schoolName': schoolName,
        'grade': grade,
        'age': age,
        'guardianName': guardianName,
        'guardianEmail': guardianEmail.toLowerCase(),
        'guardianPhone': guardianPhone,
        'role': UserRole.student.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await _usersCollection.doc(userId).set(studentData, SetOptions(merge: true));
    } catch (e) {
      print('Error storing student data: $e');
      rethrow;
    }
  }

  /// Store school-specific data
  Future<void> storeSchoolData({
    required String userId,
    required String institutionName,
    required String email,
    required String contactPersonName,
    required String phoneNumber,
    required String region,
    String? address,
    int? studentCount,
    int? teacherCount,
  }) async {
    try {
      final schoolData = {
        'institutionName': institutionName,
        'name': institutionName, // For consistency
        'email': email.toLowerCase(),
        'contactPersonName': contactPersonName,
        'phoneNumber': phoneNumber,
        'region': region,
        'address': address,
        'studentCount': studentCount,
        'teacherCount': teacherCount,
        'role': UserRole.school.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await _usersCollection.doc(userId).set(schoolData, SetOptions(merge: true));
    } catch (e) {
      print('Error storing school data: $e');
      rethrow;
    }
  }

  /// Get all teachers for a specific school
  Future<List<Map<String, dynamic>>> getTeachersForSchool(String schoolName) async {
    try {
      final querySnapshot = await _usersCollection
          .where('role', isEqualTo: UserRole.teacher.name)
          .where('schoolName', isEqualTo: schoolName)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting teachers for school: $e');
      return [];
    }
  }

  /// Get all students for a specific school
  Future<List<Map<String, dynamic>>> getStudentsForSchool(String schoolName) async {
    try {
      final querySnapshot = await _usersCollection
          .where('role', isEqualTo: UserRole.student.name)
          .where('schoolName', isEqualTo: schoolName)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting students for school: $e');
      return [];
    }
  }

  /// Navigate to appropriate home page based on user role
  static void navigateToHomePage(BuildContext context, UserRole? role) {
    switch (role) {
      case UserRole.student:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case UserRole.teacher:
        Navigator.pushReplacementNamed(context, '/teacher');
        break;
      case UserRole.school:
        Navigator.pushReplacementNamed(context, '/school');
        break;
      default:
        // Default to student home for unknown roles
        Navigator.pushReplacementNamed(context, '/home');
        break;
    }
  }
}