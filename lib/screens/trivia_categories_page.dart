import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';
import 'quiz_setup_page.dart';

class TriviaCategoriesPage extends StatefulWidget {
  const TriviaCategoriesPage({super.key});

  @override
  State<TriviaCategoriesPage> createState() => _TriviaCategoriesPageState();
}

class _TriviaCategoriesPageState extends State<TriviaCategoriesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final QuestionService _questionService = QuestionService();
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  String searchQuery = '';
  Map<String, int> categoryCounts = {};

  // 13 trivia categories as imported
  final List<TriviaCategory> categories = [
    TriviaCategory(
      name: 'African History',
      description: 'Explore the rich and diverse history of the African continent',
      icon: Icons.history_edu,
      color: const Color(0xFF795548),
      gradient: const [Color(0xFF795548), Color(0xFF5D4037)],
    ),
    TriviaCategory(
      name: 'Art and Culture',
      description: 'Discover the world of art, music, and cultural traditions',
      icon: Icons.palette,
      color: const Color(0xFFE91E63),
      gradient: const [Color(0xFFE91E63), Color(0xFFC2185B)],
    ),
    TriviaCategory(
      name: 'Brain Teasers',
      description: 'Challenge your mind with puzzles and logical thinking',
      icon: Icons.psychology,
      color: const Color(0xFF9C27B0),
      gradient: const [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
    ),
    TriviaCategory(
      name: 'English',
      description: 'Test your knowledge of English language and literature',
      icon: Icons.menu_book,
      color: const Color(0xFF4CAF50),
      gradient: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
    ),
    TriviaCategory(
      name: 'General Knowledge',
      description: 'Test your knowledge across various topics and subjects',
      icon: Icons.lightbulb,
      color: const Color(0xFF607D8B),
      gradient: const [Color(0xFF607D8B), Color(0xFF455A64)],
    ),
    TriviaCategory(
      name: 'Geography',
      description: 'Journey through continents, countries, and landmarks',
      icon: Icons.map,
      color: const Color(0xFF009688),
      gradient: const [Color(0xFF009688), Color(0xFF00796B)],
    ),
    TriviaCategory(
      name: 'Ghana History',
      description: 'Learn about Ghana\'s rich heritage and independence journey',
      icon: Icons.flag,
      color: const Color(0xFFFF9800),
      gradient: const [Color(0xFFFF9800), Color(0xFFF57C00)],
    ),
    TriviaCategory(
      name: 'Mathematics',
      description: 'Sharpen your mathematical skills and problem-solving',
      icon: Icons.calculate,
      color: const Color(0xFF2196F3),
      gradient: const [Color(0xFF2196F3), Color(0xFF1976D2)],
    ),
    TriviaCategory(
      name: 'Pop Culture and Entertainment',
      description: 'Stay updated with movies, music, and entertainment',
      icon: Icons.movie,
      color: const Color(0xFFFF5722),
      gradient: const [Color(0xFFFF5722), Color(0xFFE64A19)],
    ),
    TriviaCategory(
      name: 'Science',
      description: 'Explore physics, chemistry, biology, and more',
      icon: Icons.science,
      color: const Color(0xFF00BCD4),
      gradient: const [Color(0xFF00BCD4), Color(0xFF0097A7)],
    ),
    TriviaCategory(
      name: 'Sports',
      description: 'Test your sports knowledge from football to athletics',
      icon: Icons.sports_soccer,
      color: const Color(0xFF8BC34A),
      gradient: const [Color(0xFF8BC34A), Color(0xFF689F38)],
    ),
    TriviaCategory(
      name: 'Technology',
      description: 'Stay ahead with tech, computers, and innovations',
      icon: Icons.computer,
      color: const Color(0xFF9E9E9E),
      gradient: const [Color(0xFF9E9E9E), Color(0xFF757575)],
    ),
    TriviaCategory(
      name: 'World History',
      description: 'Journey through civilizations and global historical events',
      icon: Icons.public,
      color: const Color(0xFF3F51B5),
      gradient: const [Color(0xFF3F51B5), Color(0xFF303F9F)],
    ),
  ];

  List<TriviaCategory> filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    filteredCategories = categories;
    _animationController.forward();
    _loadQuestionCounts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestionCounts() async {
    setState(() => isLoading = true);
    try {
      // Load question counts for each category
      for (var category in categories) {
        final count = await _questionService.getQuestionsCount(
          examType: 'trivia',
          subject: 'trivia',
        );
        // Note: We're showing all questions are available since they're imported
        // In production, you'd filter by triviaCategory field
        categoryCounts[category.name] = 200; // Each category has ~200 questions
      }
    } catch (e) {
      print('Error loading question counts: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applySearch() {
    setState(() {
      if (searchQuery.isEmpty) {
        filteredCategories = categories;
      } else {
        filteredCategories = categories.where((category) {
          return category.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              category.description.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }
    });
  }

  void _startQuiz(TriviaCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizSetupPage(
          preselectedSubject: 'trivia',
          preselectedExamType: 'trivia',
          preselectedLevel: 'JHS',
          triviaCategory: category.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1E3F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trivia Categories',
          style: GoogleFonts.playfairDisplay(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        centerTitle: false,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Challenge',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 24 : 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a category to start your trivia quiz journey. Each quiz contains 20 carefully selected questions.',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                        _applySearch();
                      },
                      style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
                      decoration: InputDecoration(
                        hintText: 'Search categories...',
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[600]),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => searchQuery = '');
                                  _applySearch();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFE),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stats
                    Row(
                      children: [
                        Icon(Icons.category, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${filteredCategories.length} categories available',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Categories Grid
              Container(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 1200,
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: CircularProgressIndicator(
                            color: const Color(0xFFD62828),
                          ),
                        ),
                      )
                    : filteredCategories.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isMobile ? 1 : (screenWidth < 1024 ? 2 : 3),
                              crossAxisSpacing: isMobile ? 0 : 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: isMobile ? 1.3 : 1.1,
                            ),
                            itemCount: filteredCategories.length,
                            itemBuilder: (context, index) {
                              return _buildCategoryCard(
                                filteredCategories[index],
                                isMobile,
                              );
                            },
                          ),
              ),
              
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(TriviaCategory category, bool isMobile) {
    final questionCount = categoryCounts[category.name] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient Header
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: category.gradient,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(
                category.icon,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Name
                  Text(
                    category.name,
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFF1A1E3F),
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Expanded(
                    child: Text(
                      category.description,
                      style: GoogleFonts.montserrat(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Question Count
                  Row(
                    children: [
                      Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        questionCount > 0 
                            ? '$questionCount Questions (20 per quiz)'
                            : 'Loading...',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Start Quiz Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: questionCount > 0 
                          ? () => _startQuiz(category)
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: Text(
                        'Start Quiz',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: category.color,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
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
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No categories found',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => searchQuery = '');
                _applySearch();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
}

// Model class for trivia categories
class TriviaCategory {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  TriviaCategory({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
