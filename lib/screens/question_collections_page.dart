import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../models/question_collection_model.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import 'quiz_setup_page.dart';
import 'question_detail_page.dart';

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
      print('🚀 Loading question collections...');
      
      // Load all questions
      final questions = await _questionService.getQuestions().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Question>[],
      );
      
      final rmeQuestions = await _questionService.getRMEQuestions().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Question>[],
      );
      
      // Merge questions
      final mergedQuestions = <Question>[...questions];
      for (final q in rmeQuestions) {
        if (!mergedQuestions.any((existing) => existing.id == q.id)) {
          mergedQuestions.add(q);
        }
      }
      
      print('📊 Loaded ${mergedQuestions.length} total questions');
      
      // Group into collections
      final collections = QuestionCollection.groupQuestions(mergedQuestions);
      
      // Sort by year (most recent first)
      collections.sort((a, b) => b.year.compareTo(a.year));
      
      print('📦 Created ${collections.length} collections');
      
      setState(() {
        _collections = collections;
        _filteredCollections = collections;
        _isLoading = false;
      });
      
      // Apply initial subject filter if provided
      if (widget.initialSubject != null) {
        _applyInitialSubjectFilter();
      }
    } catch (e) {
      print('❌ Error loading collections: $e');
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
      backgroundColor: const Color(0xFF1A1E3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E3F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Past Question Collections',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD62828)))
          : Column(
              children: [
                _buildFilters(isSmallScreen),
                Expanded(
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
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2A2E4F),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            style: GoogleFonts.montserrat(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search collections...',
              hintStyle: GoogleFonts.montserrat(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1A1E3F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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
          const SizedBox(height: 12),
          Text(
            'Found ${_filteredCollections.length} collections',
            style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 14),
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
        labelStyle: GoogleFonts.montserrat(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1A1E3F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: const Color(0xFF1A1E3F),
      style: GoogleFonts.montserrat(color: Colors.white),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No collections found',
            style: GoogleFonts.playfairDisplay(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsList(bool isSmallScreen) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCollections.length,
      itemBuilder: (context, index) {
        return _buildCollectionCard(_filteredCollections[index], isSmallScreen);
      },
    );
  }

  Widget _buildCollectionCard(QuestionCollection collection, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2E4F),
            const Color(0xFF1A1E3F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD62828).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    collection.year,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
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
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${collection.questionCount} Questions',
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (isSmallScreen)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildActionButton(
                    icon: Icons.visibility,
                    label: 'View Questions',
                    onPressed: () => _viewCollection(collection),
                    isPrimary: false,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.play_arrow,
                    label: 'Start Quiz',
                    onPressed: () => _startQuiz(collection),
                    isPrimary: true,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.visibility,
                      label: 'View Questions',
                      onPressed: () => _viewCollection(collection),
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.play_arrow,
                      label: 'Start Quiz',
                      onPressed: () => _startQuiz(collection),
                      isPrimary: true,
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
        backgroundColor: isPrimary ? const Color(0xFFD62828) : Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
      ),
    );
  }

  void _viewCollection(QuestionCollection collection) {
    // Navigate to a page showing all questions in this collection
    if (collection.questions.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuestionDetailPage(question: collection.questions.first),
        ),
      );
    }
  }

  void _startQuiz(QuestionCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizSetupPage(
          preselectedSubject: _formatSubjectName(collection.subject),
          preselectedExamType: collection.examType.name.toUpperCase(),
          preselectedLevel: 'JHS 3', // Default to JHS 3 for BECE
          preloadedQuestions: collection.questions,
        ),
      ),
    );
  }
}
