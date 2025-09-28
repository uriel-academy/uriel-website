import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('No notifications yet.')),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UrielApp());
}

class UrielApp extends StatelessWidget {
  const UrielApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uriel Academy',
      theme: ThemeData(
        primaryColor: const Color(0xFF1A1E3F), // Deep Navy
        scaffoldBackgroundColor: const Color(0xFFFFF8F0), // Warm White
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/about': (_) => const AboutPage(),
        '/pricing': (_) => const PricingPage(),
        '/signin': (_) => const SignInPage(),
        '/signup': (_) => const SignUpPage(),
      },
    );
  }
}

/// Simple auth guard
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const SignInPage();
        }
        return const StudentHomePage(); // Main student homepage after login
      },
    );
  }
}

// Note: The old multi-role HomePage has been replaced with StudentHomePage
// School and Teacher dashboards will be separate pages with role-based routing

/// Placeholder pages for About, Pricing, SignIn
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext c) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final prefix = email.contains('@') ? email.split('@')[0] : email;
    return Center(
      child: Text(
        'WELCOME $prefix',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class PastQuestionsPage extends StatelessWidget {
  const PastQuestionsPage({super.key});

  @override
  Widget build(BuildContext c) {
    return const _GenericListPage(collection: 'past_questions', title: 'Past Questions');
  }
}

class TextBooksPage extends StatelessWidget {
  const TextBooksPage({super.key});

  @override
  Widget build(BuildContext c) {
    return const _GenericListPage(collection: 'textbooks', title: 'Text Books');
  }
}

class MockQuestionsPage extends StatelessWidget {
  const MockQuestionsPage({super.key});

  @override
  Widget build(BuildContext c) {
    return const _GenericListPage(collection: 'mock_questions', title: 'Mock Questions');
  }
}

class StudyPlansPage extends StatelessWidget {
  const StudyPlansPage({super.key});

  @override
  Widget build(BuildContext c) {
    return const _GenericListPage(collection: 'study_plans', title: 'Study Plans');
  }
}

class LearningGamesPage extends StatelessWidget {
  const LearningGamesPage({super.key});

  @override
  Widget build(BuildContext c) {
    return const _GenericListPage(collection: 'learning_games', title: 'Learning Games');
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext c) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _GenericListPage(
      collection: 'messages',
      title: 'Messages',
      queryBuilder: (qb) => qb.where('to', isEqualTo: uid),
    );
  }
}

/// Reusable Firestore list page
class _GenericListPage extends StatelessWidget {
  final String collection;
  final String title;
  final Query Function(Query)? queryBuilder;
  const _GenericListPage({
    required this.collection,
    required this.title,
    this.queryBuilder,
  });

  @override
  Widget build(BuildContext c) {
    Query col = FirebaseFirestore.instance.collection(collection);
    if (queryBuilder != null) col = queryBuilder!(col);
    return StreamBuilder<QuerySnapshot>(
      stream: col.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(data['title'] ?? '$title item'),
                subtitle: Text(data['subtitle'] ?? ''),
                onTap: () {
                  // TODO: navigate into detail page
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Placeholder pages for About, Pricing, SignIn
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('About')), body: const Center(child: Text('About Uriel Academy')));
}
class PricingPage extends StatelessWidget {
  const PricingPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Pricing')), body: const Center(child: Text('Pricing Plans')));
}
class SignInPage  extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext c) {
    // TODO: your sign-in UI (Google / Email / etc)
    return const Scaffold(
      body: Center(child: Text('Sign In')),
    );
  }
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext c) {
    // TODO: your sign-up UI
    return const Scaffold(
      body: Center(child: Text('Sign Up')),
    );
  }
}
