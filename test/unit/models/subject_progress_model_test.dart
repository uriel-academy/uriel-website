import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/models/subject_progress_model.dart';

void main() {
  group('SubjectProgress', () {
    test('should create instance with all properties', () {
      final progress = SubjectProgress('Mathematics', 0.75, Colors.blue);

      expect(progress.name, 'Mathematics');
      expect(progress.progress, 0.75);
      expect(progress.color, Colors.blue);
    });

    test('should create from JSON correctly', () {
      final json = {
        'name': 'Science',
        'progress': 0.6,
        'color': const Color(0xFFFF5733).value,
      };

      final progress = SubjectProgress.fromJson(json);

      expect(progress.name, 'Science');
      expect(progress.progress, 0.6);
      expect(progress.color, const Color(0xFFFF5733));
    });

    test('should convert to JSON correctly', () {
      final progress = SubjectProgress('English', 0.85, Colors.green);

      final json = progress.toJson();

      expect(json['name'], 'English');
      expect(json['progress'], 0.85);
      expect(json['color'], Colors.green.value);
    });

    test('should handle integer progress value in JSON', () {
      final json = {
        'name': 'History',
        'progress': 1,  // Integer instead of double
        'color': Colors.purple.value,
      };

      final progress = SubjectProgress.fromJson(json);

      expect(progress.progress, 1.0);  // Should convert to double
    });

    test('should support equality comparison', () {
      final progress1 = SubjectProgress('Math', 0.5, Colors.blue);
      final progress2 = SubjectProgress('Math', 0.5, Colors.blue);
      final progress3 = SubjectProgress('Math', 0.6, Colors.blue);

      expect(progress1, equals(progress2));
      expect(progress1, isNot(equals(progress3)));
    });

    test('should support identical check', () {
      final progress = SubjectProgress('Math', 0.5, Colors.blue);

      expect(progress, equals(progress));
    });

    test('should have consistent hashCode', () {
      final progress1 = SubjectProgress('Math', 0.5, Colors.blue);
      final progress2 = SubjectProgress('Math', 0.5, Colors.blue);

      expect(progress1.hashCode, equals(progress2.hashCode));
    });

    test('should have different hashCode for different objects', () {
      final progress1 = SubjectProgress('Math', 0.5, Colors.blue);
      final progress2 = SubjectProgress('Science', 0.5, Colors.blue);

      expect(progress1.hashCode, isNot(equals(progress2.hashCode)));
    });

    test('should have descriptive toString', () {
      final progress = SubjectProgress('Math', 0.75, Colors.blue);

      final str = progress.toString();

      expect(str, contains('SubjectProgress'));
      expect(str, contains('Math'));
      expect(str, contains('0.75'));
    });

    test('should handle 0% progress', () {
      final progress = SubjectProgress('New Subject', 0.0, Colors.grey);

      expect(progress.progress, 0.0);
    });

    test('should handle 100% progress', () {
      final progress = SubjectProgress('Completed Subject', 1.0, Colors.green);

      expect(progress.progress, 1.0);
    });

    test('should roundtrip through JSON', () {
      final original = SubjectProgress('RME', 0.42, const Color(0xFF6A5ACD));

      final json = original.toJson();
      final reconstructed = SubjectProgress.fromJson(json);

      expect(reconstructed, equals(original));
      expect(reconstructed.name, original.name);
      expect(reconstructed.progress, original.progress);
      expect(reconstructed.color, original.color);
    });
  });
}
