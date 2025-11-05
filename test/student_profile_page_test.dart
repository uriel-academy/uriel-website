import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/screens/student_profile_page.dart';
import 'package:uriel_mainapp/services/user_service.dart';

class FakeUserService implements IUserService {
  bool called = false;
  late Map<String, dynamic> lastArgs;

  @override
  Future<void> storeStudentData({
    required String userId,
    String? firstName,
    String? lastName,
    String? name,
    required String email,
    required String phoneNumber,
    required String schoolName,
    required String grade,
    required int age,
    required String guardianName,
    required String guardianEmail,
    required String guardianPhone,
  }) async {
    called = true;
    lastArgs = {
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'schoolName': schoolName,
      'grade': grade,
      'age': age,
      'guardianName': guardianName,
      'guardianEmail': guardianEmail,
      'guardianPhone': guardianPhone,
    };
    return Future.value();
  }
}

void main() {
  testWidgets('Save profile happy path calls userService.storeStudentData', (WidgetTester tester) async {
    final fake = FakeUserService();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StudentProfilePage(
          userService: fake,
          testUserId: 'uid123',
          testUserEmail: 'test@example.com',
        ),
      ),
    ));

    // Wait for init
    await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const ValueKey('field_First_Name')), 'John');
  await tester.enterText(find.byKey(const ValueKey('field_Last_Name')), 'Doe');
  await tester.enterText(find.byKey(const ValueKey('field_School')), 'Test School');
    // Class dropdown defaults to a value; age and guardian fields
  await tester.enterText(find.byKey(const ValueKey('field_Age')), '12');
  await tester.enterText(find.byKey(const ValueKey('field_Guardian_Name')), 'Jane Doe');
  await tester.enterText(find.byKey(const ValueKey('field_Guardian_Email')), 'jane@example.com');
  await tester.enterText(find.byKey(const ValueKey('field_Guardian_Phone_(Optional)')), '+233501234567');

  // Tap save (ensure visible if inside a scroll view)
  await tester.ensureVisible(find.text('Save Profile'));
  await tester.tap(find.text('Save Profile'));
  await tester.pumpAndSettle();

    expect(fake.called, isTrue);
    expect(fake.lastArgs['userId'], 'uid123');
    expect(fake.lastArgs['firstName'], 'John');
    expect(fake.lastArgs['lastName'], 'Doe');
    expect(fake.lastArgs['email'], 'test@example.com');
    expect(fake.lastArgs['schoolName'], 'Test School');
    expect(fake.lastArgs['age'], 12);
    expect(fake.lastArgs['guardianEmail'], 'jane@example.com');
  });

  testWidgets('Missing required fields shows error and does not call service', (WidgetTester tester) async {
    final fake = FakeUserService();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StudentProfilePage(
          userService: fake,
          testUserId: 'uid123',
          testUserEmail: 'test@example.com',
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Leave school empty and age empty to trigger validation
  await tester.enterText(find.byKey(const ValueKey('field_First_Name')), 'John');
  await tester.enterText(find.byKey(const ValueKey('field_Last_Name')), 'Doe');

  await tester.ensureVisible(find.text('Save Profile'));
  await tester.tap(find.text('Save Profile'));
  await tester.pumpAndSettle();

  // Expect SnackBar error text
  expect(find.text('Please fill all required fields correctly'), findsOneWidget);
    expect(fake.called, isFalse);
  });
}
