import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/landing_page.dart'; // Import LandingPage for first load
import 'screens/sign_in.dart' as sign_in; // Import your sign-in page with alias
import 'screens/auth_gate.dart'; // Import AuthGate from dedicated file
import 'screens/home_page.dart'; // Import StudentHomePage
import 'screens/school_dashboard.dart'; // Import SchoolDashboardPage
import 'screens/teacher_dashboard.dart'; // Import TeacherDashboardPage
import 'screens/parent_dashboard.dart'; // Import ParentDashboardPage
import 'screens/comprehensive_admin_dashboard.dart'; // Import ComprehensiveAdminDashboard
import 'screens/about_us.dart'; // Import About Us page
import 'screens/privacy_policy.dart'; // Import Privacy Policy page
import 'screens/terms_of_service.dart'; // Import Terms of Service page
import 'screens/contact.dart'; // Import Contact page
import 'screens/faq.dart'; // Import FAQ page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uriel Academy',
      debugShowCheckedModeBanner: false,
      home: const LandingPage(), // Start with LandingPage (marketing page)
      routes: {
        '/landing': (_) => const LandingPage(),
        '/about': (_) => const AboutUsPage(),
        '/privacy': (_) => const PrivacyPolicyPage(),
        '/terms': (_) => const TermsOfServicePage(),
        '/contact': (_) => const ContactPage(),
        '/faq': (_) => const FAQPage(),
        '/login': (_) => const sign_in.SignInPage(),
        '/auth': (_) => const AuthGate(), // AuthGate for post-login routing
        '/home': (_) => const StudentHomePage(),
        '/dashboard': (_) => const StudentHomePage(),
        '/school': (_) => const SchoolDashboardPage(), // Add school dashboard route
        '/teacher': (_) => const TeacherDashboardPage(), // Add teacher dashboard route
        '/parent': (_) => const ParentDashboardPage(), // Add parent dashboard route
        '/admin': (_) => const ComprehensiveAdminDashboard(), // Add comprehensive admin dashboard route
      },
    );
  }
}

// Note: The flow is:
// 1. uriel.academy → LandingPage (marketing page with sign-up/sign-in buttons)
// 2. User clicks Sign In/Sign Up → respective pages
// 3. After successful auth → routes to /home (students) or /school (teachers/schools) based on user role

