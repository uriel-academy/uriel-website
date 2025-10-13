// Enums used across the app. Keep in sync with backend naming where possible.
enum Subject {
  mathematics,
  english,
  integratedScience,
  socialStudies,
  ghanaianLanguage,
  french,
  ict,
  religiousMoralEducation,
  creativeArts,
  trivia,
}

enum ExamType { bece, wassce, mock, practice, trivia }

extension SubjectX on Subject {
  String get displayName {
    switch (this) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English Language';
      case Subject.integratedScience:
        return 'Integrated Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.ghanaianLanguage:
        return 'Ghanaian Language';
      case Subject.french:
        return 'French';
      case Subject.ict:
        return 'ICT';
      case Subject.religiousMoralEducation:
        return 'Religious & Moral Education';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.trivia:
        return 'Trivia';
    }
  }
}
