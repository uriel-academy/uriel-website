import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/services/stats_calculator_service.dart';
import 'package:uriel_mainapp/models/subject_progress_model.dart';

void main() {
  group('StatsCalculatorService', () {
    late StatsCalculatorService service;

    setUp(() {
      service = StatsCalculatorService();
    });

    group('calculateStreak', () {
      test('should return 0 for empty activity list', () {
        expect(service.calculateStreak([]), 0);
      });

      test('should return 0 if last activity was 2+ days ago', () {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        expect(service.calculateStreak([threeDaysAgo]), 0);
      });

      test('should return 1 for activity today only', () {
        final today = DateTime.now();
        expect(service.calculateStreak([today]), 1);
      });

      test('should return 1 for activity yesterday only', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(service.calculateStreak([yesterday]), 1);
      });

      test('should calculate streak for consecutive days', () {
        final today = DateTime.now();
        final dates = [
          today,
          today.subtract(const Duration(days: 1)),
          today.subtract(const Duration(days: 2)),
          today.subtract(const Duration(days: 3)),
        ];
        expect(service.calculateStreak(dates), 4);
      });

      test('should stop counting at first gap', () {
        final today = DateTime.now();
        final dates = [
          today,
          today.subtract(const Duration(days: 1)),
          // Gap here - day 2 missing
          today.subtract(const Duration(days: 3)),
          today.subtract(const Duration(days: 4)),
        ];
        expect(service.calculateStreak(dates), 2);
      });

      test('should handle unsorted activity dates', () {
        final today = DateTime.now();
        final dates = [
          today.subtract(const Duration(days: 2)),
          today,
          today.subtract(const Duration(days: 1)),
        ];
        expect(service.calculateStreak(dates), 3);
      });

      test('should handle dates with different times', () {
        final today = DateTime.now();
        final dates = [
          DateTime(today.year, today.month, today.day, 8, 30),
          DateTime(today.year, today.month, today.day, 14, 45),
          DateTime(today.year, today.month, today.day - 1, 20, 15),
        ];
        expect(service.calculateStreak(dates), 2);
      });

      test('should handle long streak', () {
        final today = DateTime.now();
        final dates = List.generate(
          30,
          (i) => today.subtract(Duration(days: i)),
        );
        expect(service.calculateStreak(dates), 30);
      });
    });

    group('computeLifetimeStudyHours', () {
      test('computeLifetimeStudyHours requires Firebase mock - skipping for now', () {
        // TODO: Add fake_cloud_firestore package for Firestore mocking
        // See: https://pub.dev/packages/fake_cloud_firestore
        expect(true, true);
      }, skip: 'Requires fake_cloud_firestore package');
    });

    group('calculateOverallProgress', () {
      test('should return 0 for empty subject list', () {
        expect(service.calculateOverallProgress([]), 0.0);
      });

      test('should calculate average progress', () {
        final subjects = [
          SubjectProgress('Math', 0.8, Colors.blue),
          SubjectProgress('Science', 0.6, Colors.green),
          SubjectProgress('English', 0.9, Colors.red),
        ];

        final avg = service.calculateOverallProgress(subjects);
        
        // (0.8 + 0.6 + 0.9) / 3 = 0.766...
        expect(avg, closeTo(0.7667, 0.001));
      });

      test('should handle single subject', () {
        final subjects = [SubjectProgress('Math', 0.75, Colors.blue)];
        expect(service.calculateOverallProgress(subjects), 0.75);
      });

      test('should handle all zeros', () {
        final subjects = [
          SubjectProgress('Math', 0.0, Colors.blue),
          SubjectProgress('Science', 0.0, Colors.green),
        ];
        expect(service.calculateOverallProgress(subjects), 0.0);
      });

      test('should handle perfect scores', () {
        final subjects = [
          SubjectProgress('Math', 1.0, Colors.blue),
          SubjectProgress('Science', 1.0, Colors.green),
        ];
        expect(service.calculateOverallProgress(subjects), 1.0);
      });
    });

    group('getOverallPerformanceMessage', () {
      test('should return excellent message for 80%+ progress', () {
        final subjects = [
          SubjectProgress('Math', 0.85, Colors.blue),
          SubjectProgress('Science', 0.80, Colors.green),
        ];
        
        final message = service.getOverallPerformanceMessage(subjects);
        expect(message, contains('Excellent'));
      });

      test('should return good message for 60-79% progress', () {
        final subjects = [
          SubjectProgress('Math', 0.70, Colors.blue),
          SubjectProgress('Science', 0.60, Colors.green),
        ];
        
        final message = service.getOverallPerformanceMessage(subjects);
        expect(message, contains('Good progress'));
      });

      test('should return making progress message for 40-59%', () {
        final subjects = [
          SubjectProgress('Math', 0.50, Colors.blue),
          SubjectProgress('Science', 0.45, Colors.green),
        ];
        
        final message = service.getOverallPerformanceMessage(subjects);
        expect(message, contains('Making progress'));
      });

      test('should return building foundations message for <40%', () {
        final subjects = [
          SubjectProgress('Math', 0.30, Colors.blue),
          SubjectProgress('Science', 0.20, Colors.green),
        ];
        
        final message = service.getOverallPerformanceMessage(subjects);
        expect(message, contains('Building foundations'));
      });
    });

    group('getPerformanceLevel', () {
      test('should return Expert for 90%+', () {
        expect(service.getPerformanceLevel(95), 'Expert');
        expect(service.getPerformanceLevel(90), 'Expert');
      });

      test('should return Advanced for 80-89%', () {
        expect(service.getPerformanceLevel(85), 'Advanced');
        expect(service.getPerformanceLevel(80), 'Advanced');
      });

      test('should return Proficient for 70-79%', () {
        expect(service.getPerformanceLevel(75), 'Proficient');
        expect(service.getPerformanceLevel(70), 'Proficient');
      });

      test('should return Developing for 60-69%', () {
        expect(service.getPerformanceLevel(65), 'Developing');
        expect(service.getPerformanceLevel(60), 'Developing');
      });

      test('should return Emerging for 40-59%', () {
        expect(service.getPerformanceLevel(50), 'Emerging');
        expect(service.getPerformanceLevel(40), 'Emerging');
      });

      test('should return Beginner for <40%', () {
        expect(service.getPerformanceLevel(35), 'Beginner');
        expect(service.getPerformanceLevel(0), 'Beginner');
      });
    });

    group('calculateAccuracy', () {
      test('should calculate correct percentage', () {
        expect(service.calculateAccuracy(8, 10), 80.0);
        expect(service.calculateAccuracy(1, 2), 50.0);
      });

      test('should return 0 for no questions', () {
        expect(service.calculateAccuracy(0, 0), 0.0);
      });

      test('should handle perfect score', () {
        expect(service.calculateAccuracy(10, 10), 100.0);
      });

      test('should handle zero correct', () {
        expect(service.calculateAccuracy(0, 10), 0.0);
      });
    });

    group('estimateStudyTimeMinutes', () {
      test('should calculate 2 minutes per question', () {
        expect(service.estimateStudyTimeMinutes(10), 20);
        expect(service.estimateStudyTimeMinutes(30), 60);
      });

      test('should return 0 for no questions', () {
        expect(service.estimateStudyTimeMinutes(0), 0);
      });
    });

    group('convertMinutesToHours', () {
      test('should convert and round correctly', () {
        expect(service.convertMinutesToHours(60), 1);
        expect(service.convertMinutesToHours(120), 2);
        expect(service.convertMinutesToHours(90), 2); // 1.5 rounds to 2
        expect(service.convertMinutesToHours(30), 1); // 0.5 rounds to 1
      });

      test('should return 0 for less than 30 minutes', () {
        expect(service.convertMinutesToHours(25), 0);
      });
    });

    group('calculateAverageScore', () {
      test('should calculate correct average', () {
        expect(service.calculateAverageScore([80, 90, 70]), 80.0);
        expect(service.calculateAverageScore([100, 100, 100]), 100.0);
      });

      test('should return 0 for empty list', () {
        expect(service.calculateAverageScore([]), 0.0);
      });

      test('should handle single score', () {
        expect(service.calculateAverageScore([85]), 85.0);
      });

      test('should handle decimal scores', () {
        final avg = service.calculateAverageScore([85.5, 90.5, 80.0]);
        expect(avg, closeTo(85.33, 0.01));
      });
    });

    group('findWeakestSubject', () {
      test('should return null for empty list', () {
        expect(service.findWeakestSubject([]), null);
      });

      test('should find subject with lowest progress', () {
        final subjects = [
          SubjectProgress('Math', 0.8, Colors.blue),
          SubjectProgress('Science', 0.3, Colors.green),
          SubjectProgress('English', 0.9, Colors.red),
        ];

        final weakest = service.findWeakestSubject(subjects);
        expect(weakest?.name, 'Science');
        expect(weakest?.progress, 0.3);
      });

      test('should handle single subject', () {
        final subjects = [SubjectProgress('Math', 0.5, Colors.blue)];
        final weakest = service.findWeakestSubject(subjects);
        expect(weakest?.name, 'Math');
      });
    });

    group('findStrongestSubject', () {
      test('should return null for empty list', () {
        expect(service.findStrongestSubject([]), null);
      });

      test('should find subject with highest progress', () {
        final subjects = [
          SubjectProgress('Math', 0.8, Colors.blue),
          SubjectProgress('Science', 0.3, Colors.green),
          SubjectProgress('English', 0.95, Colors.red),
        ];

        final strongest = service.findStrongestSubject(subjects);
        expect(strongest?.name, 'English');
        expect(strongest?.progress, 0.95);
      });

      test('should handle single subject', () {
        final subjects = [SubjectProgress('Math', 0.5, Colors.blue)];
        final strongest = service.findStrongestSubject(subjects);
        expect(strongest?.name, 'Math');
      });
    });
  });
}
