# Test Infrastructure Guide

## Overview
This directory contains the testing infrastructure for Uriel Main App, including unit tests, widget tests, integration tests, and test helpers.

## Directory Structure

```
test/
├── unit/                       # Unit tests (business logic)
│   ├── models/                # Model tests (Question, Quiz, SubjectProgress)
│   ├── services/              # Service tests (Stats, Cache, Error handling)
│   └── providers/             # Provider tests (Riverpod state management)
├── widget/                    # Widget tests (UI components)
├── integration/               # Integration tests (end-to-end flows)
├── helpers/                   # Test utilities and mocks
│   ├── firebase_mocks.dart    # Firebase mock implementations
│   └── widget_test_helpers.dart  # Widget testing utilities
└── README.md                  # This file
```

## Test Categories

### Unit Tests (179 passing)
Pure business logic tests with no UI dependencies.

**Coverage:**
- ✅ Models: Question, Quiz, SubjectProgress, Enums (30 tests)
- ✅ Services: ErrorHandler, CacheService, PerformanceMonitor, StreamManager, StatsCalculator (77 tests)
- ✅ Providers: Collections state management (9 tests)
- ✅ Utilities: Web compatibility, URI normalization (63 tests)

**Example:**
```dart
test('calculateStreak should count consecutive days', () {
  final service = StatsCalculatorService();
  final today = DateTime.now();
  final dates = [
    today,
    today.subtract(Duration(days: 1)),
    today.subtract(Duration(days: 2)),
  ];
  
  expect(service.calculateStreak(dates), 3);
});
```

### Widget Tests (Planned)
UI component tests using `flutter_test` with mocked dependencies.

**Test Strategy:**
1. Use `testWidgets()` for widget testing
2. Mock Firebase services (see helpers/firebase_mocks.dart)
3. Use `ProviderScope` for Riverpod widgets
4. Test user interactions with `tester.tap()`, `tester.enterText()`
5. Verify UI state with `expect(find.text(...), findsOneWidget)`

**Example:**
```dart
testWidgets('UriChatInterface displays welcome message', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: UriChatInterface(userName: 'Test User'),
    ),
  );
  
  expect(find.text('Hi Test User! 👋'), findsOneWidget);
});
```

### Integration Tests (Planned)
End-to-end tests simulating real user workflows.

**Test Flows:**
1. **Authentication Flow**: Sign up → Login → Logout
2. **Quiz Flow**: Browse collections → Start quiz → Answer questions → View results
3. **Textbook Flow**: Navigate subjects → Read content → Bookmark pages
4. **Leaderboard Flow**: View ranks → Check standings → Progress tracking

**Example:**
```dart
testWidgets('Complete quiz flow', (tester) async {
  // 1. Login
  await tester.pumpWidget(MyApp());
  await tester.enterText(find.byKey(Key('email')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password')), 'password123');
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
  
  // 2. Navigate to Questions
  await tester.tap(find.text('Questions'));
  await tester.pumpAndSettle();
  
  // 3. Select a quiz
  await tester.tap(find.text('Mathematics - 2024'));
  await tester.pumpAndSettle();
  
  // 4. Answer questions
  await tester.tap(find.byKey(Key('answer_A')));
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  
  // 5. Verify results
  expect(find.text('Quiz Complete'), findsOneWidget);
});
```

## Test Helpers

### Firebase Mocks (`test/helpers/firebase_mocks.dart`)

✅ **IMPLEMENTED** - Complete mock implementations for Firebase testing.

**Available Mocks:**
- `MockFirebaseAuth`: Full auth implementation (signIn, createUser, signOut, authStateChanges)
- `MockFirestore`: In-memory database with collection/document operations
- `MockUser`: Complete User implementation with uid, email, displayName, photoURL
- `MockDocumentReference`, `MockCollectionReference`: Document/collection operations
- `MockDocumentSnapshot`: Snapshot data access

**Usage:**
```dart
import '../helpers/firebase_mocks.dart';

// Create mock auth with user
final mockAuth = MockFirebaseAuth(
  currentUser: MockUser(uid: 'test-123', email: 'test@example.com'),
);

// Create mock Firestore with data
final mockFirestore = MockFirestore();
mockFirestore.addMockData('users', 'test-123', {'name': 'Test User', 'xp': 500});

// Use in tests
expect(mockAuth.currentUser?.uid, 'test-123');
final doc = await mockFirestore.collection('users').doc('test-123').get();
expect(doc.data()?['xp'], 500);
```

### Widget Test Helpers (`test/helpers/widget_test_helpers.dart`)

✅ **IMPLEMENTED** - Comprehensive widget testing utilities with Riverpod support.

**Extension Methods on WidgetTester:**
- `pumpWidgetWithProviders()`: Wrap widget with MaterialApp + ProviderScope + overrides
- `pumpWithSettle()`: Pump and wait for animations
- `tapAndSettle()`: Tap widget and settle in one call
- `enterTextAndSettle()`: Enter text and settle in one call
- `scrollToAndTap()`: Scroll until visible, then tap
- `findTextContaining()`: Find text with substring match (case-insensitive)
- `findIconByType()`: Find icon by IconData
- `isWidgetVisible()`: Check if widget is visible on screen

**Helper Functions:**
- `createMockAuth()`: Create MockFirebaseAuth with custom user
- `createMockFirestore()`: Create MockFirestore with initial data
- `createMockUserData()`: Generate sample user document data
- `createMockQuizData()`: Generate sample quiz result data
- `createMockSubjectProgress()`: Generate subject progress data
- `createTestContainer()`: Create ProviderContainer with overrides
- `delay()`: Helper for async operation delays

**Debug Utilities:**
- `printWidgetTree()`: Print all widgets in tree
- `findAllText()`: Extract all text from widget tree

**Usage:**
```dart
import '../helpers/widget_test_helpers.dart';

testWidgets('displays user stats', (tester) async {
  // Pump widget with providers
  await tester.pumpWidgetWithProviders(
    StatsCard(xp: 500, streak: 7),
    providers: [
      // Override providers for testing
      userProvider.overrideWith((ref) => createMockUserData(xp: 500)),
    ],
  );
  
  // Use extension methods
  expect(tester.findTextContaining('500'), findsOneWidget);
  await tester.tapAndSettle(find.byIcon(Icons.info));
  expect(find.text('XP Info'), findsOneWidget);
});
```
final mockAuth = MockFirebaseAuth();
final mockFirestore = MockFirestore();

// Setup mock data
mockFirestore.collection('quizzes').add({
  'userId': 'test123',
  'score': 85.0,
  'totalQuestions': 20,
});

// Use in tests
final service = StatsCalculatorService(firestore: mockFirestore);
final hours = await service.computeLifetimeStudyHours('test123');
expect(hours, greaterThan(0));
```

### Widget Test Helpers (helpers/widget_test_helpers.dart)

Utilities for testing widgets with Riverpod providers.

**Functions:**
- `testWidgetWithProviders()`: Wraps widget with ProviderScope
- `createMockProviders()`: Creates test provider overrides
- `pumpWithSettle()`: Pump widget until animations settle

**Usage:**
```dart
await testWidgetWithProviders(
  tester,
  widget: MyWidget(),
  overrides: [
    collectionsProvider.overrideWith((ref) => mockCollections),
  ],
);
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run with Coverage
```bash
flutter test --coverage
```

### Run Specific Test File
```bash
flutter test test/unit/services/stats_calculator_service_test.dart
```

### Run Tests by Name Pattern
```bash
flutter test --name="calculateStreak"
```

### Run Integration Tests
```bash
flutter test integration_test/
```

## Writing New Tests

### 1. Unit Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/services/my_service.dart';

void main() {
  group('MyService', () {
    late MyService service;

    setUp(() {
      service = MyService();
    });

    test('should do something', () {
      final result = service.doSomething();
      expect(result, expectedValue);
    });
  });
}
```

### 2. Widget Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:uriel_mainapp/widgets/my_widget.dart';

void main() {
  testWidgets('MyWidget should display text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MyWidget(text: 'Hello')),
    );

    expect(find.text('Hello'), findsOneWidget);
  });
}
```

### 3. Integration Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uriel_mainapp/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-end test', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Test flow...
  });
}
```

## Best Practices

### 1. Test Organization
- ✅ One test file per source file
- ✅ Group related tests with `group()`
- ✅ Use descriptive test names
- ✅ Keep tests focused and atomic

### 2. Mock Usage
- ✅ Mock external dependencies (Firebase, HTTP)
- ✅ Use real implementations for pure functions
- ✅ Avoid over-mocking (test real behavior when possible)

### 3. Assertions
- ✅ Use specific matchers (`equals`, `greaterThan`, `closeTo`)
- ✅ Test edge cases (null, empty, boundary values)
- ✅ Verify both success and failure paths

### 4. Test Coverage Goals
- 🎯 Unit Tests: 80%+ coverage
- 🎯 Widget Tests: Critical UI paths
- 🎯 Integration Tests: Major user flows

## Current Status

**Test Count**: 179 passing, 4 skipped
**Coverage**: 33.2% (expanding)
**Pass Rate**: 100%

**Recent Additions:**
- ✅ StatsCalculatorService: 42 tests (streak, progress, performance)
- ✅ SubjectProgress Model: 12 tests (JSON, equality)
- ✅ Collections Provider: 9 tests (filtering, pagination)

**Next Steps:**
1. Build widget test infrastructure (Firebase mocks)
2. Add widget tests for extracted components (UriChat, SubjectProgress)
3. Create integration test suite (auth, quiz, textbook flows)
4. Expand coverage to 50%+

## Troubleshooting

### Firebase Initialization Errors
```dart
// Problem: [core/no-app] No Firebase App created
// Solution: Pass mock Firestore to service
final service = StatsCalculatorService(firestore: mockFirestore);
```

### Widget Test Timeouts
```dart
// Problem: Test doesn't complete
// Solution: Use pumpAndSettle() for animations
await tester.pumpAndSettle();
```

### Provider Not Found
```dart
// Problem: Could not find provider
// Solution: Wrap with ProviderScope
await tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(home: MyWidget()),
  ),
);
```

## Resources

- [Flutter Testing Docs](https://docs.flutter.dev/testing)
- [Riverpod Testing](https://riverpod.dev/docs/cookbooks/testing)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Test Coverage Guide](https://flutter.dev/docs/testing/test-coverage)

---

**Last Updated**: November 2024  
**Maintainer**: Development Team  
**Questions**: See project documentation
