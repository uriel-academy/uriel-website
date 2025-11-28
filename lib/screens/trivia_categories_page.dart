import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/question_model.dart';
import 'quiz_taker_page.dart';

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

// Category configuration mapping
class _CategoryConfig {
  static final Map<String, Map<String, dynamic>> configs = {
    'African History': {
      'description': 'Explore the rich and diverse history of the African continent',
      'icon': Icons.history_edu,
      'color': const Color(0xFF6B7280),
    },
    'Art and Culture': {
      'description': 'Discover the world of art, music, and cultural traditions',
      'icon': Icons.palette,
      'color': const Color(0xFFFBBF77),
    },
    'Brain Teasers': {
      'description': 'Challenge your mind with puzzles and logical thinking',
      'icon': Icons.psychology,
      'color': const Color(0xFFB4A7D6),
    },
    'English': {
      'description': 'Test your knowledge of English language and literature',
      'icon': Icons.menu_book,
      'color': const Color(0xFFA8D8B9),
    },
    'General Knowledge': {
      'description': 'Test your knowledge across various topics and subjects',
      'icon': Icons.lightbulb,
      'color': const Color(0xFFFFE599),
    },
    'Geography (Africa & World)': {
      'description': 'Journey through continents, countries, and landmarks',
      'icon': Icons.map,
      'color': const Color(0xFF9CD4D4),
    },
    'Ghana History': {
      'description': 'Learn about Ghana\'s rich heritage and independence journey',
      'icon': Icons.flag,
      'color': const Color(0xFFFFB84D),
    },
    'Mathematics': {
      'description': 'Sharpen your mathematical skills and problem-solving',
      'icon': Icons.calculate,
      'color': const Color(0xFF9BB8E8),
    },
    'Pop Culture & Entertainment': {
      'description': 'Stay updated with movies, music, and entertainment',
      'icon': Icons.movie,
      'color': const Color(0xFFFFB3BA),
    },
    'Science': {
      'description': 'Explore physics, chemistry, biology, and more',
      'icon': Icons.science,
      'color': const Color(0xFFB5E5CF),
    },
    'Sports': {
      'description': 'Test your sports knowledge from football to athletics',
      'icon': Icons.sports_soccer,
      'color': const Color(0xFFD4F1A5),
    },
    'Technology': {
      'description': 'Stay ahead with tech, computers, and innovations',
      'icon': Icons.computer,
      'color': const Color(0xFFC1C1C1),
    },
    'World History': {
      'description': 'Journey through civilizations and global historical events',
      'icon': Icons.public,
      'color': const Color(0xFFBAC7E8),
    },
    'Countries & Capitals': {
      'description': 'Test your knowledge of world countries and their capitals',
      'icon': Icons.location_city,
      'color': const Color(0xFFFFD1DC),
    },
  };

  static TriviaCategory? createCategory(String subject, int questionCount) {
    final config = configs[subject];
    if (config == null) return null;

    final color = config['color'] as Color;
    return TriviaCategory(
      name: subject,
      description: config['description'] as String,
      icon: config['icon'] as IconData,
      color: color,
      gradient: [color, color],
    );
  }
}

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
  final TextEditingController _triviaTopicController = TextEditingController();

  bool isLoading = true;
  String searchQuery = '';
  Map<String, int> categoryCounts = {};
  List<TriviaCategory> categories = [];
  List<TriviaCategory> filteredCategories = [];
  
  // AI Trivia Generator state
  bool _isGeneratingTrivia = false;
  int _selectedTriviaCount = 10;
  String _selectedTriviaDifficulty = 'medium';
  String _selectedTriviaCategory = 'General Knowledge';

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
    _animationController.forward();
    // Load categories synchronously for testing
    _loadCategoriesSync();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _triviaTopicController.dispose();
    super.dispose();
  }

  void _loadCategoriesSync() {
    // Load categories from trivia_index.json
    rootBundle.loadString('assets/trivia/trivia_index.json').then((jsonString) {
      try {
        final Map<String, dynamic> data = json.decode(jsonString);
        final List<dynamic> categoriesData = data['summary'] ?? [];

        final List<TriviaCategory> loadedCategories = [];
        final Map<String, int> loadedCounts = {};

        debugPrint('📚 Loading ${categoriesData.length} categories from JSON');

        for (final categoryData in categoriesData) {
          final String subject = categoryData['subject'] ?? '';
          final int numQuestions = categoryData['num_questions'] ?? 0;

          debugPrint('   Checking category: "$subject"');

          // Create category using config mapping
          final category = _CategoryConfig.createCategory(subject, numQuestions);
          if (category != null) {
            loadedCategories.add(category);
            loadedCounts[subject] = numQuestions;
            debugPrint('   ✅ Added category: $subject');
          } else {
            debugPrint('   ❌ Failed to create category for: $subject');
          }
        }

        debugPrint('📊 Loaded ${loadedCategories.length} categories successfully');

        setState(() {
          categories = loadedCategories;
          categoryCounts = loadedCounts;
          filteredCategories = loadedCategories;
          isLoading = false;
        });
      } catch (e) {
        debugPrint('❌ Error loading trivia categories: $e');
        _loadFallbackCategories();
      }
    }).catchError((error) {
      debugPrint('❌ Error loading trivia_index.json: $error');
      _loadFallbackCategories();
    });
  }

  void _loadFallbackCategories() {
    final List<TriviaCategory> fallbackCategories = [
      TriviaCategory(
        name: 'Countries & Capitals',
        description: 'Test your knowledge of world countries and their capitals',
        icon: Icons.location_city,
        color: const Color(0xFFFFD1DC),
        gradient: const [Color(0xFFFFD1DC), Color(0xFFFFD1DC)],
      ),
      TriviaCategory(
        name: 'General Knowledge',
        description: 'Test your knowledge across various topics and subjects',
        icon: Icons.lightbulb,
        color: const Color(0xFFFFE599),
        gradient: const [Color(0xFFFFE599), Color(0xFFFFE599)],
      ),
    ];

    final Map<String, int> fallbackCounts = {
      'Countries & Capitals': 194,
      'General Knowledge': 200,
    };

    setState(() {
      categories = fallbackCategories;
      categoryCounts = fallbackCounts;
      filteredCategories = fallbackCategories;
      isLoading = false;
    });
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
              
              // AI Trivia Generator Card
              Container(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 1200,
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: _buildAITriviaCard(isMobile),
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

  // Generate AI Trivia Questions
  Future<void> _generateAITrivia() async {
    // Validate that custom category has text when selected
    if (_selectedTriviaCategory == 'Custom' && _triviaTopicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter your custom category',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: const Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() => _isGeneratingTrivia = true);

    try {
      // Use custom text if Custom is selected, otherwise use selected category
      final topicToUse = _selectedTriviaCategory == 'Custom' 
          ? _triviaTopicController.text.trim() 
          : _selectedTriviaCategory;

      debugPrint('🎲 Generating AI Trivia: topic=$topicToUse, count=$_selectedTriviaCount, difficulty=$_selectedTriviaDifficulty');

      final callable = FirebaseFunctions.instance.httpsCallable('generateAIQuiz');
      final result = await callable.call({
        'subject': 'General Knowledge',
        'examType': 'trivia',
        'numQuestions': _selectedTriviaCount,
        'difficultyLevel': _selectedTriviaDifficulty,
        'customTopic': topicToUse,
      });

      final aiGeneratedQuestions = result.data['questions'] as List<dynamic>;
      debugPrint('✅ Generated ${aiGeneratedQuestions.length} AI trivia questions');

      // Convert to Question objects
      final List<Question> questions = [];
      for (var i = 0; i < aiGeneratedQuestions.length; i++) {
        final q = aiGeneratedQuestions[i];
        
        // Parse options from {A: "...", B: "...", C: "...", D: "..."} to List
        // Format with letter prefix to match expected format: "A. Answer", "B. Answer", etc.
        final optionsMap = q['options'] as Map<String, dynamic>;
        final optionsList = [
          'A. ${optionsMap['A']?.toString() ?? ''}',
          'B. ${optionsMap['B']?.toString() ?? ''}',
          'C. ${optionsMap['C']?.toString() ?? ''}',
          'D. ${optionsMap['D']?.toString() ?? ''}',
        ];
        
        // Store correctAnswer as just the letter (A, B, C, D) to match grading logic
        final correctAnswerLetter = q['correctAnswer']?.toString().toUpperCase() ?? 'A';
        
        questions.add(Question(
          id: 'ai_trivia_${DateTime.now().millisecondsSinceEpoch}_$i',
          questionText: q['question']?.toString() ?? '',
          type: QuestionType.trivia,
          subject: Subject.trivia,
          examType: ExamType.trivia,
          year: 'AI Generated',
          section: 'General',
          questionNumber: i + 1,
          options: optionsList,
          correctAnswer: correctAnswerLetter,
          difficulty: q['difficulty']?.toString() ?? _selectedTriviaDifficulty,
          explanation: q['explanation']?.toString() ?? '',
          marks: 1,
          topics: [q['topic']?.toString() ?? topicToUse],
          createdAt: DateTime.now(),
          createdBy: 'AI',
        ));
      }

      if (mounted) {
        // Navigate to quiz taker with generated questions
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizTakerPage(
              subject: 'trivia',
              examType: 'trivia',
              level: 'General',
              triviaCategory: topicToUse,
              questionCount: _selectedTriviaCount,
              randomizeQuestions: false,
              preloadedQuestions: questions,
              customTitle: 'AI Generated Trivia: $topicToUse',
              isRevisionQuiz: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error generating AI trivia: $e');
      debugPrint('Error type: ${e.runtimeType}');
      
      // Extract more detailed error message
      String errorMessage = 'Error generating trivia';
      if (e.toString().contains('invalid question format')) {
        errorMessage = 'AI generated invalid question format. Please try again.';
      } else if (e.toString().contains('expected non-empty array')) {
        errorMessage = 'AI returned empty response. Please try again.';
      } else if (e.toString().contains('Invalid options format')) {
        errorMessage = 'AI generated invalid answer options. Please try again.';
      } else {
        errorMessage = e.toString().replaceAll('firebase_functions/', '')
            .replaceAll('[internal]', '')
            .replaceAll('Exception:', '')
            .trim();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: const Color(0xFFD62828),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTrivia = false);
      }
    }
  }

  Widget _buildAITriviaCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9B59B6),
            Color(0xFF8E44AD),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B59B6).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Trivia Generator',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create custom trivia questions instantly with AI',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Options Container
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdowns
                if (isMobile) ...[
                  _buildDropdownField(
                    'Number of Questions',
                    _selectedTriviaCount.toString(),
                    ['10', '20', '40'],
                    (value) => setState(() => _selectedTriviaCount = int.parse(value!)),
                    isMobile,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    'Difficulty',
                    _selectedTriviaDifficulty,
                    ['easy', 'medium', 'hard'],
                    (value) => setState(() => _selectedTriviaDifficulty = value!),
                    isMobile,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    'Category',
                    _selectedTriviaCategory,
                    [
                      ..._CategoryConfig.configs.keys.toList()..sort(),
                      'Custom',
                    ],
                    (value) => setState(() => _selectedTriviaCategory = value!),
                    isMobile,
                  ),
                  if (_selectedTriviaCategory == 'Custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _triviaTopicController,
                      decoration: InputDecoration(
                        labelText: 'Enter Your Custom Category',
                        hintText: 'e.g., Marvel Movies, African Wildlife, Space Exploration',
                        labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
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
                      style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
                    ),
                  ],
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          'Number of Questions',
                          _selectedTriviaCount.toString(),
                          ['10', '20', '40'],
                          (value) => setState(() => _selectedTriviaCount = int.parse(value!)),
                          isMobile,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                          'Difficulty',
                          _selectedTriviaDifficulty,
                          ['easy', 'medium', 'hard'],
                          (value) => setState(() => _selectedTriviaDifficulty = value!),
                          isMobile,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                          'Category',
                          _selectedTriviaCategory,
                          [
                            ..._CategoryConfig.configs.keys.toList()..sort(),
                            'Custom',
                          ],
                          (value) => setState(() => _selectedTriviaCategory = value!),
                          isMobile,
                        ),
                      ),
                    ],
                  ),
                
                if (_selectedTriviaCategory == 'Custom')
                  const SizedBox(height: 16),
                
                // Custom Category Field (only show when Custom is selected)
                if (_selectedTriviaCategory == 'Custom')
                  TextField(
                    controller: _triviaTopicController,
                    decoration: InputDecoration(
                      labelText: 'Enter Your Custom Category',
                      hintText: 'e.g., Marvel Movies, African Wildlife, Space Exploration',
                      labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                      hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
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
                      prefixIcon: Icon(Icons.edit, color: Colors.grey[600]),
                    ),
                    style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
                  ),
                
                const SizedBox(height: 20),
                
                // Generate Button
                SizedBox(
                  width: double.infinity,
                  child: _isGeneratingTrivia
                      ? Column(
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF9B59B6),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI is generating trivia questions...',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          onPressed: _generateAITrivia,
                          icon: const Icon(Icons.auto_awesome, size: 20),
                          label: Text(
                            'Generate with AI',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B59B6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                // Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.purple[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI generates unique trivia questions based on your selected category and difficulty',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.purple[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF1A1E3F),
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
            dropdownColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
