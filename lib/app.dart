import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/sign_in.dart' as sign_in;
import 'screens/home.dart';
import 'screens/admin_dashboard.dart';

void main() {
  runApp(const UrielApp());
}

class UrielApp extends StatelessWidget {
  const UrielApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uriel Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LandingPage(),
      routes: {
        '/login': (context) => const sign_in.SignInPage(),
        '/home': (context) => const HomePage(),
        '/admin': (context) => const AdminDashboardPage(),
        // Add other routes as needed
      },
    );
  }
}
