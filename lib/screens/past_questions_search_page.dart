import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ...existing imports...
import '../models/question_model.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import 'quiz_setup_page.dart';
import 'question_detail_page.dart';

class PastQuestionsSearchPage extends StatefulWidget {
  /// Optional initial subject display name (e.g. 'RME' or 'Religious And Moral Education')
  final String? initialSubject;

  const PastQuestionsSearchPage({Key? key, this.initialSubject}) : super(key: key);

  @override
  State<PastQuestionsSearchPage> createState() => _PastQuestionsSearchPageState();
}

class _PastQuestionsSearchPageState extends State<PastQuestionsSearchPage> 
    with SingleTickerProviderStateMixin {
  final QuestionService _questionService = QuestionService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Filter Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  String _selectedExamType = 'BECE';
  String _selectedSubject = 'All Subjects';
  String _selectedYear = 'All Years';
  String _selectedQuestionType = 'All Types'; // New: MCQ/Theory filter
  
  // State Management
  List<Question> _questions = [];
  List<Question> _filteredQuestions = [];
  bool _isLoading = false;
  bool _isGridView = false;
  String _sortBy = 'Most Recent';
  int _currentPage = 1;
  final int _questionsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadInitialData();
    _animationController.forward();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🚀 Loading questions from database...');
      
      // Load database questions with timeout
      final questionsTask = _questionService.getQuestions().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Question>[],
      );
      
      // Load RME questions specifically for debugging
      final rmeQuestionsTask = _questionService.getRMEQuestions().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Question>[],
      );
      
      // Load storage questions (RME and others) with timeout  
      final storageQuestionsTask = StorageService.getAllPastQuestions().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <PastQuestion>[],
      );
      
      final questions = await questionsTask;
      final rmeQuestions = await rmeQuestionsTask;
      final storageQuestions = await storageQuestionsTask;
      
      debugPrint('📊 Loaded ${questions.length} total questions from database');
      debugPrint('📚 Loaded ${rmeQuestions.length} RME questions specifically');
      debugPrint('📁 Loaded ${storageQuestions.length} storage questions');
      
      // Merge database questions with RME questions and storage questions so searches can find all
      final mergedQuestions = <Question>[];

      // Add database questions
      mergedQuestions.addAll(questions);

      // Add RME questions from Firestore (avoid duplicates)
      for (final q in rmeQuestions) {
        if (!mergedQuestions.any((existing) => existing.id == q.id)) {
          mergedQuestions.add(q);
        }
      }

      // Convert storage PastQuestion entries into Question-lite objects for display/search
      for (final p in storageQuestions) {
        // Convert storage PastQuestion to an in-memory Question for search/display
        final storageAsQuestion = Question(
          id: 'storage_${p.id}',
          questionText: p.title,
          type: QuestionType.essay,
          subject: Subject.religiousMoralEducation,
          examType: ExamType.bece,
          year: p.year,
          section: 'A',
          questionNumber: 0,
          options: [],
          correctAnswer: '',
          explanation: '',
          marks: 0,
          difficulty: 'medium',
          topics: [p.subject],
          createdAt: p.uploadTime,
          createdBy: 'storage',
          isActive: true,
        );

        if (!mergedQuestions.any((existing) => existing.id == storageAsQuestion.id)) {
          mergedQuestions.add(storageAsQuestion);
        }
      }

      // Filter to show only BECE and WASSCE questions (exclude trivia, mock, practice)
      final beceWasscceQuestions = mergedQuestions
          .where((q) => 
            q.examType == ExamType.bece || 
            q.examType == ExamType.wassce
          )
          .toList();

      setState(() {
        _questions = beceWasscceQuestions;
        _filteredQuestions = beceWasscceQuestions;
        _isLoading = false;
      });
      // If the widget was constructed with an initial subject, apply it
      if (widget.initialSubject != null && widget.initialSubject!.isNotEmpty) {
        setState(() {
          _selectedSubject = widget.initialSubject!;
        });
        _applyFilters();
      }
    } catch (e) {
      // Silent fallback - don't show error to user
      debugPrint('❌ Questions loading error (handled gracefully): $e');
      setState(() {
        _questions = [];
        _filteredQuestions = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() => _isLoading = true);
    
    List<Question> filtered = List.from(_questions);
    
    // Questions are already filtered to BECE/WASSCE only in _loadInitialData
    // Apply exam type filter (always applied since no "All Types" option)
    ExamType examType = ExamType.values.firstWhere(
      (e) => e.name.toUpperCase() == _selectedExamType.toUpperCase(),
    );
    filtered = filtered.where((q) => q.examType == examType).toList();
    
    if (_selectedSubject != 'All Subjects') {
      Subject? subject = _getSubjectFromDisplayName(_selectedSubject);
      if (subject != null) {
        filtered = filtered.where((q) => q.subject == subject).toList();
      }
    }
    
    if (_selectedYear != 'All Years') {
      filtered = filtered.where((q) => q.year == _selectedYear).toList();
    }
    
    // Apply question type filter (MCQ/Theory)
    if (_selectedQuestionType != 'All Types') {
      if (_selectedQuestionType == 'MCQ') {
        filtered = filtered.where((q) => q.type == QuestionType.multipleChoice).toList();
      } else if (_selectedQuestionType == 'Theory') {
        filtered = filtered.where((q) => q.type == QuestionType.essay).toList();
      }
    }
    
    // Apply topic search
    if (_topicController.text.isNotEmpty) {
      String topicSearch = _topicController.text.toLowerCase();
      filtered = filtered.where((q) => 
        q.topics.any((topic) => topic.toLowerCase().contains(topicSearch))
      ).toList();
    }
    
    // Apply search text
    if (_searchController.text.isNotEmpty) {
      String searchTerm = _searchController.text.toLowerCase();

      // Recognize common RME search terms (allow 'rme' abbreviation)
      final isRmeQuery = searchTerm.contains('rme') || searchTerm.contains('religious');

      filtered = filtered.where((q) {
        // Search in question text
        bool matchesQuestion = q.questionText.toLowerCase().contains(searchTerm);

        // Search in subject (both enum name and display name)
        bool matchesSubject = q.subject.name.toLowerCase().contains(searchTerm) ||
            _mapSubjectToString(q.subject).toLowerCase().contains(searchTerm) ||
            // Explicit RME handling: if user typed 'rme' match RME subject
            (isRmeQuery && q.subject == Subject.religiousMoralEducation);

        // Search in year
        bool matchesYear = q.year.toLowerCase().contains(searchTerm);

        // Search in exam type
        bool matchesExamType = q.examType.name.toLowerCase().contains(searchTerm) ||
            _mapExamTypeToString(q.examType).toLowerCase().contains(searchTerm);

        // Search in topics (also check for rme abbreviation)
        bool matchesTopics = q.topics.any((topic) => topic.toLowerCase().contains(searchTerm)) ||
            (isRmeQuery && q.topics.any((topic) => topic.toLowerCase().contains('rme')));

        return matchesQuestion || matchesSubject || matchesYear || matchesExamType || matchesTopics;
      }).toList();
    }
    
    // Apply sorting
    _applySorting(filtered);
    
    setState(() {
      _filteredQuestions = filtered;
      _currentPage = 1;
      _isLoading = false;
    });
  }

  void _applySorting(List<Question> questions) {
    switch (_sortBy) {
      case 'Most Recent':
        questions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Oldest First':
        questions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'By Year (Newest)':
        questions.sort((a, b) {
          // Handle year comparison safely (year is stored as String)
          final aYear = int.tryParse(a.year) ?? 0;
          final bYear = int.tryParse(b.year) ?? 0;
          return bYear.compareTo(aYear);
        });
        break;
      case 'By Difficulty':
        questions.sort((a, b) {
          // Handle null difficulty values
          final aDiff = a.difficulty;
          final bDiff = b.difficulty;
          if (aDiff == bDiff) return 0;
          if (aDiff == 'hard') return -1;
          if (bDiff == 'hard') return 1;
          if (aDiff == 'medium') return -1;
          if (bDiff == 'medium') return 1;
          return 0;
        });
        break;
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedExamType = 'BECE';
      _selectedSubject = 'All Subjects';
      _selectedYear = 'All Years';
      _searchController.clear();
      _filteredQuestions = _questions;
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Page Header
            SliverAppBar(
              floating: true,
              pinned: true,
              automaticallyImplyLeading: false,
              expandedHeight: 100,
              backgroundColor: Colors.white,
              title: Text(
                'Past Questions',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2ECC71),
                ),
              ),
              centerTitle: false,
              titleSpacing: isSmallScreen ? 16 : 24,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: EdgeInsets.only(
                    left: isSmallScreen ? 16 : 24,
                    right: isSmallScreen ? 16 : 24,
                    bottom: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(height: 40), // Space for title
                      Text(
                        'BECE Questions • WASSCE Questions • Mock Tests',
                        style: GoogleFonts.montserrat(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Search and Filters
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: _buildSearchAndFilters(isSmallScreen),
              ),
            ),
            
            // Quick Actions
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                ),
                child: _buildQuickActions(isSmallScreen),
              ),
            ),
            
            // Results Header
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: _buildResultsHeader(isSmallScreen),
              ),
            ),
            
            // Results Content
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                ),
                child: _isLoading 
                    ? _buildLoadingState()
                    : _filteredQuestions.isEmpty 
                        ? _buildEmptyState()
                        : _buildResultsList(isSmallScreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isSmallScreen) {
    return Container(
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
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search questions, topics, keywords...',
                hintStyle: GoogleFonts.montserrat(
                  color: Colors.grey[600],
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFD62828)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              onChanged: (value) => setState(() {}),
              onSubmitted: (value) => _applyFilters(),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Filter Chips - Mobile Optimized
          if (isSmallScreen) ...[
            _buildMobileFilters(),
          ] else ...[
            _buildDesktopFilters(),
          ],
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    'Reset',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search, color: Colors.white, size: 18),
                  label: Text(
                    'Search Questions',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71), // Pastel Navy Blue
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Additional Filters Row: Question Type and Topic
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildFilterChip(
                  'Question Type',
                  _selectedQuestionType,
                  ['All Types', 'MCQ', 'Theory'],
                  (value) => setState(() => _selectedQuestionType = value!),
                  Icons.quiz,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    labelText: 'Topic (Optional)',
                    labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                    hintText: 'e.g., algebra, photosynthesis',
                    hintStyle: GoogleFonts.montserrat(fontSize: 13),
                    prefixIcon: Icon(Icons.topic, color: Colors.grey[600]),
                    suffixIcon: _topicController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _topicController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFilterChip(
                'Exam Type',
                _selectedExamType,
                ['BECE', 'WASSCE'],
                (value) => setState(() => _selectedExamType = value!),
                Icons.school,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterChip(
                'Subject',
                _selectedSubject,
                ['All Subjects', 'Mathematics', 'English', 'Science', 'RME'],
                (value) => setState(() => _selectedSubject = value!),
                Icons.book,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFilterChip(
                'Year',
                _selectedYear,
                ['All Years', '2024', '2023', '2022', '2021', '2020', '2019', '2018', '2017', '2016', '2015', '2014', '2013', '2012', '2011', '2010', '2009', '2008', '2007', '2006', '2005', '2004', '2003', '2002', '2001', '2000', '1999', '1998', '1997', '1996', '1995', '1994', '1993', '1992', '1991', '1990'],
                (value) => setState(() => _selectedYear = value!),
                Icons.calendar_today,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterChip(
                'Type',
                _selectedQuestionType,
                ['All Types', 'MCQ', 'Theory'],
                (value) => setState(() => _selectedQuestionType = value!),
                Icons.quiz,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Topic search field
        TextField(
          controller: _topicController,
          decoration: InputDecoration(
            labelText: 'Search by Topic',
            labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
            hintText: 'e.g., algebra, photosynthesis',
            hintStyle: GoogleFonts.montserrat(fontSize: 13),
            prefixIcon: Icon(Icons.topic, color: Colors.grey[600]),
            suffixIcon: _topicController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _topicController.clear();
                      _applyFilters();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onSubmitted: (_) => _applyFilters(),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterChip(
            'Exam Type',
            _selectedExamType,
            ['BECE', 'WASSCE'],
            (value) => setState(() => _selectedExamType = value!),
            Icons.school,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterChip(
            'Subject',
            _selectedSubject,
            ['All Subjects', 'Mathematics', 'English', 'Science', 'RME'],
            (value) => setState(() => _selectedSubject = value!),
            Icons.book,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterChip(
            'Year',
            _selectedYear,
            ['All Years', '2024', '2023', '2022', '2021', '2020', '2019', '2018', '2017', '2016', '2015', '2014', '2013', '2012', '2011', '2010', '2009', '2008', '2007', '2006', '2005', '2004', '2003', '2002', '2001', '2000', '1999', '1998', '1997', '1996', '1995', '1994', '1993', '1992', '1991', '1990'],
            (value) => setState(() => _selectedYear = value!),
            Icons.calendar_today,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterChip(
            'Type',
            _selectedQuestionType,
            ['All Types', 'MCQ', 'Theory'],
            (value) => setState(() => _selectedQuestionType = value!),
            Icons.quiz,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSortChip(),
        ),
      ],
    );
  }
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterChip(
            'Year',
            _selectedYear,
            ['All Years', '2024', '2023', '2022', '2021', '2020', '2019', '2018', '2017', '2016', '2015', '2014', '2013', '2012', '2011', '2010', '2009', '2008', '2007', '2006', '2005', '2004', '2003', '2002', '2001', '2000', '1999', '1998', '1997', '1996', '1995', '1994', '1993', '1992', '1991', '1990'],
            (value) => setState(() => _selectedYear = value!),
            Icons.calendar_today,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSortChip(),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFFD62828)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSortChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
          items: [
            'Most Recent',
            'Oldest First',
            'By Year (Newest)',
            'By Difficulty',
          ].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 16, color: Color(0xFFD62828)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() => _sortBy = newValue!);
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isSmallScreen) {
    final quickActions = [
      {'label': 'Start Quiz', 'icon': Icons.play_circle_fill, 'color': const Color(0xFFD62828), 'action': 'quiz'},
      {'label': 'BECE Questions', 'icon': Icons.school, 'color': const Color(0xFF2E7D32), 'action': 'bece'},
      {'label': 'WASSCE Questions', 'icon': Icons.workspace_premium, 'color': const Color(0xFF1565C0), 'action': 'wassce'},
      {'label': 'Mock Tests', 'icon': Icons.timer, 'color': const Color(0xFFE65100), 'action': 'mock'},
      {'label': 'Recent Questions', 'icon': Icons.access_time, 'color': const Color(0xFF7B1FA2), 'action': 'recent'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: quickActions.map((action) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _applyQuickAction(action['action'] as String),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  color: action['action'] == 'quiz' 
                      ? (action['color'] as Color).withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: action['color'] as Color),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      action['icon'] as IconData,
                      size: isSmallScreen ? 16 : 18,
                      color: action['color'] as Color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      action['label'] as String,
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: action['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _applyQuickAction(String actionType) {
    switch (actionType) {
      case 'quiz':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const QuizSetupPage(),
          ),
        );
        break;
      case 'bece':
        setState(() {
          _selectedExamType = 'BECE';
        });
        _applyFilters();
        break;
      case 'wassce':
        setState(() {
          _selectedExamType = 'WASSCE';
        });
        _applyFilters();
        break;
      case 'mock':
        setState(() {
          _selectedExamType = 'Mock';
        });
        _applyFilters();
        break;
      case 'recent':
        setState(() {
          _sortBy = 'Most Recent';
        });
        _applyFilters();
        break;
    }
  }

  Widget _buildResultsHeader(bool isSmallScreen) {
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${_filteredQuestions.length} questions',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2ECC71),
                  ),
                ),
                if (_filteredQuestions.isNotEmpty)
                  Text(
                    'Showing ${_getDisplayedQuestionsCount()} results',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // View Toggle
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _isGridView = false),
                  icon: Icon(
                    Icons.view_list,
                    color: !_isGridView ? const Color(0xFFD62828) : Colors.grey,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _isGridView = true),
                  icon: Icon(
                    Icons.view_module,
                    color: _isGridView ? const Color(0xFFD62828) : Colors.grey,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getDisplayedQuestionsCount() {
    final totalFiltered = _filteredQuestions.length;
    final endIndex = _currentPage * _questionsPerPage;
    return endIndex > totalFiltered ? totalFiltered : endIndex;
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD62828)),
            const SizedBox(height: 16),
            Text(
              'Loading questions...',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFD62828).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 48,
                color: Color(0xFFD62828),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No questions found',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2ECC71),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71), // Pastel Navy Blue
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(bool isSmallScreen) {
    final startIndex = (_currentPage - 1) * _questionsPerPage;
    final endIndex = startIndex + _questionsPerPage;
    final displayQuestions = _filteredQuestions.take(endIndex).skip(startIndex).toList();

    return Column(
      children: [
        _isGridView 
            ? _buildGridView(displayQuestions, isSmallScreen)
            : _buildListView(displayQuestions, isSmallScreen),
        if (_filteredQuestions.length > _questionsPerPage)
          _buildPagination(),
        const SizedBox(height: 24), // Bottom padding
      ],
    );
  }

  Widget _buildListView(List<Question> questions, bool isSmallScreen) {
    return Column(
      children: questions.map((question) => _buildQuestionCard(question, isSmallScreen)).toList(),
    );
  }

  Widget _buildGridView(List<Question> questions, bool isSmallScreen) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 1 : 2,
        childAspectRatio: isSmallScreen ? 2.5 : 1.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return _buildQuestionGridCard(question, isSmallScreen);
      },
    );
  }

  Widget _buildQuestionCard(Question question, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _viewQuestion(question),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSmallScreen 
                ? _buildMobileQuestionCard(question)
                : _buildDesktopQuestionCard(question),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileQuestionCard(Question question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getSubjectColor(question.subject),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${question.questionNumber}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSubjectName(question.subject),
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2ECC71),
                    ),
                  ),
                  Text(
                    '${question.examType.name.toUpperCase()} ${question.year}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleBookmark(question),
              icon: Icon(
                Icons.bookmark_border,
                color: Colors.grey[400],
                size: 20,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Question Preview
        Text(
          question.questionText.length > 120
              ? '${question.questionText.substring(0, 120)}...'
              : question.questionText,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: const Color(0xFF2ECC71),
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 12),
        
        // Badges
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildSmallBadge(question.type.name, Colors.orange),
            _buildDifficultyBadge(question.difficulty),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _startQuizWithQuestion(question),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  'Start Quiz',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71), // Pastel Navy Blue
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5), // Pastel Green outline
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _viewQuestion(question),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD62828),
                  side: const BorderSide(color: Color(0xFFD62828)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'View',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopQuestionCard(Question question) {
    return Row(
      children: [
        // Left Section
        SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getSubjectColor(question.subject),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${question.questionNumber}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => _toggleBookmark(question),
                icon: Icon(
                  Icons.bookmark_border,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Main Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Preview
              Text(
                question.questionText.length > 100
                    ? '${question.questionText.substring(0, 100)}...'
                    : question.questionText,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2ECC71),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Metadata Row
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildBadge(question.examType.name.toUpperCase(), _getExamTypeColor(question.examType)),
                  _buildBadge(question.year, Colors.blue),
                  _buildBadge(_getSubjectName(question.subject), _getSubjectColor(question.subject)),
                  _buildBadge(question.type.name, Colors.orange),
                  _buildDifficultyBadge(question.difficulty),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Right Section - Actions
        Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => _startQuizWithQuestion(question),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Start Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71), // Pastel Navy Blue
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _viewQuestion(question),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD62828),
                side: const BorderSide(color: Color(0xFFD62828)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionGridCard(Question question, bool isSmallScreen) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _viewQuestion(question),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getSubjectColor(question.subject),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${question.questionNumber}',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleBookmark(question),
                    icon: Icon(
                      Icons.bookmark_border,
                      color: Colors.grey[400],
                      size: 18,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Question Preview
              Expanded(
                child: Text(
                  question.questionText.length > 80
                      ? '${question.questionText.substring(0, 80)}...'
                      : question.questionText,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2ECC71),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Badges
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildSmallBadge(question.examType.name.toUpperCase(), _getExamTypeColor(question.examType)),
                  _buildSmallBadge(question.year, Colors.blue),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _viewQuestion(question),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71), // Pastel Navy Blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'View',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _practiceQuestion(question),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD62828),
                        side: const BorderSide(color: Color(0xFFD62828)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Practice',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    int stars;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        color = Colors.green;
        stars = 1;
        break;
      case 'medium':
        color = Colors.orange;
        stars = 2;
        break;
      case 'hard':
        color = Colors.red;
        stars = 3;
        break;
      default:
        color = Colors.grey;
        stars = 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(3, (index) {
            return Icon(
              index < stars ? Icons.star : Icons.star_border,
              size: 12,
              color: color,
            );
          }),
          const SizedBox(width: 4),
          Text(
            difficulty,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_filteredQuestions.length / _questionsPerPage).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          
          ...List.generate(totalPages, (index) {
            final pageNumber = index + 1;
            final isSelected = pageNumber == _currentPage;
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() => _currentPage = pageNumber),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFD62828) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD62828) : Colors.grey[300]!,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$pageNumber',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          
          IconButton(
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // Helper Methods
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
      default:
        return const Color(0xFF616161);
    }
  }

  Color _getExamTypeColor(ExamType examType) {
    switch (examType) {
      case ExamType.bece:
        return const Color(0xFF2E7D32);
      case ExamType.wassce:
        return const Color(0xFF1565C0);
      case ExamType.mock:
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF616161);
    }
  }

  String _getSubjectName(Subject subject) {
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
      default:
        return subject.name;
    }
  }

  // Action Methods
  void _viewQuestion(Question question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionDetailPage(question: question),
      ),
    );
  }

  void _startQuizWithQuestion(Question question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizSetupPage(
          preselectedSubject: _mapSubjectToString(question.subject),
          preselectedExamType: _mapExamTypeToString(question.examType),
          preselectedLevel: 'JHS 3',
          
        ),
      ),
    );
  }
  
  String _mapSubjectToString(Subject subject) {
    switch (subject) {
      case Subject.religiousMoralEducation:
        return 'Religious and Moral Education';
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English Language';
      case Subject.integratedScience:
        return 'Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.ict:
        return 'Information Technology';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.french:
        return 'French';
      case Subject.ga:
        return 'Ga';
      case Subject.asanteTwi:
        return 'Asante Twi';
      default:
        return 'Religious and Moral Education';
    }
  }
  
  String _mapExamTypeToString(ExamType examType) {
    switch (examType) {
      case ExamType.bece:
        return 'BECE';
      case ExamType.wassce:
        return 'WASSCE';
      case ExamType.mock:
        return 'Mock Exam';
      case ExamType.practice:
        return 'Practice Questions';
      default:
        return 'BECE';
    }
  }

  Subject? _getSubjectFromDisplayName(String displayName) {
    switch (displayName.toLowerCase()) {
      case 'mathematics':
        return Subject.mathematics;
      case 'english':
        return Subject.english;
      case 'science':
      case 'integrated science':
        return Subject.integratedScience;
      case 'rme':
      case 'religious and moral education':
        return Subject.religiousMoralEducation;
      case 'social studies':
        return Subject.socialStudies;
      case 'ga':
        return Subject.ga;
      case 'asante twi':
      case 'twi':
        return Subject.asanteTwi;
      case 'french':
        return Subject.french;
      case 'ict':
        return Subject.ict;
      case 'creative arts':
        return Subject.creativeArts;
      case 'career technology':
        return Subject.careerTechnology;
      case 'trivia':
        return Subject.trivia;
      default:
        return null;
    }
  }

  void _practiceQuestion(Question question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionDetailPage(question: question),
      ),
    );
  }

  void _toggleBookmark(Question question) {
    setState(() {
      // Toggle bookmark status
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _topicController.dispose();
    super.dispose();
  }
}
