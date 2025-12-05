import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Minimal interface to allow injecting/mocking user persistence in tests.
abstract class IUserService {
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
  });
}

enum UserRole { student, teacher, schoolAdmin }

class UserService implements IUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for users
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Normalize school/class names for matching (same logic as Cloud Functions)
  /// Removes common noise words and non-alphanumeric characters
  String? _normalizeSchoolClass(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    
    String s = raw.toLowerCase();
    
    // Remove common noise words
    final noiseWords = ['school', 'college', 'high', 'senior', 'basic', 'jhs', 'shs', 'form', 'the'];
    for (final word in noiseWords) {
      s = s.replaceAll(RegExp('\\b$word\\b'), ' ');
    }
    
    // Replace non-alphanumeric with spaces
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    
    // Collapse whitespace and replace with underscore
    s = s.replaceAll(RegExp(r'\s+'), '_').trim();
    
    return s.isEmpty ? null : s;
  }

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
      debugPrint('UserService: Creating profile for user: $userId, email: $email, role: $role');
      
      // Don't write 'role' from the client side - roles must be assigned by admin/server.
      final userData = {
        'userId': userId,
        'email': email.toLowerCase(),
        'name': name,
        'schoolName': schoolName,
        'phoneNumber': phoneNumber,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await _usersCollection.doc(userId).set(userData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
          
      debugPrint('UserService: Profile created successfully');
    } catch (e) {
      debugPrint('UserService Error creating user profile: $e');
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
      debugPrint('Error getting user profile: $e');
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
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  /// Get user role by email (for Google sign-in routing)
  Future<UserRole?> getUserRoleByEmail(String email) async {
    try {
      debugPrint('UserService: Looking up role for email: $email');
      
      final querySnapshot = await _usersCollection
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      debugPrint('UserService: Query returned ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final roleString = userData['role'] as String?;
        
        debugPrint('UserService: Found role string: $roleString');
        
        if (roleString != null) {
          final role = UserRole.values.firstWhere(
            (role) => role.name == roleString,
            orElse: () => UserRole.student,
          );
          debugPrint('UserService: Parsed role: $role');
          return role;
        }
      } else {
        debugPrint('UserService: No user found with email: $email');
      }
      return null;
    } catch (e) {
      debugPrint('UserService Error getting user role by email: $e');
      return null;
    }
  }

  /// Update user's last login time and last seen
  Future<void> updateLastLogin(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  /// Update user's last seen time (activity tracking)
  Future<void> updateLastSeen(String userId) async {
    try {
      await _usersCollection.doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last seen: $e');
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
      debugPrint('Error updating user role: $e');
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
      debugPrint('Error checking if user exists: $e');
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
    String? firstName,
    String? lastName,
    String? name,
    required String email,
    required String phoneNumber,
    required String schoolName,
    required String teachingClass, // Changed from teachingGrade to match schema
    List<String>? subjects,
    int? yearsExperience,
    String? teacherId,
    String? institutionCode,
  }) async {
    try {
      // Parse firstName and lastName from name if not provided
      String fName = firstName ?? '';
      String lName = lastName ?? '';
      
      if (fName.isEmpty && lName.isEmpty && name != null && name.isNotEmpty) {
        final parts = name.trim().split(' ');
        fName = parts.first;
        lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
      
      // Check if school or class has changed
      final teacherDoc = await _usersCollection.doc(userId).get();
      final oldData = teacherDoc.data() as Map<String, dynamic>?;
      
      if (oldData != null) {
        final oldSchool = oldData['school'] ?? oldData['schoolName'] ?? '';
        final oldClass = oldData['class'] ?? oldData['grade'] ?? oldData['teachingGrade'] ?? '';
        
        if (oldSchool != schoolName || oldClass != teachingClass) {
          debugPrint('Teacher $userId changed from $oldSchool/$oldClass to $schoolName/$teachingClass');
          
          // Clean up old student associations
          await _cleanupOldTeacherAssociations(userId);
        }
      }
      
      final teacherData = {
        'role': UserRole.teacher.name,
        'isTeacher': true, // Flag for queries
        'firstName': fName,
        'lastName': lName,
        'name': name ?? '$fName $lName'.trim(),
        'email': email.toLowerCase(),
        'phoneNumber': phoneNumber,
        'school': schoolName, // Primary field for aggregation
        'schoolName': schoolName, // Backwards compatibility
        'class': teachingClass, // Primary field - the class they teach
        'grade': teachingClass, // For student-teacher matching
        'teachingGrade': teachingClass, // Backwards compatibility
        'subjects': subjects ?? [],
        'yearsExperience': yearsExperience,
        'teacherId': teacherId,
        'institutionCode': institutionCode,
        'createdAt': oldData?['createdAt'] ?? FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _usersCollection.doc(userId).set(teacherData, SetOptions(merge: true));
      
      // When teacher profile is updated, find and link matching students
      await _linkMatchingStudents(userId, schoolName, teachingClass);
    } catch (e) {
      debugPrint('Error storing teacher data: $e');
      rethrow;
    }
  }

  /// Clean up old teacher-student associations when teacher changes school/class
  Future<void> _cleanupOldTeacherAssociations(String teacherId) async {
    try {
      debugPrint('Cleaning up old associations for teacher $teacherId');
      
      // 1. Delete all entries in teacher's students subcollection
      final studentsSnapshot = await _usersCollection
          .doc(teacherId)
          .collection('students')
          .get();
      
      final batch = _firestore.batch();
      
      for (var doc in studentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // 2. Delete all studentSummaries entries for this teacher
      final summariesSnapshot = await _firestore
          .collection('studentSummaries')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      for (var doc in summariesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // 3. Clear teacherId from all students who had this teacher
      final studentsWithTeacherSnapshot = await _usersCollection
          .where('role', isEqualTo: UserRole.student.name)
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      for (var doc in studentsWithTeacherSnapshot.docs) {
        batch.update(doc.reference, {
          'teacherId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      debugPrint('Cleaned up ${studentsSnapshot.docs.length} students subcollection entries, '
          '${summariesSnapshot.docs.length} studentSummaries entries, '
          'and ${studentsWithTeacherSnapshot.docs.length} student teacherId references');
    } catch (e) {
      debugPrint('Error cleaning up old teacher associations: $e');
    }
  }

  /// Link students with matching school and grade to this teacher
  Future<void> _linkMatchingStudents(String teacherId, String schoolName, String teachingClass) async {
    try {
      final normalizedSchool = _normalizeSchoolClass(schoolName);
      final normalizedClass = _normalizeSchoolClass(teachingClass);
      
      if (normalizedSchool == null || normalizedClass == null) {
        debugPrint('Could not normalize teacher school/class: $schoolName, $teachingClass');
        return;
      }
      
      // Get ALL students and filter by normalized school/class
      // This ensures we catch all variations of the same school/class name
      final allStudentsQuery = await _usersCollection
          .where('role', isEqualTo: UserRole.student.name)
          .get();
      
      debugPrint('Checking ${allStudentsQuery.docs.length} students for matches with $schoolName/$teachingClass');
      
      final batch = _firestore.batch();
      int matchCount = 0;
      
      for (var studentDoc in allStudentsQuery.docs) {
        final studentId = studentDoc.id;
        final studentData = studentDoc.data() as Map<String, dynamic>?;
        
        if (studentData == null) continue;
        
        final studentSchool = studentData['school'] ?? '';
        final studentGrade = studentData['grade'] ?? studentData['class'] ?? '';
        
        // Normalize and compare
        final normalizedStudentSchool = _normalizeSchoolClass(studentSchool);
        final normalizedStudentGrade = _normalizeSchoolClass(studentGrade);
        
        if (normalizedStudentSchool == normalizedSchool && normalizedStudentGrade == normalizedClass) {
          matchCount++;
          debugPrint('  ✅ Matching student: ${studentData['firstName']} ${studentData['lastName']} ($studentSchool/$studentGrade)');
          
          // Update student's teacherId
          batch.update(_usersCollection.doc(studentId), {
            'teacherId': teacherId,
            'teacherAssignedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          // Add to teacher's students subcollection
          batch.set(
            _usersCollection.doc(teacherId).collection('students').doc(studentId),
            {
              'firstName': studentData['firstName'] ?? '',
              'lastName': studentData['lastName'] ?? '',
              'email': studentData['email'] ?? '',
              'school': studentSchool,
              'grade': studentGrade,
              'linkedAt': FieldValue.serverTimestamp(),
              'autoAssigned': true,
            },
          );
          
          // Add to studentSummaries collection with full performance data
          batch.set(
            _firestore.collection('studentSummaries').doc(studentId),
            {
              'teacherId': teacherId,
              'firstName': studentData['firstName'] ?? '',
              'lastName': studentData['lastName'] ?? '',
              'email': studentData['email'] ?? '',
              'school': studentSchool,
              'class': studentGrade,
              'normalizedSchool': normalizedStudentSchool,
              'normalizedClass': normalizedStudentGrade,
              // Include performance data from user document
              'totalXP': studentData['totalXP'] ?? studentData['xp'] ?? 0,
              'totalQuestions': studentData['totalQuestions'] ?? studentData['questionsSolved'] ?? 0,
              'subjectsCount': studentData['subjectsCount'] ?? studentData['subjectsSolved'] ?? 0,
              'avgPercent': studentData['avgPercent'] ?? studentData['accuracy'] ?? 0,
              'avatar': studentData['profileImageUrl'] ?? studentData['avatar'] ?? studentData['presetAvatar'],
              'rank': studentData['currentRankName'] ?? studentData['rankName'] ?? studentData['rank'],
              'displayName': '${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}'.trim(),
              'lastUpdated': FieldValue.serverTimestamp(),
            },
          );
        }
      }
      
      if (matchCount > 0) {
        await batch.commit();
        debugPrint('Successfully linked $matchCount students to teacher $teacherId');
      } else {
        debugPrint('No matching students found for teacher $teacherId');
      }
    } catch (e) {
      debugPrint('Error linking matching students: $e');
    }
  }

  /// Store student-specific data
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
  }) async {
    try {
      // Parse firstName and lastName from name if not provided
      String fName = firstName ?? '';
      String lName = lastName ?? '';
      
      if (fName.isEmpty && lName.isEmpty && name != null && name.isNotEmpty) {
        final parts = name.trim().split(' ');
        fName = parts.first;
        lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
      
      // Find matching teacher based on normalized school and class
      String? matchedTeacherId;
      try {
        final normalizedSchool = _normalizeSchoolClass(schoolName);
        final normalizedClass = _normalizeSchoolClass(grade);
        
        if (normalizedSchool == null || normalizedClass == null) {
          debugPrint('Could not normalize school or class: $schoolName, $grade');
        } else {
          final teachersQuery = await _usersCollection
              .where('role', isEqualTo: UserRole.teacher.name)
              .get();
          
          for (var doc in teachersQuery.docs) {
            final teacherData = doc.data() as Map<String, dynamic>?;
            if (teacherData == null) continue;
            
            final teacherSchool = _normalizeSchoolClass((teacherData['school'] ?? '').toString());
            final teacherClass = _normalizeSchoolClass((teacherData['class'] ?? '').toString());
            
            debugPrint('Comparing: Student($normalizedSchool, $normalizedClass) vs Teacher($teacherSchool, $teacherClass)');
            
            if (teacherSchool != null && teacherClass != null &&
                teacherSchool == normalizedSchool && teacherClass == normalizedClass) {
              matchedTeacherId = doc.id;
              debugPrint('✓ Matched student to teacher: ${doc.id} (${teacherData['firstName']} ${teacherData['lastName']})');
              break;
            }
          }
          
          if (matchedTeacherId == null) {
            debugPrint('✗ No teacher found for normalized school: $normalizedSchool, class: $normalizedClass');
          }
        }
      } catch (e) {
        debugPrint('Error finding matching teacher: $e');
      }
      
      // Client should not set role; leave role assignment to admin/server.
      final studentData = {
        'role': UserRole.student.name,
        'firstName': fName,
        'lastName': lName,
        'name': name ?? '$fName $lName'.trim(),
        'email': email.toLowerCase(),
        'phoneNumber': phoneNumber,
        'school': schoolName, // Use 'school' as primary field
        'schoolName': schoolName, // Keep for backwards compatibility
        'class': grade, // Use 'class' as primary field
        'grade': grade, // Keep for backwards compatibility
        'age': age,
        'guardianName': guardianName,
        'guardianEmail': guardianEmail.toLowerCase(),
        'guardianPhone': guardianPhone,
        'teacherId': matchedTeacherId, // Assign matched teacher
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await _usersCollection.doc(userId).set(studentData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error storing student data: $e');
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
    String? institutionCode,
  }) async {
    try {
      // Avoid setting 'role' here from the client side.
      final schoolData = {
        'role': UserRole.schoolAdmin.name,
        'institutionName': institutionName,
        'name': institutionName, // For consistency
        'email': email.toLowerCase(),
        'contactPersonName': contactPersonName,
        'phoneNumber': phoneNumber,
        'region': region,
        'address': address,
        'studentCount': studentCount,
        'teacherCount': teacherCount,
        'institutionCode': institutionCode,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await _usersCollection.doc(userId).set(schoolData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error storing school data: $e');
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
      debugPrint('Error getting teachers for school: $e');
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
      debugPrint('Error getting students for school: $e');
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
      case UserRole.schoolAdmin:
        Navigator.pushReplacementNamed(context, '/school-admin');
        break;
      default:
        // Default to student home for unknown roles
        Navigator.pushReplacementNamed(context, '/home');
        break;
    }
  }
}
