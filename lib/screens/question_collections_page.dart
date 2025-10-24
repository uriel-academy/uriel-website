import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../models/question_collection_model.dart';
import '../services/question_service.dart';
import 'quiz_taker_page.dart';
import 'dart:math' as math;

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
  // Pagination
  int _currentPage = 0;
  final int _pageSize = 20;
  
  // Filters
  String _selectedExamType = 'All Types';
  String _selectedSubject = 'All Subjects';
  String _selectedYear = 'All Years';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🚀 Loading question collections...');
      
      // Load all questions with increased timeout
      final questions = await _questionService.getQuestions().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏰ Timeout loading general questions');
          return <Question>[];
        },
      );
      
      final rmeQuestions = await _questionService.getRMEQuestions().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏰ Timeout loading RME questions');
          return <Question>[];
        },
      );
      
      // Merge questions
      final mergedQuestions = <Question>[...questions];
      for (final q in rmeQuestions) {
        if (!mergedQuestions.any((existing) => existing.id == q.id)) {
          mergedQuestions.add(q);
        }
      }
      
      debugPrint('📊 Loaded ${mergedQuestions.length} total questions');
      
      if (mergedQuestions.isEmpty) {
        debugPrint('⚠️ No questions loaded! Check Firebase connection and data.');
      }
      
      // Group into collections
      final collections = QuestionCollection.groupQuestions(mergedQuestions);
      
      // Sort by year (most recent first)
      collections.sort((a, b) => b.year.compareTo(a.year));
      
      debugPrint('📦 Created ${collections.length} collections');
      
      setState(() {
        _collections = collections;
        _filteredCollections = collections;
        _currentPage = 0; // reset pagination
        _isLoading = false;
      });
      
      // Apply initial subject filter if provided
      if (widget.initialSubject != null) {
        _applyInitialSubjectFilter();
      }
    } catch (e) {
      debugPrint('❌ Error loading collections: $e');
      setState(() => _isLoading = false);
    }
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
      _filteredCollections = _collections.where((collection) {
        // Exam type filter
        if (_selectedExamType != 'All Types') {
          final examMatch = collection.examType.name.toUpperCase() == _selectedExamType.toUpperCase();
          if (!examMatch) return false;
        }
        
        // Subject filter
        if (_selectedSubject != 'All Subjects') {
          final subjectMatch = _formatSubjectName(collection.subject) == _selectedSubject;
          if (!subjectMatch) return false;
        }
        
        // Year filter
        if (_selectedYear != 'All Years') {
          if (collection.year != _selectedYear) return false;
        }
        
        // Search filter
        if (_searchController.text.isNotEmpty) {
          final search = _searchController.text.toLowerCase();
          final displayName = collection.displayName.toLowerCase();
          if (!displayName.contains(search)) return false;
        }
        
        return true;
      }).toList();
    });
  }

  String _formatSubjectName(Subject subject) {
    switch (subject) {
      case Subject.mathematics: return 'Mathematics';
      case Subject.english: return 'English';
      case Subject.integratedScience: return 'Integrated Science';
      case Subject.socialStudies: return 'Social Studies';
      case Subject.ghanaianLanguage: return 'Ghanaian Language';
      case Subject.french: return 'French';
      case Subject.ict: return 'ICT';
      case Subject.religiousMoralEducation: return 'Religious and Moral Education';
      case Subject.creativeArts: return 'Creative Arts';
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
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildFilters(isSmallScreen),
                ),
                SliverToBoxAdapter(
                  child: _filteredCollections.isEmpty
                      ? _buildEmptyState()
                      : _buildCollectionsList(isSmallScreen),
                ),
              ],
            ),
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
                _buildFilterDropdown('Exam Type', _selectedExamType, ['All Types', 'BECE', 'WASSCE'], (value) {
                  setState(() => _selectedExamType = value!);
                  _applyFilters();
                }),
                const SizedBox(height: 8),
                _buildFilterDropdown('Subject', _selectedSubject, _getSubjectOptions(), (value) {
                  setState(() => _selectedSubject = value!);
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
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown('Exam Type', _selectedExamType, ['All Types', 'BECE', 'WASSCE'], (value) {
                    setState(() => _selectedExamType = value!);
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown('Subject', _selectedSubject, _getSubjectOptions(), (value) {
                    setState(() => _selectedSubject = value!);
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
                  _selectedExamType != 'All Types' || 
                  _selectedSubject != 'All Subjects' || 
                  _selectedYear != 'All Years')
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedExamType = 'All Types';
                      _selectedSubject = 'All Subjects';
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
    // Compute paginated slice
    final total = _filteredCollections.length;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    final start = _currentPage * _pageSize;
    final end = math.min(start + _pageSize, total);
    final paged = start < end ? _filteredCollections.sublist(start, end) : <QuestionCollection>[];

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
                  children: paged.map((collection) {
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
                  itemCount: paged.length,
                  itemBuilder: (context, index) {
                    return _buildCollectionCard(paged[index], isSmallScreen);
                  },
                ),

          const SizedBox(height: 12),

          // Pagination controls
          if (total > _pageSize)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                const SizedBox(width: 12),
                Text('Page ${_currentPage + 1} of $totalPages', style: GoogleFonts.montserrat()),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(QuestionCollection collection, bool isSmallScreen) {
    return Container(
      margin: isSmallScreen ? const EdgeInsets.only(bottom: 16) : EdgeInsets.zero,
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
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    collection.examType.name.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 12,
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
              collection.displayName,
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
                      // Start Quiz Button (Mobile - full width)
                      _buildActionButton(
                        icon: Icons.play_arrow,
                        label: 'Start Quiz',
                        onPressed: () => _startQuiz(collection),
                        isPrimary: true,
                      ),
                    ],
                  )
                : Row(
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
                            icon: Icons.play_arrow,
                            label: 'Start Quiz',
                            onPressed: () => _startQuiz(collection),
                            isPrimary: true,
                          ),
                        ),
                      ),
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

  void _startQuiz(QuestionCollection collection) {
    // Start quiz immediately, bypassing quiz setup page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizTakerPage(
          subject: _formatSubjectName(collection.subject),
          examType: collection.examType.name.toUpperCase(),
          level: 'JHS 3', // Default to JHS 3 for BECE
          questionCount: collection.questions.length,
          randomizeQuestions: _randomizeQuestions, // Use toggle state
          preloadedQuestions: collection.questions, // Pass questions directly
        ),
      ),
    );
  }
}
