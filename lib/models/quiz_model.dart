import '../models/question_model.dart' as question_model;

class Quiz {
  final String id;
  final String subject;
  final String examType;
  final String level;
  final int totalQuestions;
  final int correctAnswers;
  final List<QuizAnswer> answers;
  final DateTime startTime;
  final DateTime endTime;
  final String? triviaCategory;

  Quiz({
    required this.id,
    required this.subject,
    required this.examType,
    required this.level,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.answers,
    required this.startTime,
    required this.endTime,
    this.triviaCategory,
  });

  double get percentage => (correctAnswers / totalQuestions) * 100;
  
  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'examType': examType,
    'level': level,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'answers': answers.map((a) => a.toJson()).toList(),
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'triviaCategory': triviaCategory,
  };

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
    id: json['id'],
    subject: json['subject'],
    examType: json['examType'],
    level: json['level'],
    totalQuestions: json['totalQuestions'],
    correctAnswers: json['correctAnswers'],
    answers: (json['answers'] as List)
        .map((a) => QuizAnswer.fromJson(a))
        .toList(),
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    triviaCategory: json['triviaCategory'],
  );
}

class QuizAnswer {
  final String questionId;
  final String questionText;
  final String userAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final List<String> options;
  final String explanation;

  QuizAnswer({
    required this.questionId,
    required this.questionText,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.options,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'questionText': questionText,
    'userAnswer': userAnswer,
    'correctAnswer': correctAnswer,
    'isCorrect': isCorrect,
    'options': options,
    'explanation': explanation,
  };

  factory QuizAnswer.fromJson(Map<String, dynamic> json) => QuizAnswer(
    questionId: json['questionId'],
    questionText: json['questionText'],
    userAnswer: json['userAnswer'],
    correctAnswer: json['correctAnswer'],
    isCorrect: json['isCorrect'],
    options: List<String>.from(json['options']),
    explanation: json['explanation'] ?? '',
  );
}

class QuizStats {
  final int totalQuizzesTaken;
  final double averageScore;
  final int bestScore;
  final String favoriteSubject;
  final Duration totalTimeSpent;
  final List<Quiz> recentQuizzes;

  QuizStats({
    required this.totalQuizzesTaken,
    required this.averageScore,
    required this.bestScore,
    required this.favoriteSubject,
    required this.totalTimeSpent,
    required this.recentQuizzes,
  });

  Map<String, dynamic> toJson() => {
    'totalQuizzesTaken': totalQuizzesTaken,
    'averageScore': averageScore,
    'bestScore': bestScore,
    'favoriteSubject': favoriteSubject,
    'totalTimeSpent': totalTimeSpent.inSeconds,
    'recentQuizzes': recentQuizzes.map((q) => q.toJson()).toList(),
  };

  factory QuizStats.fromJson(Map<String, dynamic> json) => QuizStats(
    totalQuizzesTaken: json['totalQuizzesTaken'],
    averageScore: json['averageScore'].toDouble(),
    bestScore: json['bestScore'],
    favoriteSubject: json['favoriteSubject'],
    totalTimeSpent: Duration(seconds: json['totalTimeSpent']),
    recentQuizzes: (json['recentQuizzes'] as List)
        .map((q) => Quiz.fromJson(q))
        .toList(),
  );
}

class QuizSession {
  final String sessionId;
  final String subject;
  final String examType;
  final String level;
  final List<question_model.Question> questions;
  final Map<int, String> answers;
  final DateTime startTime;
  final bool isCompleted;
  final int currentQuestionIndex;

  QuizSession({
    required this.sessionId,
    required this.subject,
    required this.examType,
    required this.level,
    required this.questions,
    required this.answers,
    required this.startTime,
    required this.isCompleted,
    required this.currentQuestionIndex,
  });

  double get progress => (currentQuestionIndex + 1) / questions.length;
  
  int get answeredQuestions => answers.length;
  
  Duration get elapsedTime => DateTime.now().difference(startTime);

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'subject': subject,
    'examType': examType,
    'level': level,
    'questions': questions.map((q) => q.toJson()).toList(),
    'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
    'startTime': startTime.toIso8601String(),
    'isCompleted': isCompleted,
    'currentQuestionIndex': currentQuestionIndex,
  };

  factory QuizSession.fromJson(Map<String, dynamic> json) => QuizSession(
    sessionId: json['sessionId'],
    subject: json['subject'],
    examType: json['examType'],
    level: json['level'],
    questions: (json['questions'] as List)
        .map((q) => question_model.Question.fromJson(q))
        .toList(),
    answers: (json['answers'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(int.parse(key), value.toString())),
    startTime: DateTime.parse(json['startTime']),
    isCompleted: json['isCompleted'],
    currentQuestionIndex: json['currentQuestionIndex'],
  );
}
