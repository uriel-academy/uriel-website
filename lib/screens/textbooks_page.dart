import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/textbook_model.dart';
import '../models/storybook_model.dart';
import '../services/textbook_service.dart';
import '../services/storybook_service.dart';
import '../services/course_reader_service.dart';
import '../services/english_textbook_service.dart';
import '../services/social_rme_textbook_service.dart';
import 'enhanced_epub_reader_page.dart';
import 'course_unit_list_page.dart';
import 'english_textbook_reader_page.dart';
import 'social_rme_textbook_reader_page.dart';

class TextbooksPage extends StatefulWidget {
  const TextbooksPage({super.key});

  @override
  State<TextbooksPage> createState() => _TextbooksPageState();
}

class _TextbooksPageState extends State<TextbooksPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  final TextbookService _textbookService = TextbookService();
  final StorybookService _storybookService = StorybookService();
  final SocialRmeTextbookService _socialRmeService = SocialRmeTextbookService();
  final TextEditingController _searchController = TextEditingController();

  String selectedLevel = 'All';
  String selectedSubject = 'All';
  String selectedPublisher = 'All';
  String selectedAuthor = 'All';
  String searchQuery = '';
  bool isGridView = true;

  List<Textbook> allTextbooks = [];
  List<Textbook> filteredTextbooks = [];
  List<Storybook> allStorybooks = [];
  List<Storybook> filteredStorybooks = [];
  List<String> authors = [];
  List<Map<String, dynamic>> englishTextbooks = [];
  List<Map<String, dynamic>> filteredEnglishTextbooks = [];
  Map<String, Map<String, dynamic>> englishProgressMap = {};
  
  // Social Studies and RME textbooks
  List<Map<String, dynamic>> socialStudiesTextbooks = [];
  List<Map<String, dynamic>> rmeTextbooks = [];
  List<Map<String, dynamic>> filteredSocialRmeTextbooks = [];
  Map<String, Map<String, dynamic>> socialRmeProgressMap = {};
  bool isLoadingSocialRme = true;
  
  bool isLoading = true;
  bool isLoadingEnglish = true;
  
  // Pagination state
  int _currentEnglishPage = 0;
  int _currentStorybookPage = 0;

  final List<String> levels = ['All', 'JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3'];
  final List<String> subjects = [
    'All', 'English', 'Mathematics', 'English Language', 'Science', 'Social Studies',
    'ICT', 'Religious & Moral Education', 'Creative Arts', 'French',
    'Twi', 'Ga', 'Ewe', 'Technical Skills'
  ];
  final List<String> publishers = [
    'All', 'Uriel Academy', 'Unimax Macmillan', 'Sedco Publishing', 'Sam-Woode Publishers',
    'Goldfield Publishers', 'Ministry of Education'
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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    _loadTextbooks();
    _loadStorybooks();
    _loadEnglishTextbooks();
    _loadSocialRmeTextbooks();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTextbooks() async {
    try {
      setState(() => isLoading = true);
      allTextbooks = await _textbookService.getTextbooks();
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading textbooks: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStorybooks() async {
    try {
      allStorybooks = await _storybookService.getStorybooks();
      authors = await _storybookService.getAuthors();
      _applyStoryFilter();
    } catch (e) {
      debugPrint('Error loading storybooks: $e');
    }
  }

  Future<void> _loadEnglishTextbooks() async {
    setState(() => isLoadingEnglish = true);
    try {
      final service = EnglishTextbookService();
      englishTextbooks = await service.getAllTextbooks();
      
      debugPrint('📚 Loaded ${englishTextbooks.length} English textbooks:');
      for (final textbook in englishTextbooks) {
        debugPrint('  - ${textbook['id']}: ${textbook['title']} (${textbook['year']})');
      }
      
      // Load progress for each textbook
      for (final textbook in englishTextbooks) {
        final progress = await service.getUserProgress(textbook['id']);
        englishProgressMap[textbook['id']] = progress;
      }
      
      // Initialize filtered list
      filteredEnglishTextbooks = List.from(englishTextbooks);
    } catch (e) {
      debugPrint('❌ Error loading English textbooks: $e');
    } finally {
      setState(() => isLoadingEnglish = false);
    }
  }

  Future<void> _loadSocialRmeTextbooks() async {
    setState(() => isLoadingSocialRme = true);
    try {
      // Load Social Studies textbooks
      socialStudiesTextbooks = await _socialRmeService.getSocialStudiesTextbooks();
      debugPrint('📚 Loaded ${socialStudiesTextbooks.length} Social Studies textbooks');
      
      // Load RME textbooks
      rmeTextbooks = await _socialRmeService.getRmeTextbooks();
      debugPrint('📚 Loaded ${rmeTextbooks.length} RME textbooks');
      
      // Load progress for each textbook
      for (final textbook in [...socialStudiesTextbooks, ...rmeTextbooks]) {
        final progress = await _socialRmeService.getUserProgress(textbook['id']);
        socialRmeProgressMap[textbook['id']] = progress;
      }
      
      // Initialize filtered list - combine all
      filteredSocialRmeTextbooks = [...socialStudiesTextbooks, ...rmeTextbooks];
      
      // Apply any existing filters
      _applySocialRmeFilter();
    } catch (e) {
      debugPrint('❌ Error loading Social Studies/RME textbooks: $e');
    } finally {
      setState(() => isLoadingSocialRme = false);
    }
  }

  void _applySocialRmeFilter() {
    setState(() {
      final allSocialRme = [...socialStudiesTextbooks, ...rmeTextbooks];
      
      if (searchQuery.isEmpty && selectedLevel == 'All' && selectedSubject == 'All') {
        filteredSocialRmeTextbooks = List.from(allSocialRme);
      } else {
        filteredSocialRmeTextbooks = allSocialRme.where((book) {
          final title = (book['title'] as String? ?? '').toLowerCase();
          final year = (book['year'] as String? ?? '').toLowerCase();
          final subject = (book['subject'] as String? ?? '').toLowerCase();
          final query = searchQuery.toLowerCase().trim();
          
          // Level filter
          bool matchesLevel = selectedLevel == 'All' || year == selectedLevel.toLowerCase();
          
          // Subject filter
          bool matchesSubject = selectedSubject == 'All' || 
              subject.contains(selectedSubject.toLowerCase()) ||
              (selectedSubject.toLowerCase() == 'social studies' && subject.contains('social')) ||
              (selectedSubject.toLowerCase().contains('religious') && (subject.contains('rme') || subject.contains('religious')));
          
          // Search query filter
          bool matchesSearch = query.isEmpty || 
              title.contains(query) || 
              year.contains(query) ||
              subject.contains(query);
          
          return matchesLevel && matchesSubject && matchesSearch;
        }).toList();
      }
    });
  }

  void _onTabChanged() {
    setState(() {
      // Reset search when switching tabs
      _searchController.clear();
      searchQuery = '';
      _applyFilters();
      _applyStoryFilter();
      _applySocialRmeFilter();
    });
  }

  void _applyFilters() {
    setState(() {
      // Only show Uriel English course, hide all other textbooks
      filteredTextbooks = [];
      
      // Filter English textbooks by search query, level, and subject
      if (searchQuery.isEmpty && selectedLevel == 'All' && selectedSubject == 'All') {
        filteredEnglishTextbooks = List.from(englishTextbooks);
      } else {
        filteredEnglishTextbooks = englishTextbooks.where((book) {
          final title = (book['title'] as String? ?? '').toLowerCase();
          final year = (book['year'] as String? ?? '').toLowerCase();
          final subject = (book['subject'] as String? ?? '').toLowerCase();
          final query = searchQuery.toLowerCase().trim();
          
          // Level filter (class filter)
          bool matchesLevel = selectedLevel == 'All' || year == selectedLevel.toLowerCase();
          
          // Subject filter
          bool matchesSubject = selectedSubject == 'All' || subject == selectedSubject.toLowerCase();
          
          // Search query filter
          bool matchesSearch = true;
          if (query.isNotEmpty) {
            // More precise matching: check if query matches year exactly or is contained in title
            final normalizedYear = year.replaceAll(' ', ''); // "jhs 1" -> "jhs1"
            final normalizedQuery = query.replaceAll(' ', ''); // "jhs 1" -> "jhs1"
            
            // Exact year match (e.g., "jhs1" matches "JHS 1" but not "JHS 2")
            if (normalizedYear == normalizedQuery || year == query) {
              matchesSearch = true;
            } else {
              // Partial title match (e.g., "comprehensive" matches all)
              matchesSearch = title.contains(query);
            }
          }
          
          return matchesLevel && matchesSubject && matchesSearch;
        }).toList();
      }
    });
  }

  void _applyStoryFilter() {
    setState(() {
      filteredStorybooks = allStorybooks.where((book) {
        final matchesAuthor = selectedAuthor == 'All' || book.author == selectedAuthor;
        final matchesSearch = searchQuery.isEmpty ||
            book.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            book.author.toLowerCase().contains(searchQuery.toLowerCase());

        return matchesAuthor && matchesSearch;
      }).toList();

      // Sort alphabetically by title
      filteredStorybooks.sort((a, b) => a.title.compareTo(b.title));
    });
  }

  void _resetFilters() {
    setState(() {
      selectedLevel = 'All';
      selectedSubject = 'All';
      selectedPublisher = 'All';
      selectedAuthor = 'All';
      searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
    _applyStoryFilter();
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
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search textbooks, subjects, authors...',
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
                          _applyStoryFilter();
                          _applySocialRmeFilter();
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Chips
                    if (_tabController.index == 2) ...[
                      // Storybooks filters
                      if (isMobile) ...[
                        _buildStorybookMobileFilters(),
                      ] else ...[
                        _buildStorybookDesktopFilters(),
                      ],
                    ] else ...[
                      // Textbooks filters
                      if (isMobile) ...[
                        _buildMobileFilters(),
                      ] else ...[
                        _buildDesktopFilters(),
                      ],
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
                              _tabController.index == 2
                                  ? '${filteredStorybooks.length} storybooks found'
                                  : '${filteredTextbooks.length} textbooks found',
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
                  tabs: const [
                    Tab(text: 'All Books'),
                    Tab(text: 'Textbooks'),
                    Tab(text: 'Storybooks'),
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

            // Content
            if (isLoading && _tabController.index != 2 && _tabController.index != 3) ...[
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
                        'Loading textbooks...',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_tabController.index == 2) ...[
              // Storybooks tab content
              if (filteredStorybooks.isEmpty) ...[
                SliverFillRemaining(
                  child: _buildEmptyState(),
                ),
              ] else ...[
                SliverPadding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  sliver: isGridView
                      ? _buildStorybooksGrid(isMobile)
                      : _buildStorybooksList(isMobile),
                ),
                // Storybook pagination
                SliverToBoxAdapter(
                  child: _buildStorybookPaginationControls(),
                ),
              ],
            ] else if (_tabController.index == 1) ...[
              // Textbooks tab - show English textbooks first, then Social Studies/RME
              if (!isLoadingEnglish && filteredEnglishTextbooks.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 24,
                  ),
                  sliver: _buildEnglishTextbooksGrid(isMobile),
                ),
                // English pagination for Textbooks tab
                SliverToBoxAdapter(
                  child: _buildEnglishPaginationControls(),
                ),
              ],
              // Social Studies and RME Textbooks
              if (!isLoadingSocialRme && filteredSocialRmeTextbooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 24,
                      filteredEnglishTextbooks.isNotEmpty ? 16 : (isMobile ? 16 : 24),
                      isMobile ? 16 : 24,
                      8,
                    ),
                    child: Text(
                      'Social Studies & RME',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ),
                ),
                _buildSocialRmeTextbooksGrid(isMobile),
              ],
              if (filteredTextbooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 24,
                      filteredEnglishTextbooks.isNotEmpty || filteredSocialRmeTextbooks.isNotEmpty ? 8 : (isMobile ? 16 : 24),
                      isMobile ? 16 : 24,
                      8,
                    ),
                    child: Text(
                      'Other Textbooks',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    0,
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 24,
                  ),
                  sliver: isGridView
                      ? _buildTextbookGrid(isMobile)
                      : _buildTextbookList(isMobile),
                ),
              ],
              if (!isLoadingEnglish && !isLoadingSocialRme && filteredEnglishTextbooks.isEmpty && filteredSocialRmeTextbooks.isEmpty && filteredTextbooks.isEmpty) ...[
                SliverFillRemaining(
                  child: _buildEmptyState(),
                ),
              ],
            ] else ...[
              // All Books tab (index 0) - show English, Social Studies/RME, and other textbooks
              if (!isLoadingEnglish && filteredEnglishTextbooks.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 24,
                    isMobile ? 16 : 24,
                  ),
                  sliver: _buildEnglishTextbooksGrid(isMobile),
                ),
                // English pagination for All Books tab
                SliverToBoxAdapter(
                  child: _buildEnglishPaginationControls(),
                ),
              ],
              // Social Studies and RME Textbooks
              if (!isLoadingSocialRme && filteredSocialRmeTextbooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 24,
                      filteredEnglishTextbooks.isNotEmpty ? 16 : (isMobile ? 16 : 24),
                      isMobile ? 16 : 24,
                      8,
                    ),
                    child: Text(
                      'Social Studies & RME',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ),
                ),
                _buildSocialRmeTextbooksGrid(isMobile),
              ],
              if (filteredTextbooks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 24,
                      (filteredEnglishTextbooks.isNotEmpty || filteredSocialRmeTextbooks.isNotEmpty) ? 8 : (isMobile ? 16 : 24),
                      isMobile ? 16 : 24,
                      8,
                    ),
                    child: Text(
                      'Other Textbooks',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  sliver: isGridView
                      ? _buildTextbookGrid(isMobile)
                      : _buildTextbookList(isMobile),
                ),
              ],
              if (!isLoadingEnglish && !isLoadingSocialRme && filteredEnglishTextbooks.isEmpty && filteredSocialRmeTextbooks.isEmpty && filteredTextbooks.isEmpty) ...[
                SliverFillRemaining(
                  child: _buildEmptyState(),
                ),
              ],
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
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        // Level and Subject filters
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                'Level',
                selectedLevel,
                levels,
                (value) => setState(() {
                  selectedLevel = value!;
                  _applyFilters();
                  _applySocialRmeFilter();
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
                  _applySocialRmeFilter();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Publisher filter
        _buildFilterDropdown(
          'Publisher',
          selectedPublisher,
          publishers,
          (value) => setState(() {
            selectedPublisher = value!;
            _applyFilters();
            _applySocialRmeFilter();
          }),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            'Level',
            selectedLevel,
            levels,
            (value) => setState(() {
              selectedLevel = value!;
              _applyFilters();
              _applySocialRmeFilter();
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
              _applySocialRmeFilter();
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterDropdown(
            'Publisher',
            selectedPublisher,
            publishers,
            (value) => setState(() {
              selectedPublisher = value!;
              _applyFilters();
              _applySocialRmeFilter();
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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

  bool _hasActiveFilters() {
    if (_tabController.index == 2) {
      return selectedAuthor != 'All' || searchQuery.isNotEmpty;
    }
    return selectedLevel != 'All' ||
        selectedSubject != 'All' ||
        selectedPublisher != 'All' ||
        searchQuery.isNotEmpty;
  }

  Widget _buildStorybookMobileFilters() {
    return _buildFilterDropdown(
      'Author',
      selectedAuthor,
      ['All', ...authors],
      (value) => setState(() {
        selectedAuthor = value!;
        _applyStoryFilter();
      }),
    );
  }

  Widget _buildStorybookDesktopFilters() {
    return _buildFilterDropdown(
      'Author',
      selectedAuthor,
      ['All', ...authors],
      (value) => setState(() {
        selectedAuthor = value!;
        _applyStoryFilter();
      }),
    );
  }

  Widget _buildStorybooksGrid(bool isMobile) {
    // Pagination: 9 storybooks per page
    final startIndex = _currentStorybookPage * 9;
    final endIndex = (startIndex + 9).clamp(0, filteredStorybooks.length);
    final paginatedStorybooks = filteredStorybooks.sublist(startIndex, endIndex);
    
    final crossAxisCount = isMobile ? 2 : 3;
    
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 0.58 : 0.7,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final storybook = paginatedStorybooks[index];
          return _buildStorybookCard(storybook, isMobile);
        },
        childCount: paginatedStorybooks.length,
      ),
    );
  }

  Widget _buildStorybooksList(bool isMobile) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final storybook = filteredStorybooks[index];
          return _buildStorybookListItem(storybook, isMobile);
        },
        childCount: filteredStorybooks.length,
      ),
    );
  }

  Widget _buildStorybookCard(Storybook storybook, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openStorybook(storybook),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    // Book Cover Image
                    if (storybook.coverImageUrl != null && storybook.coverImageUrl!.startsWith('http'))
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          storybook.coverImageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1A1E3F).withValues(alpha: 0.8),
                                    const Color(0xFF1A1E3F),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to icon if image fails to load
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1A1E3F).withValues(alpha: 0.8),
                                    const Color(0xFF1A1E3F),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.auto_stories,
                                  size: isMobile ? 40 : 48,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else if (storybook.coverImageUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.asset(
                          storybook.coverImageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to icon if image fails to load
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1A1E3F).withValues(alpha: 0.8),
                                    const Color(0xFF1A1E3F),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.auto_stories,
                                  size: isMobile ? 40 : 48,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      // Fallback if no cover
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1A1E3F).withValues(alpha: 0.8),
                              const Color(0xFF1A1E3F),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.auto_stories,
                            size: isMobile ? 40 : 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    
                    // Format Badge (bottom left)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          storybook.format.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    
                    // NEW Badge (top right)
                    if (storybook.isNewRelease) ...[
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD62828),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            'NEW',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Book Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storybook.title,
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      storybook.author,
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 10 : 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (storybook.description != null && storybook.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        storybook.description!,
                        style: GoogleFonts.montserrat(
                          fontSize: isMobile ? 9 : 10,
                          color: Colors.grey[500],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            storybook.pageCount != null 
                              ? '${storybook.pageCount} pages' 
                              : storybook.fileSizeFormatted,
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.menu_book,
                          size: 16,
                          color: Color(0xFFD62828),
                        ),
                      ],
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

  Widget _buildStorybookListItem(Storybook storybook, bool isMobile) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openStorybook(storybook),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              // Cover
              Container(
                width: isMobile ? 60 : 80,
                height: isMobile ? 80 : 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1E3F).withValues(alpha: 0.8),
                      const Color(0xFF1A1E3F),
                    ],
                  ),
                ),
                child: storybook.coverImageUrl != null && storybook.coverImageUrl!.startsWith('http')
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        storybook.coverImageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_stories,
                                color: Colors.white,
                                size: isMobile ? 24 : 32,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  storybook.format.toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1E3F),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: isMobile ? 24 : 32,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            storybook.format.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1E3F),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),

              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            storybook.title,
                            style: GoogleFonts.montserrat(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1E3F),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (storybook.isNewRelease) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD62828),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${storybook.author}',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (storybook.description != null && storybook.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        storybook.description!,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            storybook.pageCount != null 
                              ? '${storybook.pageCount} pages' 
                              : storybook.fileSizeFormatted,
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${storybook.readCount} reads',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Read button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Color(0xFFD62828),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStorybook(Storybook storybook) {
    // Increment read count
    _storybookService.incrementReadCount(storybook.id);
    
    // Determine the asset path - prefer storage URL for lazy loading
    String assetPath = storybook.storageUrl != null 
        ? 'storage://${storybook.fileName}'
        : storybook.assetPath;
    
    // Open the Enhanced EPUB reader
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedEpubReaderPage(
          bookTitle: storybook.title,
          author: storybook.author,
          assetPath: assetPath,
          bookId: storybook.id,
        ),
      ),
    );
  }

  Widget _buildTextbookGrid(bool isMobile) {
    final crossAxisCount = isMobile ? 2 : 3;
    
    // Check if we're on the Textbooks tab (index 1) and should show the course
    final bool showCourseCard = _tabController.index == 1 || _tabController.index == 0; // Show in Textbooks and All Books tabs
    final int totalItems = filteredTextbooks.length + (showCourseCard ? 1 : 0);
    
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 0.58 : 0.7,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Show course card as first item
          if (showCourseCard && index == 0) {
            return _buildEnglishCourseCard(isMobile);
          }
          
          // Adjust index for textbooks
          final textbookIndex = showCourseCard ? index - 1 : index;
          final textbook = filteredTextbooks[textbookIndex];
          return _buildTextbookCard(textbook, isMobile);
        },
        childCount: totalItems,
      ),
    );
  }

  Widget _buildTextbookList(bool isMobile) {
    // Check if we're on the Textbooks tab (index 1) and should show the course
    final bool showCourseCard = _tabController.index == 1 || _tabController.index == 0; // Show in Textbooks and All Books tabs
    final int totalItems = filteredTextbooks.length + (showCourseCard ? 1 : 0);
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Show course card as first item
          if (showCourseCard && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEnglishCourseListItem(isMobile),
            );
          }
          
          // Adjust index for textbooks
          final textbookIndex = showCourseCard ? index - 1 : index;
          final textbook = filteredTextbooks[textbookIndex];
          return _buildTextbookListItem(textbook, isMobile);
        },
        childCount: totalItems,
      ),
    );
  }

  Widget _buildTextbookCard(Textbook textbook, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTextbook(textbook),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getSubjectColor(textbook.subject).withValues(alpha: 0.7),
                      _getSubjectColor(textbook.subject),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: isMobile ? 40 : 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              textbook.level,
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getSubjectColor(textbook.subject),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (textbook.isNew) ...[
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD62828),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'NEW',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Book Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textbook.title,
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textbook.author,
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 10 : 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getSubjectColor(textbook.subject).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            textbook.subject,
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _getSubjectColor(textbook.subject),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.download,
                          size: 16,
                          color: Color(0xFFD62828),
                        ),
                      ],
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

  // English Course Card - Interactive Textbook
  Widget _buildEnglishCourseCard(bool isMobile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Fetch the course and navigate
          final courseService = CourseReaderService();
          final courses = await courseService.getAllCourses();
          final englishCourse = courses.firstWhere(
            (c) => c.courseId == 'english_b7',
            orElse: () => courses.first, // Fallback to first course
          );
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseUnitListPage(
                  course: englishCourse,
                ),
              ),
            );
          }
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover with gradient - English theme
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF4A90E2).withValues(alpha: 0.8), // English blue
                          const Color(0xFF357ABD),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book,
                          size: isMobile ? 40 : 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'JHS 1',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF357ABD),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Content info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uriel English',
                          style: GoogleFonts.montserrat(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1E3F),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Interactive Course',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.school,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '10 Units • 46 Lessons',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // NEW badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NEW',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // English Course List Item - Interactive Textbook
  Widget _buildEnglishCourseListItem(bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Fetch the course and navigate
          final courseService = CourseReaderService();
          final courses = await courseService.getAllCourses();
          final englishCourse = courses.firstWhere(
            (c) => c.courseId == 'english_b7',
            orElse: () => courses.first, // Fallback to first course
          );
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseUnitListPage(
                  course: englishCourse,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              // Cover
              Container(
                width: isMobile ? 60 : 80,
                height: isMobile ? 80 : 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF4A90E2).withValues(alpha: 0.8),
                      const Color(0xFF357ABD),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book,
                      size: isMobile ? 24 : 32,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'JHS 1',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF357ABD),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Uriel English',
                            style: GoogleFonts.montserrat(
                              fontSize: isMobile ? 15 : 16,
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
                            color: const Color(0xFF34C759),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NEW',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Interactive Course',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '10 Units • 46 Lessons • 1,890 XP',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextbookListItem(Textbook textbook, bool isMobile) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTextbook(textbook),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              // Cover
              Container(
                width: isMobile ? 60 : 80,
                height: isMobile ? 80 : 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getSubjectColor(textbook.subject).withValues(alpha: 0.7),
                      _getSubjectColor(textbook.subject),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: Colors.white,
                      size: isMobile ? 24 : 32,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        textbook.level,
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _getSubjectColor(textbook.subject),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            textbook.title,
                            style: GoogleFonts.montserrat(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1E3F),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (textbook.isNew) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD62828),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${textbook.author}',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getSubjectColor(textbook.subject).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            textbook.subject,
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getSubjectColor(textbook.subject),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            textbook.publisher,
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${textbook.pages} pages',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Download button
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.download,
                  color: Color(0xFFD62828),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
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
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No textbooks found',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'No textbooks match your search criteria.\nTry adjusting your filters or search terms.'
                  : 'No textbooks available for the selected filters.\nTry selecting different options.',
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

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return const Color(0xFF2196F3);
      case 'english language':
        return const Color(0xFF4CAF50);
      case 'science':
        return const Color(0xFFFF9800);
      case 'social studies':
        return const Color(0xFF9C27B0);
      case 'ict':
        return const Color(0xFF607D8B);
      case 'religious & moral education':
        return const Color(0xFF795548);
      case 'creative arts':
        return const Color(0xFFE91E63);
      case 'french':
        return const Color(0xFF3F51B5);
      case 'twi':
        return const Color(0xFFFF5722);
      case 'ga':
        return const Color(0xFF009688);
      case 'ewe':
        return const Color(0xFF8BC34A);
      case 'technical skills':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF1A1E3F);
    }
  }

  void _openTextbook(Textbook textbook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          textbook.title,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Author: ${textbook.author}',
              style: GoogleFonts.montserrat(),
            ),
            Text(
              'Publisher: ${textbook.publisher}',
              style: GoogleFonts.montserrat(),
            ),
            Text(
              'Level: ${textbook.level}',
              style: GoogleFonts.montserrat(),
            ),
            Text(
              'Subject: ${textbook.subject}',
              style: GoogleFonts.montserrat(),
            ),
            Text(
              'Pages: ${textbook.pages}',
              style: GoogleFonts.montserrat(),
            ),
            const SizedBox(height: 16),
            Text(
              'This feature will allow you to read the full textbook online. Coming soon!',
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
            child: Text(
              'Close',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Download started for ${textbook.title}',
                    style: GoogleFonts.montserrat(),
                  ),
                  backgroundColor: const Color(0xFF1A1E3F),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: Text('Download', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  Widget _buildEnglishTextbooksGrid(bool isMobile) {
    // Mobile: Show all 3 textbooks, Desktop: Pagination with 9 per page
    final itemsPerPage = isMobile ? filteredEnglishTextbooks.length : 9;
    final startIndex = isMobile ? 0 : (_currentEnglishPage * itemsPerPage);
    final endIndex = (startIndex + itemsPerPage).clamp(0, filteredEnglishTextbooks.length);
    
    // Safely get paginated textbooks with validation
    List<Map<String, dynamic>> paginatedTextbooks = [];
    try {
      paginatedTextbooks = filteredEnglishTextbooks
          .where((book) => book['id'] != null && book['year'] != null && book['title'] != null)
          .toList()
          .sublist(startIndex, endIndex);
      
      debugPrint('📱 Mobile: $isMobile, Showing ${paginatedTextbooks.length} textbooks');
      for (var book in paginatedTextbooks) {
        debugPrint('   - ${book['id']}: ${book['title']}');
      }
    } catch (e) {
      debugPrint('❌ Error creating paginated textbooks: $e');
      paginatedTextbooks = [];
    }
    
    return SliverPadding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 3,
          childAspectRatio: isMobile ? 0.58 : 0.7,
          crossAxisSpacing: isMobile ? 12 : 16,
          mainAxisSpacing: isMobile ? 12 : 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            try {
              final textbook = paginatedTextbooks[index];
              final textbookId = textbook['id'] as String? ?? 'unknown';
              final title = textbook['title'] as String? ?? 'Unknown Title';
              final yearString = textbook['year'] as String? ?? 'JHS 1';
              
              // Extract year number for cover image (handle "JHS 1", "JHS 2", etc.)
              final match = RegExp(r'\d+').firstMatch(yearString);
              final yearNum = match != null ? int.parse(match.group(0)!) : 1;
              
              // Get progress data safely
              final progressData = englishProgressMap[textbookId] ?? {};
              
              // Safe integer extraction with defaults
              int completedSections = 0;
              int totalSections = 0;
              int totalXP = 0;
              bool isCompleted = false;
              
              try {
                completedSections = progressData['completedSections'] as int? ?? 0;
                totalSections = progressData['totalSections'] as int? ?? 0;
                totalXP = progressData['totalXP'] as int? ?? 0;
                isCompleted = progressData['isCompleted'] as bool? ?? false;
              } catch (e) {
                debugPrint('⚠️ Error parsing progress data for $textbookId: $e');
              }
              
              final progressPercent = totalSections > 0 ? (completedSections / totalSections * 100).toInt() : 0;

              // Determine book cover path
              final coverPath = 'assets/english_jhs$yearNum.webp';
              
              debugPrint('📖 Rendering textbook card: $textbookId');
              debugPrint('   Year: $yearString -> yearNum: $yearNum');
              debugPrint('   Cover path: $coverPath');
              debugPrint('   Title: $title');

              return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EnglishTextbookReaderPage(
                        year: yearString,
                        textbookId: textbookId,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book cover image
                    Expanded(
                      flex: 5, // 5:3 ratio gives more cover, text reduced
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.asset(
                              coverPath,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('\u274c Error loading $coverPath: $error');
                                return Container(
                                  color: const Color(0xFFD62828).withOpacity(0.1),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.book,
                                        size: 48,
                                        color: const Color(0xFFD62828).withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        yearString,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFD62828),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (isCompleted)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Completed',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Book details (reduced by 20% for desktop)
                    Expanded(
                      flex: isMobile ? 3 : 2, // Desktop: 5:2 (was 5:3), Mobile: 5:3
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 13 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            // Progress bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$progressPercent% Complete',
                                      style: GoogleFonts.montserrat(
                                        fontSize: isMobile ? 9 : 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.stars,
                                          size: isMobile ? 12 : 14,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$totalXP XP',
                                          style: GoogleFonts.montserrat(
                                            fontSize: isMobile ? 9 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: totalSections > 0 ? completedSections / totalSections : 0,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isCompleted ? Colors.green : const Color(0xFFD62828),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            } catch (e, stackTrace) {
              debugPrint('❌ Error rendering textbook card at index $index: $e');
              debugPrint('   Textbook data: ${paginatedTextbooks.length > index ? paginatedTextbooks[index] : "N/A"}');
              debugPrint('   Stack trace: $stackTrace');
              // Return error placeholder card with details
              return Card(
                elevation: 2,
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(
                        'Error at index $index',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.toString(),
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          childCount: paginatedTextbooks.length,
        ),
      ),
    );
  }

  Widget _buildEnglishPaginationControls() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    // Don't show pagination on mobile (all textbooks shown)
    if (isMobile) return const SizedBox();
    
    final totalPages = (filteredEnglishTextbooks.length / 9).ceil();
    if (totalPages <= 1) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: _currentEnglishPage > 0
                ? () => setState(() => _currentEnglishPage--)
                : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _currentEnglishPage > 0
                  ? const Color(0xFFD62828).withOpacity(0.1)
                  : Colors.grey[200],
              foregroundColor: _currentEnglishPage > 0
                  ? const Color(0xFFD62828)
                  : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Page numbers
          ...List.generate(totalPages.clamp(0, 5), (index) {
            final isCurrentPage = index == _currentEnglishPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _currentEnglishPage = index),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrentPage
                        ? const Color(0xFFD62828)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrentPage
                          ? const Color(0xFFD62828)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.montserrat(
                        color: isCurrentPage ? Colors.white : Colors.black87,
                        fontWeight: isCurrentPage
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 16),
          // Next button
          IconButton(
            onPressed: _currentEnglishPage < totalPages - 1
                ? () => setState(() => _currentEnglishPage++)
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _currentEnglishPage < totalPages - 1
                  ? const Color(0xFFD62828).withOpacity(0.1)
                  : Colors.grey[200],
              foregroundColor: _currentEnglishPage < totalPages - 1
                  ? const Color(0xFFD62828)
                  : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorybookPaginationControls() {
    final totalPages = (filteredStorybooks.length / 9).ceil();
    if (totalPages <= 1) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: _currentStorybookPage > 0
                ? () => setState(() => _currentStorybookPage--)
                : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _currentStorybookPage > 0
                  ? const Color(0xFFD62828).withOpacity(0.1)
                  : Colors.grey[200],
              foregroundColor: _currentStorybookPage > 0
                  ? const Color(0xFFD62828)
                  : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Page numbers
          ...List.generate(totalPages.clamp(0, 5), (index) {
            final isCurrentPage = index == _currentStorybookPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() => _currentStorybookPage = index),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrentPage
                        ? const Color(0xFFD62828)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrentPage
                          ? const Color(0xFFD62828)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.montserrat(
                        color: isCurrentPage ? Colors.white : Colors.black87,
                        fontWeight: isCurrentPage
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 16),
          // Next button
          IconButton(
            onPressed: _currentStorybookPage < totalPages - 1
                ? () => setState(() => _currentStorybookPage++)
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: _currentStorybookPage < totalPages - 1
                  ? const Color(0xFFD62828).withOpacity(0.1)
                  : Colors.grey[200],
              foregroundColor: _currentStorybookPage < totalPages - 1
                  ? const Color(0xFFD62828)
                  : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build grid of Social Studies and RME textbooks
  Widget _buildSocialRmeTextbooksGrid(bool isMobile) {
    if (filteredSocialRmeTextbooks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    return SliverPadding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 3,
          childAspectRatio: isMobile ? 0.58 : 0.7,
          crossAxisSpacing: isMobile ? 12 : 16,
          mainAxisSpacing: isMobile ? 12 : 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            try {
              final textbook = filteredSocialRmeTextbooks[index];
              final textbookId = textbook['id'] as String? ?? 'unknown';
              final title = textbook['title'] as String? ?? 'Unknown Title';
              final subject = textbook['subject'] as String? ?? 'Social Studies';
              final yearString = textbook['year'] as String? ?? 'JHS 1';
              final coverImage = textbook['coverImage'] as String? ?? '';
              final totalChapters = textbook['totalChapters'] as int? ?? 0;
              final totalSections = textbook['totalSections'] as int? ?? 0;
              
              // Get progress data
              final progressData = socialRmeProgressMap[textbookId] ?? {};
              final completedSections = (progressData['completedSections'] as List?)?.length ?? 0;
              final totalXP = progressData['totalXP'] as int? ?? 0;
              final progressPercent = totalSections > 0 ? (completedSections / totalSections * 100).toInt() : 0;
              final isCompleted = completedSections >= totalSections && totalSections > 0;
              
              // Get subject color
              final subjectColor = subject.toLowerCase().contains('social') 
                  ? const Color(0xFF9C27B0)  // Purple for Social Studies
                  : const Color(0xFF795548); // Brown for RME

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SocialRmeTextbookReaderPage(
                          textbookId: textbookId,
                          subject: subject,
                          year: yearString,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book cover image
                      Expanded(
                        flex: 5,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: coverImage.isNotEmpty
                                  ? Image.asset(
                                      coverImage,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: subjectColor.withOpacity(0.1),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                subject.toLowerCase().contains('social')
                                                    ? Icons.public
                                                    : Icons.church,
                                                size: 48,
                                                color: subjectColor.withOpacity(0.5),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                yearString,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: subjectColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: subjectColor.withOpacity(0.1),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            subject.toLowerCase().contains('social')
                                                ? Icons.public
                                                : Icons.church,
                                            size: 48,
                                            color: subjectColor.withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            yearString,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: subjectColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            // NEW badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'NEW',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isCompleted)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Done',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Book details
                      Expanded(
                        flex: isMobile ? 3 : 2,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Subject badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: subjectColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  subject,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: subjectColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title,
                                style: GoogleFonts.montserrat(
                                  fontSize: isMobile ? 11 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              // Progress and XP
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$totalChapters chapters',
                                        style: GoogleFonts.montserrat(
                                          fontSize: isMobile ? 8 : 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.stars,
                                            size: isMobile ? 12 : 14,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '$totalXP XP',
                                            style: GoogleFonts.montserrat(
                                              fontSize: isMobile ? 8 : 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: progressPercent / 100,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isCompleted ? Colors.green : subjectColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              debugPrint('❌ Error rendering Social/RME textbook: $e');
              return const Card(
                child: Center(
                  child: Icon(Icons.error, color: Colors.red),
                ),
              );
            }
          },
          childCount: filteredSocialRmeTextbooks.length,
        ),
      ),
    );
  }
}
