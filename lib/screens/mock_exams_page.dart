import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mock_exam_model.dart';
import '../services/mock_exam_service.dart';

class MockExamsPage extends StatefulWidget {
  const MockExamsPage({super.key});

  @override
  State<MockExamsPage> createState() => _MockExamsPageState();
}

class _MockExamsPageState extends State<MockExamsPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  final MockExamService _mockExamService = MockExamService();
  final TextEditingController _searchController = TextEditingController();

  String selectedExamType = 'All';
  String selectedSubject = 'All';
  String selectedDifficulty = 'All';
  String selectedYear = 'All';
  String searchQuery = '';

  List<MockExam> allMockExams = [];
  List<MockExam> filteredMockExams = [];
  bool isLoading = true;

  final List<String> examTypes = ['All', 'BECE', 'WASSCE', 'NECO', 'Custom'];
  final List<String> subjects = [
    'All', 'Mathematics', 'English Language', 'Science', 'Social Studies',
    'Integrated Science', 'Physics', 'Chemistry', 'Biology', 'Geography',
    'History', 'Economics', 'Government', 'Literature', 'French'
  ];
  final List<String> difficulties = ['All', 'Easy', 'Medium', 'Hard', 'Expert'];
  final List<String> years = [
    'All', '2024', '2023', '2022', '2021', '2020', '2019', '2018'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _tabController = TabController(length: 4, vsync: this);
    
    _loadMockExams();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMockExams() async {
    try {
      setState(() => isLoading = true);
      allMockExams = await _mockExamService.getMockExams();
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading mock exams: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredMockExams = allMockExams.where((exam) {
        final matchesType = selectedExamType == 'All' || exam.examType == selectedExamType;
        final matchesSubject = selectedSubject == 'All' || exam.subject == selectedSubject;
        final matchesDifficulty = selectedDifficulty == 'All' || exam.difficulty == selectedDifficulty;
        final matchesYear = selectedYear == 'All' || exam.year == selectedYear;
        final matchesSearch = searchQuery.isEmpty ||
            exam.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            exam.subject.toLowerCase().contains(searchQuery.toLowerCase()) ||
            exam.description.toLowerCase().contains(searchQuery.toLowerCase());

        return matchesType && matchesSubject && matchesDifficulty && 
               matchesYear && matchesSearch;
      }).toList();

      // Sort by relevance and difficulty
      filteredMockExams.sort((a, b) {
        if (selectedDifficulty != 'All') {
          return a.difficulty.compareTo(b.difficulty);
        }
        return b.year.compareTo(a.year); // Most recent first
      });
    });
  }

  void _resetFilters() {
    setState(() {
      selectedExamType = 'All';
      selectedSubject = 'All';
      selectedDifficulty = 'All';
      selectedYear = 'All';
      searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Search and Filters
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search mock exams, subjects, topics...',
                          hintStyle: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => searchQuery = '');
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                          _applyFilters();
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Chips
                    if (isMobile) ...[
                      _buildMobileFilters(),
                    ] else ...[
                      _buildDesktopFilters(),
                    ],

                    // Filter Summary and Clear
                    if (_hasActiveFilters()) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.filter_list, 
                              size: 16, 
                              color: Color(0xFFD62828)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${filteredMockExams.length} mock exams found',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: const Color(0xFF1A1E3F),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear Filters'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD62828),
                              textStyle: GoogleFonts.montserrat(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Quick Access Tabs
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isMobile,
                  tabs: const [
                    Tab(text: 'All Exams'),
                    Tab(text: 'BECE'),
                    Tab(text: 'WASSCE'),
                    Tab(text: 'Practice Tests'),
                  ],
                  labelColor: const Color(0xFFD62828),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFFD62828),
                  labelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            // Quick Stats
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: _buildQuickStats(isMobile),
              ),
            ),

            // Content
            if (isLoading) ...[
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading mock exams...',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (filteredMockExams.isEmpty) ...[
              SliverFillRemaining(
                child: _buildEmptyState(),
              ),
            ] else ...[
              SliverPadding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                sliver: _buildMockExamsList(isMobile),
              ),
            ],

            // Bottom padding for mobile
            if (isMobile) ...[
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCustomTest(),
        backgroundColor: const Color(0xFFD62828),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Create Test',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        // Type and Subject filters
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                'Exam Type',
                selectedExamType,
                examTypes,
                (value) => setState(() {
                  selectedExamType = value!;
                  _applyFilters();
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterDropdown(
                'Subject',
                selectedSubject,
                subjects,
                (value) => setState(() {
                  selectedSubject = value!;
                  _applyFilters();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Difficulty and Year filters
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                'Difficulty',
                selectedDifficulty,
                difficulties,
                (value) => setState(() {
                  selectedDifficulty = value!;
                  _applyFilters();
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterDropdown(
                'Year',
                selectedYear,
                years,
                (value) => setState(() {
                  selectedYear = value!;
                  _applyFilters();
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            'Exam Type',
            selectedExamType,
            examTypes,
            (value) => setState(() {
              selectedExamType = value!;
              _applyFilters();
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterDropdown(
            'Subject',
            selectedSubject,
            subjects,
            (value) => setState(() {
              selectedSubject = value!;
              _applyFilters();
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterDropdown(
            'Difficulty',
            selectedDifficulty,
            difficulties,
            (value) => setState(() {
              selectedDifficulty = value!;
              _applyFilters();
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterDropdown(
            'Year',
            selectedYear,
            years,
            (value) => setState(() {
              selectedYear = value!;
              _applyFilters();
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          style: GoogleFonts.montserrat(
            color: const Color(0xFF1A1E3F),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildQuickStats(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1E3F), Color(0xFF2D3561)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1E3F).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Performance',
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            // Mobile: 2x2 grid
            Row(
              children: [
                Expanded(child: _buildStatCard('Tests Taken', '24', Icons.assignment_turned_in)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Average Score', '78%', Icons.trending_up)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('Best Score', '95%', Icons.star)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Time Spent', '18h', Icons.access_time)),
              ],
            ),
          ] else ...[
            // Desktop: horizontal row
            Row(
              children: [
                Expanded(child: _buildStatCard('Tests Taken', '24', Icons.assignment_turned_in)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Average Score', '78%', Icons.trending_up)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Best Score', '95%', Icons.star)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Time Spent', '18h', Icons.access_time)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return selectedExamType != 'All' ||
        selectedSubject != 'All' ||
        selectedDifficulty != 'All' ||
        selectedYear != 'All' ||
        searchQuery.isNotEmpty;
  }

  Widget _buildMockExamsList(bool isMobile) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final exam = filteredMockExams[index];
          return _buildMockExamCard(exam, isMobile);
        },
        childCount: filteredMockExams.length,
      ),
    );
  }

  Widget _buildMockExamCard(MockExam exam, bool isMobile) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _startExam(exam),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exam Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getExamTypeColor(exam.examType),
                          _getExamTypeColor(exam.examType).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getExamTypeIcon(exam.examType),
                      color: Colors.white,
                      size: isMobile ? 24 : 28,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Exam Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                exam.title,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1E3F),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(exam.difficulty).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                exam.difficulty,
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getDifficultyColor(exam.difficulty),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exam.description,
                          style: GoogleFonts.montserrat(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Exam Info Row
              if (isMobile) ...[
                // Mobile: Stack info vertically
                Column(
                  children: [
                    Row(
                      children: [
                        _buildInfoChip(Icons.subject, exam.subject, _getSubjectColor(exam.subject)),
                        const SizedBox(width: 8),
                        _buildInfoChip(Icons.schedule, '${exam.duration} min', Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoChip(Icons.quiz, '${exam.totalQuestions} Qs', Colors.blue),
                        const SizedBox(width: 8),
                        _buildInfoChip(Icons.calendar_today, exam.year, Colors.grey),
                        const Spacer(),
                        if (exam.isCompleted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  '${exam.lastScore}%',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ] else ...[
                // Desktop: Single row
                Row(
                  children: [
                    _buildInfoChip(Icons.subject, exam.subject, _getSubjectColor(exam.subject)),
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.schedule, '${exam.duration} min', Colors.orange),
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.quiz, '${exam.totalQuestions} Questions', Colors.blue),
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.calendar_today, exam.year, Colors.grey),
                    const Spacer(),
                    if (exam.isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              'Completed - ${exam.lastScore}%',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  if (exam.isCompleted) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewResults(exam),
                        icon: const Icon(Icons.analytics, size: 16),
                        label: const Text('View Results'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1E3F),
                          side: const BorderSide(color: Color(0xFF1A1E3F)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startExam(exam),
                      icon: Icon(
                        exam.isCompleted ? Icons.refresh : Icons.play_arrow,
                        size: 16,
                      ),
                      label: Text(exam.isCompleted ? 'Retake' : 'Start Exam'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD62828),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No mock exams found',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'No exams match your search criteria.\nTry adjusting your filters or search terms.'
                  : 'No mock exams available for the selected filters.\nTry selecting different options.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getExamTypeColor(String examType) {
    switch (examType.toLowerCase()) {
      case 'bece':
        return const Color(0xFF2196F3);
      case 'wassce':
        return const Color(0xFF4CAF50);
      case 'neco':
        return const Color(0xFFFF9800);
      case 'custom':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF1A1E3F);
    }
  }

  IconData _getExamTypeIcon(String examType) {
    switch (examType.toLowerCase()) {
      case 'bece':
        return Icons.school;
      case 'wassce':
        return Icons.workspace_premium;
      case 'neco':
        return Icons.verified;
      case 'custom':
        return Icons.create;
      default:
        return Icons.assignment;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'hard':
        return const Color(0xFFFF5722);
      case 'expert':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return const Color(0xFF2196F3);
      case 'english language':
        return const Color(0xFF4CAF50);
      case 'science':
      case 'integrated science':
      case 'physics':
      case 'chemistry':
      case 'biology':
        return const Color(0xFFFF9800);
      case 'social studies':
      case 'geography':
      case 'history':
      case 'economics':
      case 'government':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  void _startExam(MockExam exam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Start ${exam.title}',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${exam.duration} minutes'),
            Text('Questions: ${exam.totalQuestions}'),
            Text('Subject: ${exam.subject}'),
            Text('Difficulty: ${exam.difficulty}'),
            const SizedBox(height: 16),
            Text(
              'Make sure you have a stable internet connection and ${exam.duration} minutes to complete this exam.',
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to exam page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Starting ${exam.title}...'),
                  backgroundColor: const Color(0xFF1A1E3F),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _viewResults(MockExam exam) {
    // TODO: Navigate to results page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing results for ${exam.title}'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
    );
  }

  void _createCustomTest() {
    // TODO: Navigate to custom test creator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom test creator coming soon!'),
        backgroundColor: Color(0xFF1A1E3F),
      ),
    );
  }
}
