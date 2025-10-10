import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'quiz_taker_page.dart';

class TriviaCategoriesPage extends StatefulWidget {
  const TriviaCategoriesPage({super.key});

  @override
  State<TriviaCategoriesPage> createState() => _TriviaCategoriesPageState();
}

class _TriviaCategoriesPageState extends State<TriviaCategoriesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  String searchQuery = '';
  Map<String, int> categoryCounts = {};

  // 13 trivia categories with pastel colors (no gradients)
  final List<TriviaCategory> categories = [
    TriviaCategory(
      name: 'African History',
      description: 'Explore the rich and diverse history of the African continent',
      icon: Icons.history_edu,
      color: const Color(0xFF6B7280), // Pastel Black (Cool Gray)
      gradient: const [Color(0xFF6B7280), Color(0xFF6B7280)],
    ),
    TriviaCategory(
      name: 'Art and Culture',
      description: 'Discover the world of art, music, and cultural traditions',
      icon: Icons.palette,
      color: const Color(0xFFFBBF77), // Pastel Peach
      gradient: const [Color(0xFFFBBF77), Color(0xFFFBBF77)],
    ),
    TriviaCategory(
      name: 'Brain Teasers',
      description: 'Challenge your mind with puzzles and logical thinking',
      icon: Icons.psychology,
      color: const Color(0xFFB4A7D6), // Pastel Purple
      gradient: const [Color(0xFFB4A7D6), Color(0xFFB4A7D6)],
    ),
    TriviaCategory(
      name: 'English',
      description: 'Test your knowledge of English language and literature',
      icon: Icons.menu_book,
      color: const Color(0xFFA8D8B9), // Pastel Mint Green
      gradient: const [Color(0xFFA8D8B9), Color(0xFFA8D8B9)],
    ),
    TriviaCategory(
      name: 'General Knowledge',
      description: 'Test your knowledge across various topics and subjects',
      icon: Icons.lightbulb,
      color: const Color(0xFFFFE599), // Pastel Yellow
      gradient: const [Color(0xFFFFE599), Color(0xFFFFE599)],
    ),
    TriviaCategory(
      name: 'Geography',
      description: 'Journey through continents, countries, and landmarks',
      icon: Icons.map,
      color: const Color(0xFF9CD4D4), // Pastel Teal
      gradient: const [Color(0xFF9CD4D4), Color(0xFF9CD4D4)],
    ),
    TriviaCategory(
      name: 'Ghana History',
      description: 'Learn about Ghana\'s rich heritage and independence journey',
      icon: Icons.flag,
      color: const Color(0xFFFFB84D), // Pastel Gold/Amber
      gradient: const [Color(0xFFFFB84D), Color(0xFFFFB84D)],
    ),
    TriviaCategory(
      name: 'Mathematics',
      description: 'Sharpen your mathematical skills and problem-solving',
      icon: Icons.calculate,
      color: const Color(0xFF9BB8E8), // Pastel Blue
      gradient: const [Color(0xFF9BB8E8), Color(0xFF9BB8E8)],
    ),
    TriviaCategory(
      name: 'Pop Culture and Entertainment',
      description: 'Stay updated with movies, music, and entertainment',
      icon: Icons.movie,
      color: const Color(0xFFFFB3BA), // Pastel Pink
      gradient: const [Color(0xFFFFB3BA), Color(0xFFFFB3BA)],
    ),
    TriviaCategory(
      name: 'Science',
      description: 'Explore physics, chemistry, biology, and more',
      icon: Icons.science,
      color: const Color(0xFFB5E5CF), // Pastel Sage Green
      gradient: const [Color(0xFFB5E5CF), Color(0xFFB5E5CF)],
    ),
    TriviaCategory(
      name: 'Sports',
      description: 'Test your sports knowledge from football to athletics',
      icon: Icons.sports_soccer,
      color: const Color(0xFFD4F1A5), // Pastel Lime
      gradient: const [Color(0xFFD4F1A5), Color(0xFFD4F1A5)],
    ),
    TriviaCategory(
      name: 'Technology',
      description: 'Stay ahead with tech, computers, and innovations',
      icon: Icons.computer,
      color: const Color(0xFFC1C1C1), // Pastel Silver
      gradient: const [Color(0xFFC1C1C1), Color(0xFFC1C1C1)],
    ),
    TriviaCategory(
      name: 'World History',
      description: 'Journey through civilizations and global historical events',
      icon: Icons.public,
      color: const Color(0xFFBAC7E8), // Pastel Lavender Blue
      gradient: const [Color(0xFFBAC7E8), Color(0xFFBAC7E8)],
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
    // Filter out Mathematics category (temporarily disabled)
    filteredCategories = categories.where((cat) => cat.name != 'Mathematics').toList();
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
      // Set question counts for each category (all categories have ~200 questions)
      for (var category in categories) {
        categoryCounts[category.name] = 200;
      }
    } catch (e) {
      debugPrint('Error loading question counts: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applySearch() {
    setState(() {
      if (searchQuery.isEmpty) {
        // Filter out Mathematics category (temporarily disabled)
        filteredCategories = categories.where((cat) => cat.name != 'Mathematics').toList();
      } else {
        filteredCategories = categories.where((category) {
          // Exclude Mathematics and apply search filter
          return category.name != 'Mathematics' &&
              (category.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              category.description.toLowerCase().contains(searchQuery.toLowerCase()));
        }).toList();
      }
    });
  }

  void _startQuiz(TriviaCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizTakerPage(
          subject: 'trivia',
          examType: 'trivia',
          level: 'JHS',
          triviaCategory: category.name,
          questionCount: 20, // Trivia always uses 20 questions
          randomizeQuestions: true, // Always randomize trivia for variety
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
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48.0),
                          child: CircularProgressIndicator(
                            color: Color(0xFFD62828),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                        backgroundColor: const Color(0xFF2ECC71), // Accent Green
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
                color: Colors.grey.withValues(alpha: 0.1),
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
