class MockExam {
  final String id;
  final String title;
  final String description;
  final String examType;
  final String subject;
  final String difficulty;
  final String year;
  final int duration; // in minutes
  final int totalQuestions;
  final int totalMarks;
  final bool isCompleted;
  final int? lastScore;
  final DateTime? lastAttemptDate;
  final List<String> topics;
  final String instructions;
  final bool isTimeLimited;
  final bool allowRetake;
  final int maxAttempts;
  final int currentAttempts;

  MockExam({
    required this.id,
    required this.title,
    required this.description,
    required this.examType,
    required this.subject,
    required this.difficulty,
    required this.year,
    required this.duration,
    required this.totalQuestions,
    required this.totalMarks,
    this.isCompleted = false,
    this.lastScore,
    this.lastAttemptDate,
    required this.topics,
    required this.instructions,
    this.isTimeLimited = true,
    this.allowRetake = true,
    this.maxAttempts = 3,
    this.currentAttempts = 0,
  });

  factory MockExam.fromJson(Map<String, dynamic> json) {
    return MockExam(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      examType: json['examType'] ?? '',
      subject: json['subject'] ?? '',
      difficulty: json['difficulty'] ?? '',
      year: json['year'] ?? '',
      duration: json['duration'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      totalMarks: json['totalMarks'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      lastScore: json['lastScore'],
      lastAttemptDate: json['lastAttemptDate'] != null 
          ? DateTime.parse(json['lastAttemptDate']) 
          : null,
      topics: List<String>.from(json['topics'] ?? []),
      instructions: json['instructions'] ?? '',
      isTimeLimited: json['isTimeLimited'] ?? true,
      allowRetake: json['allowRetake'] ?? true,
      maxAttempts: json['maxAttempts'] ?? 3,
      currentAttempts: json['currentAttempts'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'examType': examType,
      'subject': subject,
      'difficulty': difficulty,
      'year': year,
      'duration': duration,
      'totalQuestions': totalQuestions,
      'totalMarks': totalMarks,
      'isCompleted': isCompleted,
      'lastScore': lastScore,
      'lastAttemptDate': lastAttemptDate?.toIso8601String(),
      'topics': topics,
      'instructions': instructions,
      'isTimeLimited': isTimeLimited,
      'allowRetake': allowRetake,
      'maxAttempts': maxAttempts,
      'currentAttempts': currentAttempts,
    };
  }

  bool get canRetake => allowRetake && currentAttempts < maxAttempts;
  
  double get completionPercentage {
    if (maxAttempts == 0) return 0.0;
    return (currentAttempts / maxAttempts) * 100;
  }

  String get statusText {
    if (!isCompleted) return 'Not Started';
    if (canRetake) return 'Retake Available';
    return 'Completed';
  }
}
