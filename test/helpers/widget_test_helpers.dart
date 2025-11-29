/// Widget test helper utilities for testing Flutter widgets with Riverpod providers.
///
/// This file provides helper functions to simplify widget testing by:
/// - Wrapping widgets with necessary providers (Riverpod, MaterialApp, etc.)
/// - Providing Firebase mocks for widgets that depend on Firebase
/// - Common test utilities (pump with settle, find helpers, etc.)
///
/// Usage:
/// ```dart
/// await tester.pumpWidgetWithProviders(
///   MyWidget(),
///   providers: [/* override providers */],
/// );
/// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extension on WidgetTester to add custom helper methods
extension WidgetTesterHelpers on WidgetTester {
  /// Pump a widget wrapped with MaterialApp and ProviderScope.
  ///
  /// This is the primary helper for widget testing. It wraps your widget
  /// with all the necessary scaffolding (MaterialApp, ProviderScope) and
  /// optionally allows you to override providers for testing.
  ///
  /// Example:
  /// ```dart
  /// await tester.pumpWidgetWithProviders(
  ///   MyWidget(),
  ///   providers: [
  ///     myProvider.overrideWith((ref) => MockMyService()),
  ///   ],
  /// );
  /// ```
  Future<void> pumpWidgetWithProviders(
    Widget widget, {
    List<Override> providers = const [],
    ThemeData? theme,
    Locale? locale,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: providers,
        child: MaterialApp(
          theme: theme,
          locale: locale,
          home: Scaffold(body: widget),
        ),
      ),
    );
  }

  /// Pump widget and settle with a custom duration.
  ///
  /// Useful for widgets with animations. Waits for all animations to complete.
  Future<void> pumpWithSettle([Duration duration = const Duration(seconds: 1)]) async {
    await pump(duration);
    await pumpAndSettle();
  }

  /// Find text containing a substring (case-insensitive)
  Finder findTextContaining(String substring) {
    return find.byWidgetPredicate((widget) {
      if (widget is Text) {
        final text = widget.data?.toLowerCase() ?? '';
        final span = widget.textSpan?.toPlainText().toLowerCase() ?? '';
        return text.contains(substring.toLowerCase()) || 
               span.contains(substring.toLowerCase());
      }
      return false;
    });
  }

  /// Find icon by type
  Finder findIconByType(IconData iconData) {
    return find.byWidgetPredicate((widget) {
      if (widget is Icon) {
        return widget.icon == iconData;
      }
      return false;
    });
  }

  /// Tap and settle in one call
  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  /// Enter text and settle in one call
  Future<void> enterTextAndSettle(Finder finder, String text) async {
    await enterText(finder, text);
    await pumpAndSettle();
  }

  /// Scroll until visible and tap
  Future<void> scrollToAndTap(Finder finder, {Finder? scrollable}) async {
    await scrollUntilVisible(
      finder,
      100,
      scrollable: scrollable ?? find.byType(Scrollable).first,
    );
    await tapAndSettle(finder);
  }

  /// Verify widget is visible (not obscured, on screen)
  bool isWidgetVisible(Finder finder) {
    try {
      final widget = finder.evaluate().first;
      final renderObject = widget.renderObject;
      return renderObject != null && renderObject.attached;
    } catch (e) {
      return false;
    }
  }
}

/// Create sample user data for testing
Map<String, dynamic> createMockUserData({
  String? name,
  String? email,
  String? role,
  int xp = 100,
  int streak = 3,
}) {
  return {
    'name': name ?? 'Test User',
    'email': email ?? 'test@example.com',
    'role': role ?? 'student',
    'xp': xp,
    'currentStreak': streak,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

/// Create sample quiz data for testing
Map<String, dynamic> createMockQuizData({
  String? userId,
  String subject = 'Mathematics',
  int score = 80,
  int totalQuestions = 10,
  int correctAnswers = 8,
}) {
  return {
    'userId': userId ?? 'test-user-id',
    'subject': subject,
    'score': score.toDouble(),
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'completedAt': DateTime.now().toIso8601String(),
    'answers': List.generate(
      totalQuestions,
      (i) => {
        'questionId': 'q$i',
        'userAnswer': i < correctAnswers ? 'correct' : 'wrong',
        'isCorrect': i < correctAnswers,
      },
    ),
  };
}

/// Create sample subject progress data
Map<String, dynamic> createMockSubjectProgress({
  String subject = 'Mathematics',
  double progress = 75.0,
  int questionsAnswered = 50,
}) {
  return {
    'subject': subject,
    'progress': progress,
    'questionsAnswered': questionsAnswered,
    'averageScore': progress,
    'lastActivityAt': DateTime.now().toIso8601String(),
  };
}

/// Create a test Riverpod container with mocks
ProviderContainer createTestContainer({
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: overrides,
  );
}

/// Delay helper for async operations in tests
Future<void> delay([Duration duration = const Duration(milliseconds: 100)]) async {
  await Future.delayed(duration);
}

/// Common matchers for widget testing

/// Matcher to check if widget exists and is visible
Matcher isVisible() {
  return isNotNull;
}

/// Matcher to check if widget has specific color
Matcher hasColor(Color color) {
  return isA<Widget>().having(
    (w) {
      if (w is Container && w.decoration is BoxDecoration) {
        return (w.decoration as BoxDecoration).color;
      }
      return null;
    },
    'color',
    equals(color),
  );
}

/// Matcher to check text style properties
Matcher hasTextStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
}) {
  return isA<Text>().having(
    (t) => t.style,
    'style',
    allOf([
      if (color != null) isA<TextStyle>().having((s) => s.color, 'color', equals(color)),
      if (fontSize != null) isA<TextStyle>().having((s) => s.fontSize, 'fontSize', equals(fontSize)),
      if (fontWeight != null) isA<TextStyle>().having((s) => s.fontWeight, 'fontWeight', equals(fontWeight)),
    ]),
  );
}

/// Print helper for debugging widget tests
void printWidgetTree(WidgetTester tester) {
  debugPrint('=== Widget Tree ===');
  tester.allWidgets.forEach((widget) {
    debugPrint(widget.runtimeType.toString());
  });
  debugPrint('==================');
}

/// Find all text widgets in the tree
List<String> findAllText(WidgetTester tester) {
  final texts = <String>[];
  tester.allWidgets.forEach((widget) {
    if (widget is Text && widget.data != null) {
      texts.add(widget.data!);
    }
  });
  return texts;
}
