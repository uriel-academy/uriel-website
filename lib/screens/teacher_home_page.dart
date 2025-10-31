import 'package:flutter/material.dart';
import 'home_page.dart';

/// Teacher page - reuse StudentHomePage but enable teacher mode so it mirrors
/// the student UI exactly while excluding Questions, Revision and Leaderboard.
class TeacherHomePage extends StatelessWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentHomePage(isTeacher: true);
  }
}
