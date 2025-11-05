import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

/// Navigation helper to get user's role-specific home route
/// This ensures users always return to their appropriate homepage
class NavigationHelper {
  /// Get the home route based on user's role
  /// Returns:
  /// - '/teacher' for teachers
  /// - '/school-admin' for school admins
  /// - '/admin' for super admins
  /// - '/home' for students (default)
  /// - '/landing' if not authenticated
  static Future<String> getUserHomeRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // If not logged in, return landing page
    if (user == null) {
      return '/landing';
    }
    
    // Get user role
    UserRole? role = await UserService().getCurrentUserRole();
    
    // If role not found by uid, try by email as fallback
    if (role == null && user.email != null) {
      try {
        role = await UserService().getUserRoleByEmail(user.email!);
      } catch (e) {
        // Ignore and default to student
      }
    }
    
    // Return route based on role
    switch (role) {
      case UserRole.teacher:
        return '/teacher';
      case UserRole.schoolAdmin:
        return '/school-admin';
      case UserRole.student:
      default:
        return '/home';
    }
  }
  
  /// Check if user has admin privileges
  /// Note: Currently, super admin is determined separately
  /// This checks for school admin role
  static Future<bool> isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final role = await UserService().getCurrentUserRole();
    return role == UserRole.schoolAdmin;
  }
  
  /// Check if user is a teacher
  static Future<bool> isTeacher() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final role = await UserService().getCurrentUserRole();
    return role == UserRole.teacher;
  }
  
  /// Check if user is a student
  static Future<bool> isStudent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final role = await UserService().getCurrentUserRole();
    return role == UserRole.student || role == null; // Default to student
  }
}
