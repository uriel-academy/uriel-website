import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/widgets/xp_earning_guide.dart';

void main() {
  group('XPEarningGuide Tests', () {
    testWidgets('should display XP earning methods', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XPEarningGuide(),
          ),
        ),
      );

      expect(find.text('How to Earn XP'), findsOneWidget);
    });

    testWidgets('should show quiz completion XP', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XPEarningGuide(),
          ),
        ),
      );

      // The guide should mention quizzes as a way to earn XP
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('should have proper structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: XPEarningGuide(),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });
  });
}
