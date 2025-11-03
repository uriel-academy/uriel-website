import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/connection_service.dart'; // Import connection monitoring service
import 'screens/landing_page.dart'; // Import LandingPage for first load
import 'screens/sign_in.dart' as sign_in; // Import your sign-in page with alias
import 'screens/auth_gate.dart'; // Import AuthGate from dedicated file
import 'screens/home_page.dart'; // Import StudentHomePage
import 'screens/teacher_home_page.dart'; // New TeacherHomePage (student-home replica for teachers)
import 'screens/school_admin_home_page.dart'; // School Admin Homepage
import 'screens/parent_dashboard.dart'; // Import ParentDashboardPage
import 'screens/comprehensive_admin_dashboard.dart'; // Import ComprehensiveAdminDashboard
import 'screens/admin_setup_page.dart'; // Import Admin Setup page
import 'screens/rme_debug_page.dart'; // Import RME Debug Page
import 'screens/about_us.dart'; // Import About Us page
import 'screens/privacy_policy.dart'; // Import Privacy Policy page
import 'screens/terms_of_service.dart'; // Import Terms of Service page
import 'screens/contact.dart'; // Import Contact page
import 'screens/faq.dart'; // Import FAQ page
import 'screens/pricing_page.dart'; // Import Pricing page
import 'screens/payment_page.dart'; // Import Payment page
import 'screens/uri_page.dart'; // New ChatGPT-like full page Uri
import 'screens/upload_note_page.dart'; // Upload notes page
import 'screens/note_viewer_page.dart'; // Note viewer page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use path-based URLs instead of hash-based (#) URLs for better SEO
  usePathUrlStrategy();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable local persistence so note text is immediately available offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Keep auth state persistent across page refreshes
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Start connection monitoring to detect and recover from disconnections
  ConnectionService().startMonitoring();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: MaterialApp(
        title: 'Uriel Academy',
        debugShowCheckedModeBanner: false,
        home: const AuthGate(), // Start with AuthGate (checks auth state automatically)
        onGenerateRoute: (settings) {
        // Check if user is authenticated
        final isAuthenticated = FirebaseAuth.instance.currentUser != null;
        
        // Public routes accessible to everyone
        final publicRoutes = [
          '/landing',
          '/about',
          '/privacy',
          '/terms',
          '/contact',
          '/faq',
          '/pricing',
          '/payment',
          '/login',
        ];
        
        // If trying to access landing/login while authenticated, redirect to auth gate
        if (isAuthenticated && publicRoutes.contains(settings.name)) {
          return MaterialPageRoute(builder: (_) => const AuthGate());
        }
        
        // If trying to access protected routes while not authenticated, redirect to landing
        if (!isAuthenticated && !publicRoutes.contains(settings.name) && settings.name != '/') {
          return MaterialPageRoute(builder: (_) => const LandingPage());
        }
        
        // Default route handling
        return null; // Let the routes map handle it
      },
      routes: {
        '/landing': (_) => const LandingPage(),
        '/pricing': (_) => const PricingPage(),
  '/payment': (_) => const PaymentPage(),
        '/about': (_) => const AboutUsPage(),
        '/privacy': (_) => const PrivacyPolicyPage(),
        '/terms': (_) => const TermsOfServicePage(),
        '/contact': (_) => const ContactPage(),
        '/faq': (_) => const FAQPage(),
        '/login': (_) => const sign_in.SignInPage(),
        '/auth': (_) => const AuthGate(), // AuthGate for post-login routing
        '/home': (_) => const StudentHomePage(),
        '/dashboard': (_) => const StudentHomePage(),
        '/teacher': (_) => const TeacherHomePage(), // Route teachers to the new TeacherHomePage
        '/school-admin': (_) => const SchoolAdminHomePage(), // Route school admins to the school admin homepage
        '/parent': (_) => const ParentDashboardPage(), // Add parent dashboard route
        '/admin': (_) => const ComprehensiveAdminDashboard(), // Add comprehensive admin dashboard route
        '/admin-setup': (_) => const AdminSetupPage(), // Add admin setup route
        '/rme-debug': (_) => const RMEQuestionsDebugPage(), // Add RME debug route
  '/uri': (_) => const UriPage(),
        '/upload_note': (_) => const UploadNotePage(),
        '/note': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
          String? id = args?['noteId'] as String?;
          // If no explicit route arguments, try query params (for shared links)
          if (id == null) {
            final q = Uri.base.queryParameters;
            id = q['noteId'];
          }
          if (id == null) return const LandingPage();
          return NoteViewerPage(noteId: id);
        },
        '/comprehensive-admin': (_) => const ComprehensiveAdminDashboard(), // Add comprehensive admin dashboard route
      },
      ),
    );
  }
}

// Note: The flow is:
// 1. uriel.academy → LandingPage (marketing page with sign-up/sign-in buttons)
// 2. User clicks Sign In/Sign Up → respective pages
// 3. After successful auth → routes to /home (students) or /school (teachers/schools) based on user role

