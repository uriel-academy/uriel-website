import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/landing_page.dart'; // Import LandingPage for first load
import 'screens/sign_in.dart' as sign_in; // Import your sign-in page with alias
import 'screens/auth_gate.dart'; // Import AuthGate from dedicated file
import 'screens/home_page.dart'; // Import StudentHomePage

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
        '/login': (_) => const sign_in.SignInPage(),
        '/auth': (_) => const AuthGate(), // AuthGate for post-login routing
        '/home': (_) => const StudentHomePage(),
        '/dashboard': (_) => const StudentHomePage(),
      },
    );
  }
}

// Note: The flow is:
// 1. uriel.academy → LandingPage (marketing page with sign-up/sign-in buttons)
// 2. User clicks Sign In/Sign Up → respective pages
// 3. After successful auth → routes to /home → StudentHomePage

