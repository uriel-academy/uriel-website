import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/course_models.dart';
import '../services/course_reader_service.dart';
import 'lesson_reader_page.dart';

/// Apple-inspired Course Unit List Page
class CourseUnitListPage extends StatefulWidget {
  final Course course;

  const CourseUnitListPage({
    super.key,
    required this.course,
  });

  @override
  State<CourseUnitListPage> createState() => _CourseUnitListPageState();
}

class _CourseUnitListPageState extends State<CourseUnitListPage> {
  final CourseReaderService _service = CourseReaderService();
  List<CourseUnit> _units = [];
  Map<String, UnitProgress> _progressMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _loading = true);
    
    final units = await _service.getCourseUnits(widget.course.courseId);
    
    // Load progress for each unit
    final Map<String, UnitProgress> progressMap = {};
    for (var unit in units) {
      final progress = await _service.getUnitProgress(
        widget.course.courseId,
        unit.unitId,
      );
      if (progress != null) {
        progressMap[unit.unitId] = progress;
      }
    }

    setState(() {
      _units = units;
      _progressMap = progressMap;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          // Apple-style App Bar with Course Info
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: _getCourseColor(widget.course.subject),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.course.title,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 18 : 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              titlePadding: EdgeInsets.only(
                left: isSmallScreen ? 56 : 72,
                bottom: 16,
                right: 16,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCourseColor(widget.course.subject),
                      _getCourseColor(widget.course.subject).withOpacity(0.7),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isSmallScreen ? 16 : 24,
                    right: isSmallScreen ? 16 : 24,
                    top: 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.course.level ?? 'JHS 1',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_units.length} Units',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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

          // Unit List
          if (!_loading)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: 16,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final unit = _units[index];
                    final progress = _progressMap[unit.unitId];
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _UnitCard(
                        unit: unit,
                        unitNumber: index + 1,
                        progress: progress,
                        onTap: () => _openUnit(unit),
                      ),
                    );
                  },
                  childCount: _units.length,
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

  void _openUnit(CourseUnit unit) {
    if (unit.lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This unit has no lessons yet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to first lesson
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonReaderPage(
          course: widget.course,
          unit: unit,
          lesson: unit.lessons.first,
        ),
      ),
    ).then((_) => _loadUnits()); // Refresh progress on return
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
}

/// Unit Card Widget
class _UnitCard extends StatelessWidget {
  final CourseUnit unit;
  final int unitNumber;
  final UnitProgress? progress;
  final VoidCallback onTap;

  const _UnitCard({
    required this.unit,
    required this.unitNumber,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completionRate = progress?.completionRate ?? 0.0;
    final isCompleted = completionRate >= 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isCompleted
                ? Border.all(color: const Color(0xFF34C759), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Unit Number Badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF34C759)
                          : const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : Text(
                              '$unitNumber',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title & Lessons Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.title,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${unit.lessons.length} lessons · ${unit.xpTotal} XP',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow Icon
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),

              // Progress Bar (if started)
              if (progress != null && completionRate > 0) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completionRate,
                    backgroundColor: const Color(0xFFE5E5EA),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted
                          ? const Color(0xFF34C759)
                          : const Color(0xFF007AFF),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${(completionRate * 100).toStringAsFixed(0)}% complete',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${progress!.xpEarned} / ${unit.xpTotal} XP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                  ],
                ),
              ],

              // Overview (collapsed)
              if (unit.overview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  unit.overview,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF8E8E93),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Duration
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '~${unit.estimatedDurationMin} minutes',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF8E8E93),
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
}
