import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'landing_page.dart';
import 'home_page.dart'; // Import StudentHomePage
import 'school_dashboard.dart'; // Import SchoolDashboardPage
import 'teacher_home_page.dart'; // Import TeacherHomePage

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
          return FutureBuilder<UserRole?>(
            future: UserService().getCurrentUserRole(),
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
                case UserRole.school:
                  return const SchoolDashboardPage();
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
