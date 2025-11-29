import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/models/enums.dart';

void main() {
  group('Subject Enum Tests', () {
    test('should have correct display names', () {
      expect(Subject.mathematics.displayName, 'Mathematics');
      expect(Subject.english.displayName, 'English Language');
      expect(Subject.integratedScience.displayName, 'Integrated Science');
      expect(Subject.socialStudies.displayName, 'Social Studies');
      expect(Subject.ga.displayName, 'Ga');
      expect(Subject.asanteTwi.displayName, 'Asante Twi');
      expect(Subject.french.displayName, 'French');
      expect(Subject.ict.displayName, 'ICT');
      expect(Subject.religiousMoralEducation.displayName, 'Religious & Moral Education');
      expect(Subject.creativeArts.displayName, 'Creative Arts');
      expect(Subject.careerTechnology.displayName, 'Career Technology');
      expect(Subject.trivia.displayName, 'Trivia');
    });

    test('should have all 12 subjects defined', () {
      expect(Subject.values.length, 12);
    });

    test('should have unique display names', () {
      final displayNames = Subject.values.map((s) => s.displayName).toList();
      final uniqueNames = displayNames.toSet();
      expect(displayNames.length, uniqueNames.length);
    });
  });

  group('ExamType Enum Tests', () {
    test('should have all 5 exam types defined', () {
      expect(ExamType.values.length, 5);
      expect(ExamType.values, contains(ExamType.bece));
      expect(ExamType.values, contains(ExamType.wassce));
      expect(ExamType.values, contains(ExamType.mock));
      expect(ExamType.values, contains(ExamType.practice));
      expect(ExamType.values, contains(ExamType.trivia));
    });

    test('should have correct enum values', () {
      expect(ExamType.bece.name, 'bece');
      expect(ExamType.wassce.name, 'wassce');
      expect(ExamType.mock.name, 'mock');
      expect(ExamType.practice.name, 'practice');
      expect(ExamType.trivia.name, 'trivia');
    });
  });
}
