import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/course_models.dart';
import '../services/course_reader_service.dart';
import 'course_unit_list_page.dart';

/// Apple-inspired Course Library Page
class CourseLibraryPage extends StatefulWidget {
  const CourseLibraryPage({super.key});

  @override
  State<CourseLibraryPage> createState() => _CourseLibraryPageState();
}

class _CourseLibraryPageState extends State<CourseLibraryPage> {
  final CourseReaderService _service = CourseReaderService();
  List<Course> _courses = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    final courses = await _service.getAllCourses();
    setState(() {
      _courses = courses;
      _loading = false;
    });
  }

  List<Course> get _filteredCourses {
    if (_searchQuery.isEmpty) return _courses;
    return _courses.where((course) {
      return course.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          // Apple-style App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1C1C1E)),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Books',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              titlePadding: EdgeInsets.only(
                left: isSmallScreen ? 56 : 72,
                bottom: 16,
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: 16,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search courses...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF8E8E93),
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 15),
                ),
              ),
            ),
          ),

          // Loading State
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF007AFF),
                ),
              ),
            ),

          // Empty State
          if (!_loading && _filteredCourses.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty ? 'No courses available' : 'No courses found',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Course Grid
          if (!_loading && _filteredCourses.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: 8,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isSmallScreen ? 1 : (screenWidth < 1024 ? 2 : 3),
                  childAspectRatio: isSmallScreen ? 1.5 : 1.3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _CourseCard(
                      course: _filteredCourses[index],
                      onTap: () => _openCourse(_filteredCourses[index]),
                    );
                  },
                  childCount: _filteredCourses.length,
                ),
              ),
            ),

          // Bottom Spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  void _openCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseUnitListPage(course: course),
      ),
    );
  }
}

/// Course Card Widget
class _CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCourseColor(course.subject),
                      _getCourseColor(course.subject).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Stack(
                  children: [
                    // Subject Icon
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Icon(
                        _getCourseIcon(course.subject),
                        size: 48,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    // Level Badge
                    if (course.level != null)
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            course.level!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        course.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1C1C1E),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Description
                      Expanded(
                        child: Text(
                          course.description,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8E8E93),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Stats Row
                      Row(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${course.totalUnits} units',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                          const Spacer(),
                          // Arrow Icon
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey.shade400,
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
      ),
    );
  }

  Color _getCourseColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'english':
        return const Color(0xFF007AFF);
      case 'mathematics':
        return const Color(0xFFFF9500);
      case 'science':
        return const Color(0xFF34C759);
      case 'social studies':
        return const Color(0xFF5856D6);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  IconData _getCourseIcon(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'english':
        return Icons.menu_book;
      case 'mathematics':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'social studies':
        return Icons.public;
      default:
        return Icons.book;
    }
  }
}
