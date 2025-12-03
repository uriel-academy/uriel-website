import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';
import '../models/question_collection_model.dart';
import '../services/question_service.dart';
import 'quiz_taker_page.dart';
import 'theory_year_questions_list.dart';

// Model class for subject cards
class SubjectCard {
  final String name;
  final String displayName;
  final String mobileDisplayName;
  final String desktopDisplayName;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final int collectionCount;
  final int completedCollections;

  SubjectCard({
    required this.name,
    required this.displayName,
    required this.mobileDisplayName,
    required this.desktopDisplayName,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.collectionCount,
    this.completedCollections = 0,
  });
}

/// Page that displays past questions grouped as collections (e.g., "BECE RME 1999 MCQ")
/// This provides a much cleaner UI when there are hundreds of questions across multiple years
class QuestionCollectionsPage extends StatefulWidget {
  final String? initialSubject;

  const QuestionCollectionsPage({Key? key, this.initialSubject}) : super(key: key);

  @override
  State<QuestionCollectionsPage> createState() => _QuestionCollectionsPageState();
}

class _QuestionCollectionsPageState extends State<QuestionCollectionsPage> {
  final QuestionService _questionService = QuestionService();
  
  List<QuestionCollection> _collections = [];
  List<QuestionCollection> _filteredCollections = [];
  bool _isLoading = false;
  bool _randomizeQuestions = false;
  // Map to track question count selection per collection
  final Map<String, int> _selectedQuestionCounts = {};
  
  // Pagination (unified)
  int _currentPage = 0;
  final int _itemsPerPage = 12; // Collections per page
  
  // Filters
  String _selectedQuestionType = 'All Types'; // MCQ or Theory
  String _selectedSubject = 'All Subjects';
  String _selectedTopic = 'All Topics';
  String _selectedYear = 'All Years';
  final TextEditingController _searchController = TextEditingController();

  // Subject Cards
  List<SubjectCard> _subjectCards = [];
  bool _isLoadingSubjects = false;
  
  // View state - whether showing subject cards or collection view
  bool _isViewingCollections = false;
  String _viewingSubjectName = '';
  
  // Error handling
  String? _errorMessage;
  bool _hasError = false;
  
  // Debouncing for search
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
    _loadCollections();
    // On initial load, do not show any collections
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _filteredCollections = [];
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  // P2 Fix #7: Load saved filters from SharedPreferences
  Future<void> _loadSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedQuestionType = prefs.getString('filter_questionType') ?? 'All Types';
        _selectedSubject = prefs.getString('filter_subject') ?? 'All Subjects';
        _selectedTopic = prefs.getString('filter_topic') ?? 'All Topics';
        _selectedYear = prefs.getString('filter_year') ?? 'All Years';
        _randomizeQuestions = prefs.getBool('randomize_questions') ?? false;
      });
      debugPrint('✅ Loaded saved filters: Type=$_selectedQuestionType, Subject=$_selectedSubject');
    } catch (e) {
      debugPrint('⚠️ Could not load saved filters: $e');
    }
  }

  // P2 Fix #7: Save filters to SharedPreferences
  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('filter_questionType', _selectedQuestionType);
      await prefs.setString('filter_subject', _selectedSubject);
      await prefs.setString('filter_topic', _selectedTopic);
      await prefs.setString('filter_year', _selectedYear);
      await prefs.setBool('randomize_questions', _randomizeQuestions);
      debugPrint('💾 Saved filters to preferences');
    } catch (e) {
      debugPrint('⚠️ Could not save filters: $e');
    }
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🚀 Loading collection metadata from Firestore (no questions)...');
      
      // Load all collections from questionCollections (MCQ, Theory, and Topics)
      final collectionsData = await _questionService.getQuestionCollections(activeOnly: true);
      debugPrint('📚 Found ${collectionsData.length} collections in Firestore');
      
      final allCollections = <QuestionCollection>[];
      
      for (final collData in collectionsData) {
        try {
          final questionIds = List<String>.from(collData['questionIds'] ?? []);
          if (questionIds.isEmpty) continue;
          
          // Parse subject
          final subjectStr = collData['subject'] ?? 'ict';
          Subject subject = Subject.ict;
          try {
            subject = Subject.values.firstWhere(
              (s) => s.name.toLowerCase() == subjectStr.toLowerCase(),
              orElse: () => Subject.ict,
            );
          } catch (e) {
            debugPrint('⚠️ Unknown subject: $subjectStr');
          }
          
          // Parse exam type
          final examTypeStr = collData['examType'] ?? 'bece';
          ExamType examType = ExamType.bece;
          try {
            examType = ExamType.values.firstWhere(
              (e) => e.name.toLowerCase() == examTypeStr.toLowerCase(),
              orElse: () => ExamType.bece,
            );
          } catch (e) {
            debugPrint('⚠️ Unknown exam type: $examTypeStr');
          }
          
          // Parse question type
          final questionTypeStr = collData['questionType'] ?? 'multipleChoice';
          QuestionType questionType = QuestionType.multipleChoice;
          try {
            questionType = QuestionType.values.firstWhere(
              (q) => q.name.toLowerCase() == questionTypeStr.toLowerCase(),
              orElse: () => QuestionType.multipleChoice,
            );
          } catch (e) {
            debugPrint('⚠️ Unknown question type: $questionTypeStr');
          }
          
          String title = collData['name'] ?? 'Unnamed Collection';
          
          final collection = QuestionCollection(
            id: collData['id'] ?? '',
            title: title,
            examType: examType,
            subject: subject,
            year: collData['year'] ?? 'All Years',
            questionType: questionType,
            questionCount: collData['questionCount'] ?? questionIds.length,
            description: collData['topic'] ?? collData['description'],
            questions: [], // NO questions loaded
            questionIds: questionIds,
          );
          
          allCollections.add(collection);
        } catch (e) {
          debugPrint('❌ Error loading collection ${collData['id']}: $e');
        }
      }
      
      // Sort by subject, then year (most recent first), then type
      allCollections.sort((a, b) {
        final subjectCompare = a.subject.name.compareTo(b.subject.name);
        if (subjectCompare != 0) return subjectCompare;
        final yearCompare = b.year.compareTo(a.year);
        if (yearCompare != 0) return yearCompare;
        return a.questionType.name.compareTo(b.questionType.name);
      });
      
      debugPrint('📦 Total collections loaded: ${allCollections.length}');
      
      _collections = allCollections;
      
      setState(() {
        _filteredCollections = [];
        _currentPage = 0;
        _isLoading = false;
      });
      
      _loadSubjectCards();
      
      if (widget.initialSubject != null) {
        _applyInitialSubjectFilter();
      }
      
    } catch (e) {
      debugPrint('❌ Error loading collections: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load collections. Please check your connection and try again.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _retryLoadCollections,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadSubjectCards() async {
    setState(() => _isLoadingSubjects = true);
    try {
      // Get current user for progress tracking
      final user = FirebaseAuth.instance.currentUser;

      // Get subjects that have collections
      final subjectCounts = <String, int>{};

      for (final collection in _collections) {
        final subjectName = _getDisplayNameFromSubject(collection.subject);
        if (subjectName != null) {
          subjectCounts[subjectName] = (subjectCounts[subjectName] ?? 0) + 1;
        }
      }

      // Create subject cards with real progress - load all progress in parallel
      final subjectCards = <SubjectCard>[];

      if (user?.uid != null && user!.uid.isNotEmpty) {
        // Load progress for all subjects in parallel
        final progressFutures = <Future<int>>[];
        final subjectNames = subjectCounts.keys.toList();

        for (final subjectName in subjectNames) {
          progressFutures.add(_questionService.getUserCompletedCollectionsCount(user.uid, subjectName));
        }

        final progressResults = await Future.wait(progressFutures);

        for (int i = 0; i < subjectNames.length; i++) {
          final subjectName = subjectNames[i];
          final collectionCount = subjectCounts[subjectName]!;
          final completedCollections = progressResults[i];

          final card = _createSubjectCardSync(subjectName, collectionCount, completedCollections);
          if (card != null) {
            subjectCards.add(card);
          }
        }
      } else {
        // No user logged in, create cards with 0 progress
        for (final entry in subjectCounts.entries) {
          final card = _createSubjectCardSync(entry.key, entry.value, 0);
          if (card != null) {
            subjectCards.add(card);
          }
        }
      }

      // Sort by collection count (most collections first)
      subjectCards.sort((a, b) => b.collectionCount.compareTo(a.collectionCount));

      setState(() {
        _subjectCards = subjectCards;
        _isLoadingSubjects = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading subject cards: $e');
      setState(() {
        _isLoadingSubjects = false;
        _hasError = true;
        _errorMessage = 'Failed to load subjects. Please try again.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _retryLoadSubjects,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  SubjectCard? _createSubjectCardSync(String subjectName, int collectionCount, int completedCollections) {
    final config = _getSubjectCardConfig(subjectName);
    if (config == null) return null;

    return SubjectCard(
      name: subjectName,
      displayName: config['displayName'] as String,
      mobileDisplayName: config['mobileDisplayName'] as String,
      desktopDisplayName: config['desktopDisplayName'] as String,
      description: config['description'] as String,
      icon: config['icon'] as IconData,
      color: config['color'] as Color,
      gradient: [config['color'] as Color, (config['color'] as Color)],
      collectionCount: collectionCount,
      completedCollections: completedCollections,
    );
  }

  Map<String, dynamic>? _getSubjectCardConfig(String subjectName) {
    final configs = {
      'Mathematics': {
        'displayName': 'Mathematics',
        'mobileDisplayName': 'Maths',
        'desktopDisplayName': 'Mathematics',
        'description': 'Algebra, geometry, calculus, and mathematical problem-solving',
        'icon': Icons.calculate,
        'color': const Color(0xFFC7D9FF), // Soft Blue
      },
      'English': {
        'displayName': 'English Language',
        'mobileDisplayName': 'English',
        'desktopDisplayName': 'English\nLanguage',
        'description': 'Grammar, comprehension, literature, and language skills',
        'icon': Icons.article,
        'color': const Color(0xFFCDEFD1), // Soft Green
      },
      'Integrated Science': {
        'displayName': 'Integrated Science',
        'mobileDisplayName': 'Int. Science',
        'desktopDisplayName': 'Integrated\nScience',
        'description': 'Physics, chemistry, biology, and earth science',
        'icon': Icons.science,
        'color': const Color(0xFFC4F3EC), // Pastel Teal
      },
      'Social Studies': {
        'displayName': 'Social Studies',
        'mobileDisplayName': 'Social Studies',
        'desktopDisplayName': 'Social\nStudies',
        'description': 'History, geography, citizenship, and social sciences',
        'icon': Icons.public,
        'color': const Color(0xFFFFD9C7), // Peach
      },
      'Religious and Moral Education': {
        'displayName': 'RME',
        'mobileDisplayName': 'RME',
        'desktopDisplayName': 'RME',
        'description': 'Religious studies, ethics, and moral education',
        'icon': Icons.auto_stories,
        'color': const Color(0xFFE3D1FF), // Lavender/Violet
      },
      'Ga': {
        'displayName': 'Ga Language',
        'mobileDisplayName': 'Ga',
        'desktopDisplayName': 'Ga\nLanguage',
        'description': 'Ga language, literature, and cultural studies',
        'icon': Icons.chat_bubble_outline,
        'color': const Color(0xFFF6E3D0), // Warm Sand
      },
      'Asante Twi': {
        'displayName': 'Asante Twi',
        'mobileDisplayName': 'Asante Twi',
        'desktopDisplayName': 'Asante\nTwi',
        'description': 'Twi language, literature, and cultural studies',
        'icon': Icons.chat_bubble_outline,
        'color': const Color(0xFFFFC9C9), // Coral
      },
      'French': {
        'displayName': 'French',
        'mobileDisplayName': 'French',
        'desktopDisplayName': 'French',
        'description': 'French language, grammar, and literature',
        'icon': Icons.translate,
        'color': const Color(0xFFF9CFE7), // Rose Pink
      },
      'ICT': {
        'displayName': 'Information Technology',
        'mobileDisplayName': 'ICT',
        'desktopDisplayName': 'Information\nTechnology',
        'description': 'Computer science, programming, and digital skills',
        'icon': Icons.computer,
        'color': const Color(0xFFC9F3FF), // Light Cyan
      },
      'Creative Arts': {
        'displayName': 'Creative Arts',
        'mobileDisplayName': 'Creative Arts',
        'desktopDisplayName': 'Creative\nArts',
        'description': 'Visual arts, music, dance, and creative expression',
        'icon': Icons.palette,
        'color': const Color(0xFFECF8C8), // Lime Tint
      },
      'Career Technology': {
        'displayName': 'Career Technology',
        'mobileDisplayName': 'Career Tech',
        'desktopDisplayName': 'Career\nTechnology',
        'description': 'Technical skills and vocational training',
        'icon': Icons.work_outline,
        'color': const Color(0xFFFFF3C4), // Pale Yellow
      },
    };

    return configs[subjectName];
  }

  String? _getDisplayNameFromSubject(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English';
      case Subject.integratedScience:
        return 'Integrated Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.religiousMoralEducation:
        return 'Religious and Moral Education';
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
        return 'Career Technology';
      default:
        return null;
    }
  }

  void _onSubjectCardTap(SubjectCard subjectCard) {
    // Filter collections by the selected subject and group by collection type
    setState(() {
      _selectedSubject = subjectCard.name;
      _viewingSubjectName = subjectCard.displayName;
      _isViewingCollections = true;
      _currentPage = 0;
      
      // Only show collections for selected subject
      final subjectCollections = _collections.where((collection) {
        return _formatSubjectName(collection.subject) == _selectedSubject;
      }).toList();
      
      // Group collections by type: MCQ (multipleChoice year collections), Theory (essay year collections), Topic (topic collections)
      _filteredCollections = subjectCollections;
      _currentPage = 0;
    });
  }
  
  void _closeCollectionView() {
    setState(() {
      _isViewingCollections = false;
      _selectedSubject = 'All Subjects';
      _filteredCollections = [];
      _currentPage = 0;
    });
  }

  Widget _buildSubjectCards(bool isSmallScreen) {
    if (_isLoadingSubjects || _subjectCards.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine grid layout based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 480 ? 1 : (isSmallScreen ? 2 : 3);
    final crossAxisSpacing = isSmallScreen ? 12.0 : 20.0;
    final mainAxisSpacing = isSmallScreen ? 12.0 : 20.0;
    final childAspectRatio = isSmallScreen ? 1.1 : 1.05; // Slightly taller on mobile

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 48,
        vertical: isSmallScreen ? 20 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: isSmallScreen ? 16 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse by Subject',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isSmallScreen ? 28 : 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a subject to view past questions and practice tests',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: _subjectCards.length,
            itemBuilder: (context, index) {
              return _buildSubjectCard(_subjectCards[index], isSmallScreen);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectCard subjectCard, bool isSmallScreen) {
    final progress = subjectCard.collectionCount > 0
        ? subjectCard.completedCollections / subjectCard.collectionCount
        : 0.0;

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onSubjectCardTap(subjectCard),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top pastel section with title and collection count
            Expanded(
              flex: 70,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmallScreen ? 8 : 12,
                  isSmallScreen ? 8 : 12,
                  isSmallScreen ? 8 : 12,
                  isSmallScreen ? 4 : 6,
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 20 : 32,
                    horizontal: isSmallScreen ? 12 : 24,
                  ),
                  decoration: BoxDecoration(
                    color: subjectCard.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isSmallScreen
                            ? subjectCard.mobileDisplayName
                            : subjectCard.desktopDisplayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 23 : 26,
                          fontWeight: FontWeight.w700,
                          color: subjectCard.color.computeLuminance() > 0.5
                              ? const Color(0xFF1D1D1F)
                              : Colors.white,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        '${subjectCard.collectionCount} quiz sets',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 14,
                          fontWeight: FontWeight.w500,
                          color: subjectCard.color.computeLuminance() > 0.5
                              ? const Color(0xFF6E6E73)
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Middle section with arrow button
            Expanded(
              flex: 15,
              child: Center(
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: isSmallScreen ? 26 : 28,
                  color: subjectCard.color,
                  weight: 700,
                ),
              ),
            ),

            // Bottom section with progress bar and percentage
            Expanded(
              flex: 15,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 4 : 6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Progress bar
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(subjectCard.color),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    // Percentage text
                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6E6E73),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyInitialSubjectFilter() {
    final subject = widget.initialSubject?.toLowerCase() ?? '';
    if (subject.contains('rme') || subject.contains('religious')) {
      setState(() {
        _selectedSubject = 'Religious and Moral Education';
        _applyFilters();
      });
    }
  }

  // Retry methods for error recovery
  void _retryLoadCollections() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    _loadCollections();
  }

  void _retryLoadSubjects() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    _loadSubjectCards();
  }

  // P2 Fix #8: Debounced search to prevent excessive filtering
  void _onSearchChanged(String query) {
    // Cancel existing timer
    _searchDebounceTimer?.cancel();
    
    // Start new timer (300ms delay)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 0; // reset to first page when filters change
      // Only show collections if a subject is selected
      if (_selectedSubject != 'All Subjects') {
        _filteredCollections = _collections.where((collection) {
          // Subject filter
          final subjectMatch = _formatSubjectName(collection.subject) == _selectedSubject;
          if (!subjectMatch) return false;
          // Question type filter (MCQ vs Theory)
          if (_selectedQuestionType != 'All Types') {
            final isMCQ = collection.questionType == QuestionType.multipleChoice;
            final isTheory = collection.questionType == QuestionType.essay;
            if (_selectedQuestionType == 'MCQ' && !isMCQ) return false;
            if (_selectedQuestionType == 'Theory' && !isTheory) return false;
          }
          // Topic filter
          if (_selectedTopic != 'All Topics') {
            bool hasCollectionTopic = collection.description == _selectedTopic;
            final collectionTopics = collection.questions.expand((q) => q.topics).toSet().toList();
            bool hasQuestionTopic = collectionTopics.contains(_selectedTopic);
            if (!hasCollectionTopic && !hasQuestionTopic) return false;
          }
          // Year filter
          if (_selectedYear != 'All Years') {
            if (collection.year != _selectedYear) return false;
          }
          // Search filter
          if (_searchController.text.isNotEmpty) {
            final search = _searchController.text.toLowerCase();
            final displayText = (collection.title.isNotEmpty ? collection.title : collection.displayName).toLowerCase();
            if (!displayText.contains(search)) return false;
          }
          return true;
        }).toList();
      } else {
        _filteredCollections = [];
      }
    });
  }

  String _formatSubjectName(Subject subject) {
    switch (subject) {
      case Subject.mathematics: return 'Mathematics';
      case Subject.english: return 'English';
      case Subject.integratedScience: return 'Integrated Science';
      case Subject.socialStudies: return 'Social Studies';
      case Subject.ga: return 'Ga';
      case Subject.asanteTwi: return 'Asante Twi';
      case Subject.french: return 'French';
      case Subject.ict: return 'ICT';
      case Subject.religiousMoralEducation: return 'Religious and Moral Education';
      case Subject.creativeArts: return 'Creative Arts';
      case Subject.careerTechnology: return 'Career Technology';
      case Subject.trivia: return 'Trivia';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD62828)))
          : _hasError
              ? _buildErrorState(isSmallScreen)
              : _isViewingCollections
                  ? _buildCollectionView(isSmallScreen)
                  : CustomScrollView(
                      slivers: [
                        // Subject Cards only
                        SliverToBoxAdapter(
                          child: _buildSubjectCards(isSmallScreen),
                        ),
                      ],
                    ),
    );
  }
  
  Widget _buildErrorState(bool isSmallScreen) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 24 : 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isSmallScreen ? 64 : 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _retryLoadCollections,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 32,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCollectionView(bool isSmallScreen) {
    return CustomScrollView(
      slivers: [
        // Header with back button
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 20,
              vertical: isSmallScreen ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _closeCollectionView,
                  icon: const Icon(Icons.arrow_back),
                  color: const Color(0xFF1A1E3F),
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  constraints: BoxConstraints(
                    minWidth: isSmallScreen ? 40 : 48,
                    minHeight: isSmallScreen ? 40 : 48,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _viewingSubjectName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isSmallScreen ? 18 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Search & Filter card
        SliverToBoxAdapter(
          child: _buildFilters(isSmallScreen),
        ),
        // Collections (combined list)
        SliverToBoxAdapter(
          child: _buildUnifiedCollections(isSmallScreen),
        ),
      ],
    );
  }

  Widget _buildFilters(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
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
          // Title
          Text(
            'Search & Filter',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
            decoration: InputDecoration(
              hintText: 'Search collections...',
              hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFFF8FAFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          // Filter dropdowns
          if (isSmallScreen)
            Column(
              children: [
                _buildFilterDropdown('Question Type', _selectedQuestionType, ['All Types', 'MCQ', 'Theory'], (value) {
                  setState(() => _selectedQuestionType = value!);
                  _saveFilters();
                  _applyFilters();
                }),
                const SizedBox(height: 8),
                _buildFilterDropdown('Subject', _selectedSubject, _getSubjectOptions(), (value) {
                  setState(() {
                    _selectedSubject = value!;
                    _selectedTopic = 'All Topics'; // Reset topic when subject changes
                  });
                  _saveFilters();
                  _applyFilters();
                }),
                const SizedBox(height: 8),
                _buildFilterDropdown('Topic', _selectedTopic, _getTopicOptions(), (value) {
                  setState(() => _selectedTopic = value!);
                  _saveFilters();
                  _applyFilters();
                }),
                const SizedBox(height: 8),
                _buildFilterDropdown('Year', _selectedYear, _getYearOptions(), (value) {
                  setState(() => _selectedYear = value!);
                  _saveFilters();
                  _applyFilters();
                }),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown('Question Type', _selectedQuestionType, ['All Types', 'MCQ', 'Theory'], (value) {
                        setState(() => _selectedQuestionType = value!);
                        _saveFilters();
                        _applyFilters();
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown('Subject', _selectedSubject, _getSubjectOptions(), (value) {
                        setState(() {
                          _selectedSubject = value!;
                          _selectedTopic = 'All Topics'; // Reset topic when subject changes
                        });
                        _saveFilters();
                        _applyFilters();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown('Topic', _selectedTopic, _getTopicOptions(), (value) {
                        setState(() => _selectedTopic = value!);
                        _saveFilters();
                        _applyFilters();
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown('Year', _selectedYear, _getYearOptions(), (value) {
                        setState(() => _selectedYear = value!);
                        _saveFilters();
                        _applyFilters();
                      }),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found ${_filteredCollections.length} quiz sets',
                style: GoogleFonts.montserrat(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchController.text.isNotEmpty || 
                  _selectedQuestionType != 'All Types' || 
                  _selectedSubject != 'All Subjects' || 
                  _selectedTopic != 'All Topics' ||
                  _selectedYear != 'All Years')
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedQuestionType = 'All Types';
                      _selectedSubject = 'All Subjects';
                      _selectedTopic = 'All Topics';
                      _selectedYear = 'All Years';
                    });
                    _saveFilters();
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD62828),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF8FAFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownColor: Colors.white,
      style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
      items: options.map((option) {
        return DropdownMenuItem(value: option, child: Text(option));
      }).toList(),
    );
  }

  List<String> _getSubjectOptions() {
    final subjects = _collections.map((c) => _formatSubjectName(c.subject)).toSet().toList();
    subjects.sort();
    return ['All Subjects', ...subjects];
  }

  List<String> _getYearOptions() {
    final years = _collections.map((c) => c.year).toSet().toList();
    years.sort((a, b) => b.compareTo(a)); // Most recent first
    return ['All Years', ...years];
  }

  List<String> _getTopicOptions() {
    // Get topics from collections matching current subject filter
    final relevantCollections = _selectedSubject == 'All Subjects'
        ? _collections
        : _collections.where((c) => _formatSubjectName(c.subject) == _selectedSubject).toList();
    
    final topicSet = <String>{};
    
    // Add collection-level topics (from saved collections like ICT/RME topics)
    for (final collection in relevantCollections) {
      if (collection.description != null && collection.description!.isNotEmpty) {
        // Skip generic descriptions, only add actual topic names
        final desc = collection.description!;
        if (!desc.startsWith('Practice') && desc.length > 5) {
          topicSet.add(desc);
        }
      }
    }
    
    // Also add question-level topics
    final questionTopics = relevantCollections
        .expand((c) => c.questions)
        .expand((q) => q.topics)
        .where((topic) {
          // Filter out years (4 digits), exam types (BECE, WASSCE), and subject names
          if (RegExp(r'^\d{4}$').hasMatch(topic)) return false; // Years
          if (topic.toUpperCase() == 'BECE' || topic.toUpperCase() == 'WASSCE') return false;
          if (topic.toUpperCase() == 'ICT' || topic == 'Information And Communication Technology') return false;
          return true;
        });
    
    topicSet.addAll(questionTopics);
    
    final topics = topicSet.toList();
    topics.sort();
    return ['All Topics', ...topics];
  }

  Widget _buildUnifiedCollections(bool isSmallScreen) {
    // Sort collections: MCQ first, then Theory, then Topics
    final sortedCollections = List<QuestionCollection>.from(_filteredCollections);
    sortedCollections.sort((a, b) {
      // Priority order: MCQ (multipleChoice) -> Theory (essay) -> Topics (All Years)
      int getTypeOrder(QuestionCollection c) {
        if (c.questionType == QuestionType.multipleChoice && c.year != 'All Years') return 0; // MCQ
        if (c.questionType == QuestionType.essay && c.year != 'All Years') return 1; // Theory
        return 2; // Topics
      }
      
      final typeCompare = getTypeOrder(a).compareTo(getTypeOrder(b));
      if (typeCompare != 0) return typeCompare;
      
      // Within same type, sort by year (most recent first)
      return b.year.compareTo(a.year);
    });
    
    // Pagination: 12 items per page
    final totalPages = (sortedCollections.length / _itemsPerPage).ceil();
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, sortedCollections.length);
    final paginatedCollections = sortedCollections.sublist(startIndex, endIndex);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collections Grid
          isSmallScreen
              ? Column(
                  children: paginatedCollections.map((collection) {
                    return _buildCollectionCard(collection, isSmallScreen);
                  }).toList(),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: paginatedCollections.length,
                  itemBuilder: (context, index) {
                    return _buildCollectionCard(paginatedCollections[index], isSmallScreen);
                  },
                ),
          
          // Pagination Controls
          if (totalPages > 1) ...[
            SizedBox(height: isSmallScreen ? 20 : 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  color: const Color(0xFF1A1E3F),
                  disabledColor: Colors.grey[300],
                  iconSize: isSmallScreen ? 20 : 24,
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF1A1E3F),
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                IconButton(
                  onPressed: _currentPage < totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: const Color(0xFF1A1E3F),
                  disabledColor: Colors.grey[300],
                  iconSize: isSmallScreen ? 20 : 24,
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionCard(QuestionCollection collection, bool isSmallScreen) {
    return Container(
      margin: isSmallScreen ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 12,
                    vertical: isSmallScreen ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                  ),
                  child: Text(
                    collection.examType.name.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1A1E3F).withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    collection.year,
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF1A1E3F),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              collection.title.isNotEmpty ? collection.title : collection.displayName,
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFF1A1E3F),
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${collection.questionCount} Questions',
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Randomize Toggle and Start Quiz Button - responsive layout
            isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Randomize Toggle (Mobile - full width)
                      Row(
                        children: [
                          Switch(
                            value: _randomizeQuestions,
                            onChanged: (value) => setState(() => _randomizeQuestions = value),
                            activeColor: const Color(0xFFD62828),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Randomize Questions',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: const Color(0xFF1A1E3F),
                                  ),
                                ),
                                Text(
                                  'Questions will appear in random order',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Question Count Selector (Mobile - full width)
                      _buildQuestionCountSelector(collection, isSmallScreen),
                      const SizedBox(height: 12),
                      // Start Quiz Button (Mobile - full width)
                      _buildActionButton(
                        icon: collection.questionType == QuestionType.essay ? Icons.edit_note : Icons.play_arrow,
                        label: collection.questionType == QuestionType.essay ? 'Start' : 'Start Quiz',
                        onPressed: () => _startQuiz(collection),
                        isPrimary: true,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // Randomize Questions Toggle (Desktop - Left side)
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Switch(
                                  value: _randomizeQuestions,
                                  onChanged: (value) => setState(() => _randomizeQuestions = value),
                                  activeColor: const Color(0xFFD62828),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Randomize',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: const Color(0xFF1A1E3F),
                                        ),
                                      ),
                                      Text(
                                        'Random order',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Start Quiz Button (Desktop - Right side, 20% larger than before)
                          Flexible(
                            child: FractionallySizedBox(
                              widthFactor: 0.84, // 20% increase from 0.7
                              child: _buildActionButton(
                                icon: collection.questionType == QuestionType.essay ? Icons.edit_note : Icons.play_arrow,
                                label: collection.questionType == QuestionType.essay ? 'Start' : 'Start Quiz',
                                onPressed: () => _startQuiz(collection),
                                isPrimary: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Question Count Selector (Desktop - full width below)
                      _buildQuestionCountSelector(collection, isSmallScreen),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF2ECC71) : const Color(0xFF1A1E3F), // Uriel Blue
        foregroundColor: Colors.white, // White text for both buttons
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildQuestionCountSelector(QuestionCollection collection, bool isSmallScreen) {
    // Get available counts based on collection size
    final availableCounts = [10, 20, 40].where((count) => count <= collection.questionCount).toList();
    
    // If collection has fewer questions, add small count
    if (collection.questionCount < 10) {
      availableCounts.clear();
      availableCounts.add(collection.questionCount);
    }
    
    // Add "All" as last option if collection has more than 40 questions
    final showAllOption = collection.questionCount > 40;
    
    // Get current selection or default to first available count
    final currentCount = _selectedQuestionCounts[collection.id] ?? availableCounts.first;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A1E3F).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_list_numbered, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Questions:',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ...availableCounts.map((count) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildCountChip(
                    label: count.toString(),
                    isSelected: currentCount == count,
                    onTap: () {
                      setState(() {
                        _selectedQuestionCounts[collection.id] = count;
                      });
                    },
                  ),
                )),
                if (showAllOption)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildCountChip(
                      label: 'All',
                      isSelected: currentCount == collection.questionCount,
                      onTap: () {
                        setState(() {
                          _selectedQuestionCounts[collection.id] = collection.questionCount;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD62828) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFD62828) : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF1A1E3F),
          ),
        ),
      ),
    );
  }

  void _startQuiz(QuestionCollection collection) {
    // Get selected question count or default
    final selectedCount = _selectedQuestionCounts[collection.id] ?? 
        ([10, 20, 40].where((c) => c <= collection.questionCount).firstOrNull ?? collection.questionCount);
    // Check if this is a theory/essay collection
    if (collection.questionType == QuestionType.essay) {
      // Route to theory questions list
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoryYearQuestionsList(
            subject: _formatSubjectName(collection.subject),
            year: int.parse(collection.year),
          ),
        ),
      );
    } else {
      // Always fetch questions from Firestore when starting quiz
      if (collection.questionIds != null && collection.questionIds!.isNotEmpty) {
        List<String> questionIds = List<String>.from(collection.questionIds!);
        if (_randomizeQuestions) {
          questionIds.shuffle();
        }
        if (selectedCount < questionIds.length) {
          questionIds = questionIds.take(selectedCount).toList();
        }
        // Show loading indicator while fetching questions
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
        _questionService.getQuestionsByIds(questionIds).then((questions) {
          Navigator.pop(context); // Remove loading dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizTakerPage(
                subject: _formatSubjectName(collection.subject),
                examType: collection.examType.name.toUpperCase(),
                level: 'JHS 3',
                questionCount: questions.length,
                randomizeQuestions: false,
                preloadedQuestions: questions,
              ),
            ),
          );
        });
      }
    }
  }
}
