import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';

class SubjectQuickLinksWidget extends StatelessWidget {
  final Function(Subject) onSubjectSelected;
  final List<Question> questions;

  const SubjectQuickLinksWidget({
    Key? key,
    required this.onSubjectSelected,
    required this.questions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subjects = _getAvailableSubjects();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Subject Access',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final questionCount = _getQuestionCountForSubject(subject);
              
              return InkWell(
                onTap: () => onSubjectSelected(subject),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getSubjectColor(subject).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getSubjectColor(subject).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getSubjectIcon(subject),
                        color: _getSubjectColor(subject),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSubjectDisplayName(subject),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getSubjectColor(subject),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$questionCount questions',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Subject> _getAvailableSubjects() {
    final subjectCounts = <Subject, int>{};
    
    for (final question in questions) {
      subjectCounts[question.subject] = (subjectCounts[question.subject] ?? 0) + 1;
    }
    
    return subjectCounts.keys.toList()..sort((a, b) => 
      subjectCounts[b]!.compareTo(subjectCounts[a]!));
  }

  int _getQuestionCountForSubject(Subject subject) {
    return questions.where((q) => q.subject == subject).length;
  }

  Color _getSubjectColor(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return const Color(0xFF1565C0);
      case Subject.english:
        return const Color(0xFF2E7D32);
      case Subject.integratedScience:
        return const Color(0xFFE65100);
      case Subject.socialStudies:
        return const Color(0xFF7B1FA2);
      case Subject.religiousMoralEducation:
        return const Color(0xFFD32F2F);
      case Subject.ga:
        return const Color(0xFF795548);
      case Subject.asanteTwi:
        return const Color(0xFF5D4037);
      case Subject.french:
        return const Color(0xFF3F51B5);
      case Subject.ict:
        return const Color(0xFF009688);
      case Subject.creativeArts:
        return const Color(0xFFFF5722);
      case Subject.careerTechnology:
        return const Color(0xFF607D8B);
      case Subject.trivia:
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF616161);
    }
  }

  IconData _getSubjectIcon(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return Icons.functions;
      case Subject.english:
        return Icons.menu_book;
      case Subject.integratedScience:
        return Icons.science;
      case Subject.socialStudies:
        return Icons.public;
      case Subject.religiousMoralEducation:
        return Icons.church;
      case Subject.ga:
        return Icons.language;
      case Subject.asanteTwi:
        return Icons.record_voice_over;
      case Subject.french:
        return Icons.translate;
      case Subject.ict:
        return Icons.computer;
      case Subject.creativeArts:
        return Icons.palette;
      case Subject.careerTechnology:
        return Icons.build;
      case Subject.trivia:
        return Icons.psychology;
      default:
        return Icons.book;
    }
  }

  String _getSubjectDisplayName(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English';
      case Subject.integratedScience:
        return 'Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.religiousMoralEducation:
        return 'RME';
      case Subject.ga:
        return 'Ga';
      case Subject.asanteTwi:
        return 'Asante Twi';
      case Subject.french:
        return 'French';
      case Subject.ict:
        return 'ICT';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.careerTechnology:
        return 'Career Tech';
      case Subject.trivia:
        return 'Trivia';
      default:
        return subject.name;
    }
  }
}