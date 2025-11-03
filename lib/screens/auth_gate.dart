import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'landing_page.dart';
import 'home_page.dart'; // Import StudentHomePage
import 'teacher_home_page.dart'; // Import TeacherHomePage
import 'school_admin_home_page.dart'; // Import SchoolAdminHomePage

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData) {
          // User is logged in, route based on role
          // Try to resolve the user's role by uid first; if not available, fall back to email lookup.
          return FutureBuilder<UserRole?>(
            future: () async {
              final user = snapshot.data!;
              // Try by uid
              var role = await UserService().getCurrentUserRole();
              if (role != null) return role;
              // If missing, try by email as a fallback (helps when user doc exists under a different uid or was just created)
              try {
                final email = user.email;
                if (email != null && email.isNotEmpty) {
                  final byEmail = await UserService().getUserRoleByEmail(email);
                  return byEmail;
                }
              } catch (e) {
                // ignore
              }
              return null;
            }(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final userRole = roleSnapshot.data;

              // Update last login time
              if (snapshot.data != null) {
                UserService().updateLastLogin(snapshot.data!.uid);
              }

              // Route based on user role
              switch (userRole) {
                case UserRole.teacher:
                  return const TeacherHomePage();
                case UserRole.schoolAdmin:
                  return const SchoolAdminHomePage();
                case UserRole.student:
                default:
                  return const StudentHomePage();
              }
            },
          );
        } else {
          // User is not logged in - show landing page
          return const LandingPage();
        }
      },
    );
  }
}
