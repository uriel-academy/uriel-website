import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/models/question_model.dart';

void main() {
  group('Question Model Tests', () {
    test('should create a question with required fields', () {
      final question = Question(
        id: 'q1',
        questionText: 'What is 2 + 2?',
        type: QuestionType.multipleChoice,
        subject: Subject.mathematics,
        examType: ExamType.bece,
        year: '2024',
        section: 'A',
        questionNumber: 1,
        correctAnswer: '4',
        marks: 1,
        difficulty: 'easy',
        topics: ['Addition'],
        createdAt: DateTime(2024, 1, 1),
        createdBy: 'admin',
      );

      expect(question.id, 'q1');
      expect(question.questionText, 'What is 2 + 2?');
      expect(question.type, QuestionType.multipleChoice);
      expect(question.subject, Subject.mathematics);
      expect(question.correctAnswer, '4');
      expect(question.isActive, true); // Default value
    });

    test('should serialize to JSON correctly', () {
      final question = Question(
        id: 'q1',
        questionText: 'What is 2 + 2?',
        type: QuestionType.multipleChoice,
        subject: Subject.mathematics,
        examType: ExamType.bece,
        year: '2024',
        section: 'A',
        questionNumber: 1,
        options: ['2', '3', '4', '5'],
        correctAnswer: '4',
        explanation: 'Basic addition',
        marks: 1,
        difficulty: 'easy',
        topics: ['Addition'],
        createdAt: DateTime(2024, 1, 1),
        createdBy: 'admin',
        isActive: true,
      );

      final json = question.toJson();

      expect(json['id'], 'q1');
      expect(json['questionText'], 'What is 2 + 2?');
      expect(json['type'], 'multipleChoice');
      expect(json['subject'], 'mathematics');
      expect(json['examType'], 'bece');
      expect(json['year'], '2024');
      expect(json['options'], ['2', '3', '4', '5']);
      expect(json['correctAnswer'], '4');
      expect(json['explanation'], 'Basic addition');
      expect(json['marks'], 1);
      expect(json['difficulty'], 'easy');
      expect(json['topics'], ['Addition']);
      expect(json['isActive'], true);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'q1',
        'questionText': 'What is 2 + 2?',
        'type': 'multipleChoice',
        'subject': 'mathematics',
        'examType': 'bece',
        'year': '2024',
        'section': 'A',
        'questionNumber': 1,
        'options': ['2', '3', '4', '5'],
        'correctAnswer': '4',
        'explanation': 'Basic addition',
        'marks': 1,
        'difficulty': 'easy',
        'topics': ['Addition'],
        'createdAt': '2024-01-01T00:00:00.000Z',
        'createdBy': 'admin',
        'isActive': true,
      };

      final question = Question.fromJson(json);

      expect(question.id, 'q1');
      expect(question.questionText, 'What is 2 + 2?');
      expect(question.type, QuestionType.multipleChoice);
      expect(question.subject, Subject.mathematics);
      expect(question.examType, ExamType.bece);
      expect(question.options, ['2', '3', '4', '5']);
      expect(question.correctAnswer, '4');
      expect(question.explanation, 'Basic addition');
    });

    test('should handle legacy RME subject value', () {
      final json = {
        'id': 'q1',
        'questionText': 'Test question',
        'type': 'essay',
        'subject': 'RME', // Legacy value
        'examType': 'bece',
        'year': '2024',
        'section': 'B',
        'questionNumber': 1,
        'correctAnswer': 'Sample answer',
        'marks': 5,
        'difficulty': 'medium',
        'topics': ['Religion'],
        'createdAt': '2024-01-01T00:00:00.000Z',
        'createdBy': 'admin',
      };

      final question = Question.fromJson(json);

      expect(question.subject, Subject.religiousMoralEducation);
    });

    test('should handle unknown subject value with default', () {
      final json = {
        'id': 'q1',
        'questionText': 'Test question',
        'type': 'multipleChoice',
        'subject': 'unknown', // Invalid value
        'examType': 'practice',
        'year': '2024',
        'section': 'A',
        'questionNumber': 1,
        'correctAnswer': 'A',
        'marks': 1,
        'difficulty': 'easy',
        'topics': [],
        'createdAt': '2024-01-01T00:00:00.000Z',
        'createdBy': 'admin',
      };

      final question = Question.fromJson(json);

      expect(question.subject, Subject.religiousMoralEducation); // Default
    });

    test('should handle missing optional fields', () {
      final json = {
        'id': 'q1',
        'questionText': 'Test',
        'type': 'shortAnswer',
        'subject': 'english',
        'examType': 'mock',
        'year': '2024',
        'section': 'A',
        'questionNumber': 1,
        'correctAnswer': 'answer',
        'marks': 2,
        'difficulty': 'medium',
        'topics': ['Grammar'],
        'createdAt': '2024-01-01T00:00:00.000Z',
        'createdBy': 'admin',
      };

      final question = Question.fromJson(json);

      expect(question.options, isNull);
      expect(question.explanation, isNull);
      expect(question.imageUrl, isNull);
      expect(question.imageBeforeQuestion, isNull);
      expect(question.imageAfterQuestion, isNull);
      expect(question.optionImages, isNull);
      expect(question.passageId, isNull);
      expect(question.sectionInstructions, isNull);
      expect(question.relatedQuestions, isNull);
    });

    test('should handle Firestore Timestamp format', () {
      final json = {
        'id': 'q1',
        'questionText': 'Test',
        'type': 'multipleChoice',
        'subject': 'mathematics',
        'examType': 'bece',
        'year': '2024',
        'section': 'A',
        'questionNumber': 1,
        'correctAnswer': 'A',
        'marks': 1,
        'difficulty': 'easy',
        'topics': [],
        'createdAt': {
          '_seconds': 1704067200, // Jan 1, 2024 00:00:00 UTC
          '_nanoseconds': 0,
        },
        'createdBy': 'admin',
      };

      final question = Question.fromJson(json);

      expect(question.createdAt.year, 2024);
      expect(question.createdAt.month, 1);
      expect(question.createdAt.day, 1);
    });

    test('should include optional fields in JSON when provided', () {
      final question = Question(
        id: 'q1',
        questionText: 'Test',
        type: QuestionType.multipleChoice,
        subject: Subject.english,
        examType: ExamType.bece,
        year: '2024',
        section: 'A',
        questionNumber: 1,
        correctAnswer: 'A',
        marks: 1,
        difficulty: 'easy',
        topics: [],
        createdAt: DateTime(2024, 1, 1),
        createdBy: 'admin',
        passageId: 'passage_1',
        sectionInstructions: 'Read the passage carefully',
        relatedQuestions: [1, 2, 3],
      );

      final json = question.toJson();

      expect(json['passageId'], 'passage_1');
      expect(json['sectionInstructions'], 'Read the passage carefully');
      expect(json['relatedQuestions'], [1, 2, 3]);
    });

    test('should handle optionImages correctly', () {
      final question = Question(
        id: 'q1',
        questionText: 'Identify the shape',
        type: QuestionType.multipleChoice,
        subject: Subject.mathematics,
        examType: ExamType.bece,
        year: '2024',
        section: 'A',
        questionNumber: 1,
        options: ['A', 'B', 'C', 'D'],
        optionImages: {
          'A': 'https://example.com/circle.png',
          'B': 'https://example.com/square.png',
          'C': 'https://example.com/triangle.png',
          'D': 'https://example.com/rectangle.png',
        },
        correctAnswer: 'A',
        marks: 1,
        difficulty: 'easy',
        topics: ['Shapes'],
        createdAt: DateTime(2024, 1, 1),
        createdBy: 'admin',
      );

      final json = question.toJson();
      expect(json['optionImages'], isA<Map<String, String>>());
      expect(json['optionImages']['A'], 'https://example.com/circle.png');

      final deserialized = Question.fromJson(json);
      expect(deserialized.optionImages, isNotNull);
      expect(deserialized.optionImages!['A'], 'https://example.com/circle.png');
    });

    test('should handle different question types', () {
      final types = [
        QuestionType.multipleChoice,
        QuestionType.shortAnswer,
        QuestionType.essay,
        QuestionType.calculation,
        QuestionType.trivia,
      ];

      for (final type in types) {
        final json = {
          'id': 'q1',
          'questionText': 'Test',
          'type': type.name,
          'subject': 'mathematics',
          'examType': 'practice',
          'year': '2024',
          'section': 'A',
          'questionNumber': 1,
          'correctAnswer': 'answer',
          'marks': 1,
          'difficulty': 'easy',
          'topics': [],
          'createdAt': '2024-01-01T00:00:00.000Z',
          'createdBy': 'admin',
        };

        final question = Question.fromJson(json);
        expect(question.type, type);
      }
    });

    test('should handle all exam types', () {
      final examTypes = [
        ExamType.bece,
        ExamType.wassce,
        ExamType.mock,
        ExamType.practice,
        ExamType.trivia,
      ];

      for (final examType in examTypes) {
        final json = {
          'id': 'q1',
          'questionText': 'Test',
          'type': 'multipleChoice',
          'subject': 'mathematics',
          'examType': examType.name,
          'year': '2024',
          'section': 'A',
          'questionNumber': 1,
          'correctAnswer': 'A',
          'marks': 1,
          'difficulty': 'easy',
          'topics': [],
          'createdAt': '2024-01-01T00:00:00.000Z',
          'createdBy': 'admin',
        };

        final question = Question.fromJson(json);
        expect(question.examType, examType);
      }
    });
  });
}
