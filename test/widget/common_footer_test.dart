import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/widgets/common_footer.dart';

void main() {
  group('CommonFooter Widget Tests', () {
    testWidgets('should render with all links on large screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommonFooter(
              isSmallScreen: false,
              showLinks: true,
              showPricing: true,
            ),
          ),
        ),
      );

      expect(find.text('Uriel Academy'), findsOneWidget);
      expect(find.text('Empowering Ghanaian students to excel in BECE & WASSCE'), findsOneWidget);
    });

    testWidgets('should render with small screen layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommonFooter(
              isSmallScreen: true,
              showLinks: true,
              showPricing: false,
            ),
          ),
        ),
      );

      expect(find.text('Uriel Academy'), findsOneWidget);
    });

    testWidgets('should hide links when showLinks is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommonFooter(
              isSmallScreen: false,
              showLinks: false,
            ),
          ),
        ),
      );

      // Brand name should still show but tagline should not
      expect(find.text('Uriel Academy'), findsOneWidget);
      expect(find.text('Empowering Ghanaian students to excel in BECE & WASSCE'), findsNothing);
      // Footer links should not be present
      expect(find.text('Pricing'), findsNothing);
      expect(find.text('About Us'), findsNothing);
    });

    testWidgets('should have correct container properties', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommonFooter(
              isSmallScreen: false,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, const Color(0xFF1A1E3F));
      expect(container.constraints?.maxWidth, double.infinity);
    });
  });
}
