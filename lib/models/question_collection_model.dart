import 'question_model.dart';

/// Represents a collection of questions grouped by year, subject, exam type, and question type
/// Example: "BECE RME 1999 MCQ" containing 40 multiple choice questions
class QuestionCollection {
  final String id; // e.g., "bece_rme_1999_mcq"
  final String title; // e.g., "BECE RME 1999 MCQ"
  final Subject subject;
  final ExamType examType;
  final String year;
  final QuestionType questionType;
  final int questionCount;
  final String? description;
  final String? imageUrl;
  final List<Question> questions; // The actual questions in this collection

  QuestionCollection({
    required this.id,
    required this.title,
    required this.subject,
    required this.examType,
    required this.year,
    required this.questionType,
    required this.questionCount,
    this.description,
    this.imageUrl,
    required this.questions,
  });

  /// Helper method to format display name
  String get displayName {
    final subjectName = _formatSubjectName(subject);
    final examName = examType.name.toUpperCase();
    final typeName = _formatQuestionType(questionType);
    return '$examName $subjectName $year $typeName';
  }

  /// Helper method to create collection ID
  static String createId(Subject subject, ExamType examType, String year, QuestionType questionType) {
    return '${examType.name}_${subject.name}_${year}_${questionType.name}'.toLowerCase();
  }

  String _formatSubjectName(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English';
      case Subject.integratedScience:
        return 'Integrated Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.ga:
        return 'Ga';
      case Subject.asanteTwi:
        return 'Asante Twi';
      case Subject.french:
        return 'French';
      case Subject.ict:
        return 'ICT';
      case Subject.religiousMoralEducation:
        return 'RME';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.careerTechnology:
        return 'Career Technology';
      case Subject.trivia:
        return 'Trivia';
    }
  }

  String _formatQuestionType(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'MCQ';
      case QuestionType.shortAnswer:
        return 'Short Answer';
      case QuestionType.essay:
        return 'Theory'; // Display as "Theory" instead of "Essay"
      case QuestionType.calculation:
        return 'Calculation';
      case QuestionType.trivia:
        return 'Trivia';
    }
  }

  /// Group a list of questions into collections
  static List<QuestionCollection> groupQuestions(List<Question> questions) {
    final Map<String, List<Question>> grouped = {};

    for (final question in questions) {
      final collectionId = createId(
        question.subject,
        question.examType,
        question.year,
        question.type,
      );

      if (!grouped.containsKey(collectionId)) {
        grouped[collectionId] = [];
      }
      grouped[collectionId]!.add(question);
    }

    return grouped.entries.map((entry) {
      final questions = entry.value;
      final firstQuestion = questions.first;
      
      final collection = QuestionCollection(
        id: entry.key,
        title: '', // Will be set by displayName
        subject: firstQuestion.subject,
        examType: firstQuestion.examType,
        year: firstQuestion.year,
        questionType: firstQuestion.type,
        questionCount: questions.length,
        questions: questions,
      );

      return collection;
    }).toList();
  }
}
