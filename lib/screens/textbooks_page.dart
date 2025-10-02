import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/textbook_model.dart';
import '../services/textbook_service.dart';

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
  final TextEditingController _searchController = TextEditingController();

  String selectedLevel = 'All';
  String selectedSubject = 'All';
  String selectedPublisher = 'All';
  String searchQuery = '';
  bool isGridView = true;

  List<Textbook> allTextbooks = [];
  List<Textbook> filteredTextbooks = [];
  bool isLoading = true;

  final List<String> levels = ['All', 'JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3'];
  final List<String> subjects = [
    'All', 'Mathematics', 'English Language', 'Science', 'Social Studies',
    'ICT', 'Religious & Moral Education', 'Creative Arts', 'French',
    'Twi', 'Ga', 'Ewe', 'Technical Skills'
  ];
  final List<String> publishers = [
    'All', 'Unimax Macmillan', 'Sedco Publishing', 'Sam-Woode Publishers',
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
    
    _loadTextbooks();
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

  void _applyFilters() {
    setState(() {
      filteredTextbooks = allTextbooks.where((textbook) {
        final matchesLevel = selectedLevel == 'All' || textbook.level == selectedLevel;
        final matchesSubject = selectedSubject == 'All' || textbook.subject == selectedSubject;
        final matchesPublisher = selectedPublisher == 'All' || textbook.publisher == selectedPublisher;
        final matchesSearch = searchQuery.isEmpty ||
            textbook.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            textbook.subject.toLowerCase().contains(searchQuery.toLowerCase()) ||
            textbook.author.toLowerCase().contains(searchQuery.toLowerCase());

        return matchesLevel && matchesSubject && matchesPublisher && matchesSearch;
      }).toList();

      // Sort by relevance and level
      filteredTextbooks.sort((a, b) {
        if (selectedLevel != 'All') {
          return a.level.compareTo(b.level);
        }
        return a.subject.compareTo(b.subject);
      });
    });
  }

  void _resetFilters() {
    setState(() {
      selectedLevel = 'All';
      selectedSubject = 'All';
      selectedPublisher = 'All';
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
            // App Bar
            SliverAppBar(
              expandedHeight: isMobile ? 100 : 120,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1E3F),
              title: Text(
                'Digital Textbooks',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              centerTitle: false,
              titleSpacing: isMobile ? 16 : 24,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8FAFE)],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    isGridView ? Icons.view_list : Icons.grid_view,
                    color: const Color(0xFF1A1E3F),
                  ),
                  onPressed: () => setState(() => isGridView = !isGridView),
                ),
                const SizedBox(width: 8),
              ],
            ),

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
                          Icon(Icons.filter_list, 
                              size: 16, 
                              color: const Color(0xFFD62828)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${filteredTextbooks.length} textbooks found',
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
                    Tab(text: 'Recently Added'),
                    Tab(text: 'Popular'),
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
            ] else if (filteredTextbooks.isEmpty) ...[
              SliverFillRemaining(
                child: _buildEmptyState(),
              ),
            ] else ...[
              SliverPadding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                sliver: isGridView
                    ? _buildTextbookGrid(isMobile)
                    : _buildTextbookList(isMobile),
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
        // Publisher filter
        _buildFilterDropdown(
          'Publisher',
          selectedPublisher,
          publishers,
          (value) => setState(() {
            selectedPublisher = value!;
            _applyFilters();
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
            'Publisher',
            selectedPublisher,
            publishers,
            (value) => setState(() {
              selectedPublisher = value!;
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

  bool _hasActiveFilters() {
    return selectedLevel != 'All' ||
        selectedSubject != 'All' ||
        selectedPublisher != 'All' ||
        searchQuery.isNotEmpty;
  }

  Widget _buildTextbookGrid(bool isMobile) {
    final crossAxisCount = isMobile ? 2 : 4;
    
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 0.7 : 0.75,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final textbook = filteredTextbooks[index];
          return _buildTextbookCard(textbook, isMobile);
        },
        childCount: filteredTextbooks.length,
      ),
    );
  }

  Widget _buildTextbookList(bool isMobile) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final textbook = filteredTextbooks[index];
          return _buildTextbookListItem(textbook, isMobile);
        },
        childCount: filteredTextbooks.length,
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
                      _getSubjectColor(textbook.subject).withOpacity(0.7),
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
                              color: Colors.white.withOpacity(0.9),
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
                            color: _getSubjectColor(textbook.subject).withOpacity(0.1),
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
                        Icon(
                          Icons.download,
                          size: 16,
                          color: const Color(0xFFD62828),
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
                      _getSubjectColor(textbook.subject).withOpacity(0.7),
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
                        color: Colors.white.withOpacity(0.9),
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
                            color: _getSubjectColor(textbook.subject).withOpacity(0.1),
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
                            color: Colors.grey.withOpacity(0.1),
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
                  color: const Color(0xFFD62828).withOpacity(0.1),
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
                color: Colors.grey.withOpacity(0.1),
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
}
