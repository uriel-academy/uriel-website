import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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
      home: const AuthGate(), // Use AuthGate as main entry point
      routes: {
        '/login': (_) => const sign_in.SignInPage(),
        '/home': (_) => const StudentHomePage(),
        '/dashboard': (_) => const StudentHomePage(),
      },
    );
  }
}

