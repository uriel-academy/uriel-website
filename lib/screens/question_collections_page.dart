import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../models/question_collection_model.dart';
import '../services/question_service.dart';
import 'quiz_taker_page.dart';
import 'theory_year_questions_list.dart';

// Model class for subject cards
class SubjectCard {
  final String name;
  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final int collectionCount;

  SubjectCard({
    required this.name,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.collectionCount,
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
  List<QuestionCollection> _loadedCollections = []; // For lazy loading
  bool _isLoading = false;
  bool _isLoadingMore = false; // For pagination loading
  bool _hasMoreCollections = true; // Track if more collections available
  bool _randomizeQuestions = false;
  // Map to track question count selection per collection
  final Map<String, int> _selectedQuestionCounts = {};
  // Pagination
  int _currentPage = 0;
  final int _pageSize = 12; // 12 collections per page
  
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
  
  // Pagination for collection view
  int _collectionPage = 0;
  final int _collectionsPerPage = 12;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
      _loadedCollections = allCollections;
      
      setState(() {
        _filteredCollections = [];
        _currentPage = 0;
        _isLoading = false;
        _hasMoreCollections = false;
      });
      
      _loadSubjectCards();
      
      if (widget.initialSubject != null) {
        _applyInitialSubjectFilter();
      }
      
    } catch (e) {
      debugPrint('❌ Error loading collections: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubjectCards() async {
    setState(() => _isLoadingSubjects = true);
    try {
      // Get subjects that have collections
      final subjectCounts = <String, int>{};

      for (final collection in _collections) {
        final subjectName = _getDisplayNameFromSubject(collection.subject);
        if (subjectName != null) {
          subjectCounts[subjectName] = (subjectCounts[subjectName] ?? 0) + 1;
        }
      }

      // Create subject cards
      final subjectCards = <SubjectCard>[];

      for (final entry in subjectCounts.entries) {
        final card = _createSubjectCard(entry.key, entry.value);
        if (card != null) {
          subjectCards.add(card);
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
      setState(() => _isLoadingSubjects = false);
    }
  }

  SubjectCard? _createSubjectCard(String subjectName, int collectionCount) {
    final config = _getSubjectCardConfig(subjectName);
    if (config == null) return null;

    return SubjectCard(
      name: subjectName,
      displayName: config['displayName'] as String,
      description: config['description'] as String,
      icon: config['icon'] as IconData,
      color: config['color'] as Color,
      gradient: [config['color'] as Color, (config['color'] as Color)],
      collectionCount: collectionCount,
    );
  }

  Map<String, dynamic>? _getSubjectCardConfig(String subjectName) {
    final configs = {
      'Mathematics': {
        'displayName': 'Mathematics',
        'description': 'Algebra, geometry, calculus, and mathematical problem-solving',
        'icon': Icons.dialpad, // Retro calculator keypad
        'color': const Color(0xFF2196F3),
      },
      'English': {
        'displayName': 'English Language',
        'description': 'Grammar, comprehension, literature, and language skills',
        'icon': Icons.article, // Classic document/paper icon
        'color': const Color(0xFF4CAF50),
      },
      'Integrated Science': {
        'displayName': 'Integrated Science',
        'description': 'Physics, chemistry, biology, and earth science',
        'icon': Icons.biotech, // Classic microscope/lab equipment
        'color': const Color(0xFFFF9800),
      },
      'Social Studies': {
        'displayName': 'Social Studies',
        'description': 'History, geography, citizenship, and social sciences',
        'icon': Icons.account_balance, // Classic government building
        'color': const Color(0xFF9C27B0),
      },
      'Religious and Moral Education': {
        'displayName': 'RME',
        'description': 'Religious studies, ethics, and moral education',
        'icon': Icons.auto_stories, // Open book - classic religious study icon
        'color': const Color(0xFF795548),
      },
      'Ga': {
        'displayName': 'Ga Language',
        'description': 'Ga language, literature, and cultural studies',
        'icon': Icons.speaker_notes, // Speech/communication icon
        'color': const Color(0xFF607D8B),
      },
      'Asante Twi': {
        'displayName': 'Asante Twi',
        'description': 'Twi language, literature, and cultural studies',
        'icon': Icons.chat_bubble_outline, // Classic chat/speech bubble
        'color': const Color(0xFF5D4037),
      },
      'French': {
        'displayName': 'French',
        'description': 'French language, grammar, and literature',
        'icon': Icons.import_contacts, // Classic textbook icon
        'color': const Color(0xFF3F51B5),
      },
      'ICT': {
        'displayName': 'Information Technology',
        'description': 'Computer science, programming, and digital skills',
        'icon': Icons.desktop_windows, // Retro desktop computer
        'color': const Color(0xFF009688),
      },
      'Creative Arts': {
        'displayName': 'Creative Arts',
        'description': 'Visual arts, music, dance, and creative expression',
        'icon': Icons.brush, // Classic paintbrush
        'color': const Color(0xFFE91E63),
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
      _collectionPage = 0;
      
      // Only show collections for selected subject
      final subjectCollections = _loadedCollections.where((collection) {
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
      _collectionPage = 0;
    });
  }

  Widget _buildSubjectCards(bool isSmallScreen) {
    if (_isLoadingSubjects || _subjectCards.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;

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
            child: Text(
              'Browse by Subject',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 22 : 32,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1F),
                letterSpacing: -0.5,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isSmallScreen ? 2 : (screenWidth < 1024 ? 3 : 4),
              crossAxisSpacing: isSmallScreen ? 12 : 20,
              mainAxisSpacing: isSmallScreen ? 12 : 20,
              childAspectRatio: isSmallScreen ? 0.95 : 1.0,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: isSmallScreen ? 12 : 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onSubjectCardTap(subjectCard),
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with subtle background
                Container(
                  width: isSmallScreen ? 56 : 72,
                  height: isSmallScreen ? 56 : 72,
                  decoration: BoxDecoration(
                    color: subjectCard.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 18),
                  ),
                  child: Icon(
                    subjectCard.icon,
                    size: isSmallScreen ? 28 : 36,
                    color: subjectCard.color,
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 12 : 20),
                
                // Subject Name
                Text(
                  subjectCard.displayName,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 15 : 19,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D1D1F),
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: isSmallScreen ? 6 : 8),
                
                // Collection count with minimal styling
                Text(
                  '${subjectCard.collectionCount} collections',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF86868B),
                    letterSpacing: -0.1,
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 12 : 16),
                
                // Minimalist arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: isSmallScreen ? 12 : 14,
                  color: subjectCard.color.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Load more collections when user clicks "Load More" button
  Future<void> _loadMoreCollections() async {
    if (_isLoadingMore || !_hasMoreCollections) return;

    setState(() => _isLoadingMore = true);

    // Simulate loading delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 500));

    final nextPage = _currentPage + 1;
    final startIndex = (_currentPage * _pageSize);
    final endIndex = (nextPage * _pageSize);

    final moreCollections = _collections.skip(startIndex).take(_pageSize).toList();

    if (moreCollections.isNotEmpty) {
      setState(() {
        _loadedCollections.addAll(moreCollections);
        _currentPage = nextPage;
        _hasMoreCollections = endIndex < _collections.length;
      });
      debugPrint('📄 Loaded page $_currentPage: ${moreCollections.length} more collections');
    }

    setState(() => _isLoadingMore = false);
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

  void _applyFilters() {
    setState(() {
      _currentPage = 0; // reset to first page when filters change
      _collectionPage = 0; // reset collection view page too
      // Only show collections if a subject is selected
      if (_selectedSubject != 'All Subjects') {
        _filteredCollections = _loadedCollections.where((collection) {
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
      backgroundColor: const Color(0xFFF5F5F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD62828)))
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
            onChanged: (_) => _applyFilters(),
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
                  _applyFilters();
                }),
                const SizedBox(height: 8),
                _buildFilterDropdown('Subject', _selectedSubject, _getSubjectOptions(), (value) {
                  setState(() {
                    _selectedSubject = value!;
                    _selectedTopic = 'All Topics'; // Reset topic when subject changes
                  });
                  _applyFilters();
                }),
                const SizedBox(height: 8),
                _buildFilterDropdown('Topic', _selectedTopic, _getTopicOptions(), (value) {
                  setState(() => _selectedTopic = value!);
                  _applyFilters();
                }),
                const SizedBox(height: 8),
                _buildFilterDropdown('Year', _selectedYear, _getYearOptions(), (value) {
                  setState(() => _selectedYear = value!);
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
                        _applyFilters();
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown('Year', _selectedYear, _getYearOptions(), (value) {
                        setState(() => _selectedYear = value!);
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
                'Found ${_filteredCollections.length} collections',
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No collections found',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFF1A1E3F),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsList(bool isSmallScreen) {
    // Group collections by type when a subject is selected
    if (_selectedSubject != 'All Subjects') {
      return _buildGroupedCollections(isSmallScreen);
    }
    
    // Original list view when no subject selected
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 8,
      ),
      child: Column(
        children: [
          // Collections grid / list
          isSmallScreen
              ? Column(
                  children: _filteredCollections.map((collection) {
                    return _buildCollectionCard(collection, isSmallScreen);
                  }).toList(),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 cards per line
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.1, // 15% height reduction (was 1.8)
                  ),
                  itemCount: _filteredCollections.length,
                  itemBuilder: (context, index) {
                    return _buildCollectionCard(_filteredCollections[index], isSmallScreen);
                  },
                ),

          const SizedBox(height: 12),

          // Load More Button (if more collections available)
          if (_hasMoreCollections && !_isLoadingMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _loadMoreCollections,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Load More Collections'),
              ),
            ),

          // Loading indicator for background loading
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Color(0xFFD62828)),
            ),

          // Legacy pagination controls (for filtered results if needed)
          if (_filteredCollections.length > _pageSize && !_hasMoreCollections)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                const SizedBox(width: 12),
                Text('Page ${_currentPage + 1} of ${(_filteredCollections.length / _pageSize).ceil()}',
                     style: GoogleFonts.montserrat()),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _currentPage < (_filteredCollections.length / _pageSize).ceil() - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
    );
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
    final totalPages = (sortedCollections.length / _collectionsPerPage).ceil();
    final startIndex = _collectionPage * _collectionsPerPage;
    final endIndex = (startIndex + _collectionsPerPage).clamp(0, sortedCollections.length);
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
                  onPressed: _collectionPage > 0
                      ? () => setState(() => _collectionPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  color: const Color(0xFF1A1E3F),
                  disabledColor: Colors.grey[300],
                  iconSize: isSmallScreen ? 20 : 24,
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Text(
                  'Page ${_collectionPage + 1} of $totalPages',
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF1A1E3F),
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                IconButton(
                  onPressed: _collectionPage < totalPages - 1
                      ? () => setState(() => _collectionPage++)
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
  
  Widget _buildGroupedCollections(bool isSmallScreen) {
    // Separate collections into MCQ, Theory, and Topic
    final mcqCollections = _filteredCollections.where((c) {
      // Year collections with multipleChoice type
      return c.questionType == QuestionType.multipleChoice && 
             c.year != 'All Years';
    }).toList();
    
    final theoryCollections = _filteredCollections.where((c) {
      // Year collections with essay type
      return c.questionType == QuestionType.essay && 
             c.year != 'All Years';
    }).toList();
    
    final topicCollections = _filteredCollections.where((c) {
      // Topic collections (identified by year == 'All Years' or by having topic info)
      return c.year == 'All Years';
    }).toList();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MCQ Section
          if (mcqCollections.isNotEmpty) ...[
            _buildCollectionSection(
              'Multiple Choice Questions',
              mcqCollections,
              isSmallScreen,
              Icons.check_circle_outline,
              const Color(0xFF2ECC71),
            ),
            const SizedBox(height: 24),
          ],
          
          // Theory Section
          if (theoryCollections.isNotEmpty) ...[
            _buildCollectionSection(
              'Theory / Essay Questions',
              theoryCollections,
              isSmallScreen,
              Icons.edit_note,
              const Color(0xFFE67E22),
            ),
            const SizedBox(height: 24),
          ],
          
          // Topic Section
          if (topicCollections.isNotEmpty) ...[
            _buildCollectionSection(
              'Practice by Topic',
              topicCollections,
              isSmallScreen,
              Icons.topic,
              const Color(0xFF9B59B6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionSection(
    String title,
    List<QuestionCollection> collections,
    bool isSmallScreen,
    IconData icon,
    Color color,
  ) {
    // Pagination: 12 items per page
    final totalPages = (collections.length / _collectionsPerPage).ceil();
    final startIndex = _collectionPage * _collectionsPerPage;
    final endIndex = (startIndex + _collectionsPerPage).clamp(0, collections.length);
    final paginatedCollections = collections.sublist(startIndex, endIndex);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${collections.length}',
                style: GoogleFonts.montserrat(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _collectionPage > 0
                    ? () => setState(() => _collectionPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFF1A1E3F),
                disabledColor: Colors.grey[300],
              ),
              const SizedBox(width: 16),
              Text(
                'Page ${_collectionPage + 1} of $totalPages',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF1A1E3F),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _collectionPage < totalPages - 1
                    ? () => setState(() => _collectionPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFF1A1E3F),
                disabledColor: Colors.grey[300],
              ),
            ],
          ),
        ],
      ],
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
