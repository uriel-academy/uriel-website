import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/models/quiz_model.dart';

void main() {
  group('Quiz Model Tests', () {
    test('should calculate percentage correctly', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Mathematics',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 40,
        correctAnswers: 30,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 11, 0),
      );

      expect(quiz.percentage, 75.0);
    });

    test('should calculate duration correctly', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'English',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 20,
        correctAnswers: 15,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 10, 45),
      );

      expect(quiz.duration.inMinutes, 45);
      expect(quiz.duration.inSeconds, 2700);
    });

    test('should handle perfect score', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Science',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 20,
        correctAnswers: 20,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 10, 30),
      );

      expect(quiz.percentage, 100.0);
    });

    test('should handle zero score', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Mathematics',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 20,
        correctAnswers: 0,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 10, 30),
      );

      expect(quiz.percentage, 0.0);
    });

    test('should serialize to JSON correctly', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Mathematics',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 40,
        correctAnswers: 30,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 11, 0),
        triviaCategory: 'Science',
      );

      final json = quiz.toJson();

      expect(json['id'], 'quiz_1');
      expect(json['subject'], 'Mathematics');
      expect(json['examType'], 'BECE');
      expect(json['level'], 'JHS 3');
      expect(json['totalQuestions'], 40);
      expect(json['correctAnswers'], 30);
      expect(json['triviaCategory'], 'Science');
      expect(json['answers'], isA<List>());
      expect(json['startTime'], isA<String>());
      expect(json['endTime'], isA<String>());
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'quiz_1',
        'subject': 'English',
        'examType': 'WASSCE',
        'level': 'JHS 3',
        'totalQuestions': 50,
        'correctAnswers': 40,
        'answers': [],
        'startTime': '2024-01-01T10:00:00.000Z',
        'endTime': '2024-01-01T11:30:00.000Z',
      };

      final quiz = Quiz.fromJson(json);

      expect(quiz.id, 'quiz_1');
      expect(quiz.subject, 'English');
      expect(quiz.examType, 'WASSCE');
      expect(quiz.level, 'JHS 3');
      expect(quiz.totalQuestions, 50);
      expect(quiz.correctAnswers, 40);
      expect(quiz.percentage, 80.0);
      expect(quiz.duration.inMinutes, 90);
    });

    test('should handle trivia category', () {
      final quiz = Quiz(
        id: 'quiz_trivia',
        subject: 'Trivia',
        examType: 'Trivia',
        level: 'General',
        totalQuestions: 10,
        correctAnswers: 7,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 10, 10),
        triviaCategory: 'History',
      );

      expect(quiz.triviaCategory, 'History');
      expect(quiz.subject, 'Trivia');
    });

    test('should handle quiz without trivia category', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Mathematics',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 20,
        correctAnswers: 15,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 10, 30),
      );

      expect(quiz.triviaCategory, isNull);
    });

    test('should handle fractional percentages', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Science',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 30,
        correctAnswers: 20,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 10, 45),
      );

      expect(quiz.percentage, closeTo(66.67, 0.01));
    });

    test('should handle very short duration', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Trivia',
        examType: 'Trivia',
        level: 'General',
        totalQuestions: 5,
        correctAnswers: 4,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0, 0),
        endTime: DateTime(2024, 1, 1, 10, 0, 30),
      );

      expect(quiz.duration.inSeconds, 30);
    });

    test('should handle very long duration', () {
      final quiz = Quiz(
        id: 'quiz_1',
        subject: 'Mathematics',
        examType: 'BECE',
        level: 'JHS 3',
        totalQuestions: 100,
        correctAnswers: 75,
        answers: [],
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 13, 30),
      );

      expect(quiz.duration.inHours, 3);
      expect(quiz.duration.inMinutes, 210);
    });
  });
}
