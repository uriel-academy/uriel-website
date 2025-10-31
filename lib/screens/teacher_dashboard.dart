import 'package:flutter/material.dart';
import 'teacher_home_page.dart';

/// Deprecated: teacher dashboard removed. Use `TeacherHomePage` (which reuses
/// `StudentHomePage(isTeacher: true)`) instead. This file remains for
/// compatibility but forwards to the new page.
@deprecated
class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherHomePage();
  }
}
// Remaining dashboard helper widgets were intentionally removed. This file is
// deprecated and now forwards to `TeacherHomePage`. Complex dashboard UI was
// moved into `teacher_home_page.dart` to avoid duplication.
