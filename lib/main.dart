import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'services/connection_service.dart'; // Import connection monitoring service
// import 'services/push_notification_service.dart'; // Import push notification service - commented out as file doesn't exist
// Core pages - loaded immediately
import 'screens/landing_page.dart';
import 'screens/sign_in.dart' as sign_in;
import 'screens/auth_gate.dart';
import 'screens/home_page.dart';

// Admin pages - deferred (loaded on demand)
import 'screens/comprehensive_admin_dashboard.dart' deferred as admin_dashboard;
import 'screens/redesigned_admin_home_page.dart' deferred as admin_home;
import 'screens/admin_setup_page.dart' deferred as admin_setup;
import 'screens/rme_debug_page.dart' deferred as rme_debug;

// Teacher/School pages - deferred
import 'screens/teacher_home_page.dart' deferred as teacher_home;
import 'screens/school_admin_home_page.dart' deferred as school_admin;
import 'screens/parent_dashboard.dart' deferred as parent_dashboard;

// Secondary features - deferred
import 'screens/study_planner_page.dart' deferred as study_planner;
import 'screens/upload_note_page.dart' deferred as upload_note;
import 'screens/uri_page.dart' deferred as uri_page;

// Static pages - deferred (rarely accessed)
import 'screens/about_us.dart' deferred as about_us;
import 'screens/privacy_policy.dart' deferred as privacy_policy;
import 'screens/terms_of_service.dart' deferred as terms_of_service;
import 'screens/contact.dart' deferred as contact;
import 'screens/faq.dart' deferred as faq;
import 'screens/pricing_page.dart' deferred as pricing;
import 'screens/payment_page.dart' deferred as payment;

// Note viewer - keep eager (used frequently)
import 'screens/note_viewer_page.dart';
// import 'widgets/error_boundary.dart'; // Import error boundary - COMMENTED OUT: Causing app initialization issues

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use path-based URLs instead of hash-based (#) URLs for better SEO
  usePathUrlStrategy();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Analytics
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  // SCALABILITY: Disable persistence on web to prevent snapshot listener conflicts
  // With polling strategy (30s intervals), persistence causes INTERNAL ASSERTION errors
  // Mobile keeps persistence for offline support
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false, // Disabled for web to avoid listener conflicts
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } else {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB on mobile
    );
  }

  // Keep auth state persistent across page refreshes
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Start connection monitoring to detect and recover from disconnections
  ConnectionService().startMonitoring();

  // Initialize push notifications - commented out as service doesn't exist
  // await PushNotificationService().initialize();

  runApp(
    ProviderScope(
      child: MyApp(analytics: analytics, observer: observer),
    ),
  );
}

// Wrapper widget to show loading while deferred library loads
class DeferredWidget extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;

  const DeferredWidget({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  Widget? _loadedWidget;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.loadLibrary();
    if (mounted) {
      setState(() {
        _loadedWidget = widget.builder();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _loadedWidget!;
  }
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  const MyApp({super.key, required this.analytics, required this.observer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uriel Academy',
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // Start with AuthGate (checks auth state automatically)
      navigatorObservers: [observer], // Add analytics observer
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
        
        // Routes that should redirect to dashboard if authenticated (login/landing only)
        final authRedirectRoutes = ['/landing', '/login'];
        
        // If trying to access landing/login while authenticated, redirect to auth gate
        if (isAuthenticated && authRedirectRoutes.contains(settings.name)) {
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
        '/pricing': (_) => DeferredWidget(
          loadLibrary: pricing.loadLibrary,
          builder: () => pricing.PricingPage(),
        ),
        '/payment': (_) => DeferredWidget(
          loadLibrary: payment.loadLibrary,
          builder: () => payment.PaymentPage(),
        ),
        '/about': (_) => DeferredWidget(
          loadLibrary: about_us.loadLibrary,
          builder: () => about_us.AboutUsPage(),
        ),
        '/privacy': (_) => DeferredWidget(
          loadLibrary: privacy_policy.loadLibrary,
          builder: () => privacy_policy.PrivacyPolicyPage(),
        ),
        '/terms': (_) => DeferredWidget(
          loadLibrary: terms_of_service.loadLibrary,
          builder: () => terms_of_service.TermsOfServicePage(),
        ),
        '/contact': (_) => DeferredWidget(
          loadLibrary: contact.loadLibrary,
          builder: () => contact.ContactPage(),
        ),
        '/faq': (_) => DeferredWidget(
          loadLibrary: faq.loadLibrary,
          builder: () => faq.FAQPage(),
        ),
        '/login': (_) => const sign_in.SignInPage(),
        '/auth': (_) => const AuthGate(),
        '/home': (_) => const StudentHomePage(),
        '/dashboard': (_) => const StudentHomePage(),
        '/teacher': (_) => DeferredWidget(
          loadLibrary: teacher_home.loadLibrary,
          builder: () => teacher_home.TeacherHomePage(),
        ),
        '/school-admin': (_) => DeferredWidget(
          loadLibrary: school_admin.loadLibrary,
          builder: () => school_admin.SchoolAdminHomePage(),
        ),
        '/parent': (_) => DeferredWidget(
          loadLibrary: parent_dashboard.loadLibrary,
          builder: () => parent_dashboard.ParentDashboardPage(),
        ),
        '/admin': (_) => DeferredWidget(
          loadLibrary: admin_home.loadLibrary,
          builder: () => admin_home.RedesignedAdminHomePage(),
        ),
        '/admin-old': (_) => DeferredWidget(
          loadLibrary: admin_dashboard.loadLibrary,
          builder: () => admin_dashboard.ComprehensiveAdminDashboard(),
        ),
        '/admin-setup': (_) => DeferredWidget(
          loadLibrary: admin_setup.loadLibrary,
          builder: () => admin_setup.AdminSetupPage(),
        ),
        '/rme-debug': (_) => DeferredWidget(
          loadLibrary: rme_debug.loadLibrary,
          builder: () => rme_debug.RMEQuestionsDebugPage(),
        ),
        '/uri': (_) => DeferredWidget(
          loadLibrary: uri_page.loadLibrary,
          builder: () => uri_page.UriPage(),
        ),
        '/upload_note': (_) => DeferredWidget(
          loadLibrary: upload_note.loadLibrary,
          builder: () => upload_note.UploadNotePage(),
        ),
        '/study-planner': (_) => DeferredWidget(
          loadLibrary: study_planner.loadLibrary,
          builder: () => study_planner.StudyPlannerPage(),
        ),
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
        '/comprehensive-admin': (_) => DeferredWidget(
          loadLibrary: admin_dashboard.loadLibrary,
          builder: () => admin_dashboard.ComprehensiveAdminDashboard(),
        ),
      },
    );
  }
}

// Note: The flow is:
// 1. uriel.academy → LandingPage (marketing page with sign-up/sign-in buttons)
// 2. User clicks Sign In/Sign Up → respective pages
// 3. After successful auth → routes to /home (students) or /school (teachers/schools) based on user role

