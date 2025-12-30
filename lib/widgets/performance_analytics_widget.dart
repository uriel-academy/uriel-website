import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget displaying Firebase Analytics performance data for admin dashboard
class PerformanceAnalyticsWidget extends StatefulWidget {
  const PerformanceAnalyticsWidget({Key? key}) : super(key: key);

  @override
  State<PerformanceAnalyticsWidget> createState() => _PerformanceAnalyticsWidgetState();
}

class _PerformanceAnalyticsWidgetState extends State<PerformanceAnalyticsWidget> {
  String _selectedTimeRange = '24h';
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      // In a real implementation, this would query Firebase Analytics
      // For now, we'll simulate with mock data
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _analyticsData = {
          'app_startup': {
            'avg_duration_ms': 2847,
            'max_duration_ms': 4521,
            'min_duration_ms': 1823,
            'slow_count': 12,
            'total_count': 156,
          },
          'bottlenecks': {
            'total_detected': 23,
            'critical': 5,
            'warning': 18,
            'operations': [
              {'name': 'quiz_generation', 'avg_ms': 3421, 'count': 34},
              {'name': 'firestore_complex_query', 'avg_ms': 2891, 'count': 67},
              {'name': 'image_upload', 'avg_ms': 3156, 'count': 23},
            ],
          },
          'firestore_queries': {
            'total_count': 2654,
            'slow_queries': 47,
            'avg_duration_ms': 456,
            'collections': {
              'questions': {'count': 892, 'avg_ms': 423},
              'users': {'count': 567, 'avg_ms': 234},
              'answers': {'count': 1195, 'avg_ms': 567},
            },
          },
          'network_requests': {
            'total_count': 1258,
            'slow_requests': 34,
            'failed_requests': 12,
            'avg_duration_ms': 1847,
            'endpoints': {
              'aiChatHttp': {'count': 234, 'avg_ms': 2341, 'errors': 8},
              'generateQuiz': {'count': 156, 'avg_ms': 1923, 'errors': 3},
              'findSimilarQuestion': {'count': 868, 'avg_ms': 1456, 'errors': 1},
            },
          },
          'errors': {
            'total_count': 68,
            'api_errors': 23,
            'firestore_errors': 12,
            'ui_errors': 33,
            'recent_errors': [
              {'type': 'ApiError', 'message': 'Request timeout', 'count': 8},
              {'type': 'FirestoreError', 'message': 'Permission denied', 'count': 5},
              {'type': 'UIError', 'message': 'Widget not mounted', 'count': 12},
            ],
          },
          'screen_engagement': {
            'most_visited': [
              {'screen': 'HomePage', 'visits': 2341, 'avg_duration_s': 145},
              {'screen': 'QuizPage', 'visits': 1823, 'avg_duration_s': 423},
              {'screen': 'RevisionPage', 'visits': 1456, 'avg_duration_s': 312},
            ],
            'longest_engagement': [
              {'screen': 'TheoryQuestionViewer', 'avg_duration_s': 678},
              {'screen': 'NoteViewerPage', 'avg_duration_s': 534},
              {'screen': 'QuizPage', 'avg_duration_s': 423},
            ],
          },
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with time range selector
        Row(
          children: [
            Text(
              'Performance Analytics',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const Spacer(),
            _buildTimeRangeSelector(),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Column(
            children: [
              // Key metrics row
              _buildKeyMetricsRow(),
              const SizedBox(height: 16),

              // Bottlenecks and errors
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildBottlenecksCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildErrorsCard()),
                ],
              ),
              const SizedBox(height: 16),

              // Performance details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildFirestorePerformanceCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildNetworkPerformanceCard()),
                ],
              ),
              const SizedBox(height: 16),

              // Screen engagement
              _buildScreenEngagementCard(),
            ],
          ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeRangeButton('24h'),
          _buildTimeRangeButton('7d'),
          _buildTimeRangeButton('30d'),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String range) {
    final isSelected = _selectedTimeRange == range;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTimeRange = range);
        _loadAnalyticsData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
              : null,
        ),
        child: Text(
          range,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF1A1E3F) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Avg Startup',
            '${_analyticsData['app_startup']['avg_duration_ms']}ms',
            _analyticsData['app_startup']['avg_duration_ms'] < 3000
                ? Icons.check_circle
                : Icons.warning,
            _analyticsData['app_startup']['avg_duration_ms'] < 3000
                ? const Color(0xFF2ECC71)
                : const Color(0xFFF39C12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Bottlenecks',
            '${_analyticsData['bottlenecks']['total_detected']}',
            Icons.speed,
            _analyticsData['bottlenecks']['critical'] > 0
                ? const Color(0xFFE74C3C)
                : const Color(0xFF2ECC71),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Slow Queries',
            '${_analyticsData['firestore_queries']['slow_queries']}',
            Icons.storage,
            const Color(0xFF3498DB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Errors',
            '${_analyticsData['errors']['total_count']}',
            Icons.error_outline,
            const Color(0xFFE74C3C),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottlenecksCard() {
    final bottlenecks = _analyticsData['bottlenecks'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 20, color: Color(0xFFE74C3C)),
              const SizedBox(width: 8),
              Text(
                'Performance Bottlenecks',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${bottlenecks['critical']} Critical',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE74C3C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            (bottlenecks['operations'] as List).length,
            (index) {
              final op = bottlenecks['operations'][index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            op['name'],
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1E3F),
                            ),
                          ),
                        ),
                        Text(
                          '${op['avg_ms']}ms',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE74C3C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: op['avg_ms'] / 5000,
                              backgroundColor: Colors.grey.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                op['avg_ms'] > 3000
                                    ? const Color(0xFFE74C3C)
                                    : const Color(0xFFF39C12),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${op['count']} calls',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsCard() {
    final errors = _analyticsData['errors'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 20, color: Color(0xFFE74C3C)),
              const SizedBox(width: 8),
              Text(
                'Error Tracking',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildErrorTypeChip('API', errors['api_errors']),
              const SizedBox(width: 8),
              _buildErrorTypeChip('Firestore', errors['firestore_errors']),
              const SizedBox(width: 8),
              _buildErrorTypeChip('UI', errors['ui_errors']),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            (errors['recent_errors'] as List).length,
            (index) {
              final error = errors['recent_errors'][index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE74C3C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            error['type'],
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1E3F),
                            ),
                          ),
                          Text(
                            error['message'],
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '×${error['count']}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1E3F),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorTypeChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE74C3C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirestorePerformanceCard() {
    final firestore = _analyticsData['firestore_queries'];
    final collections = firestore['collections'] as Map<String, dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, size: 20, color: Color(0xFF3498DB)),
              const SizedBox(width: 8),
              Text(
                'Firestore Performance',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Queries', '${firestore['total_count']}'),
              ),
              Expanded(
                child: _buildStatItem('Avg Time', '${firestore['avg_duration_ms']}ms'),
              ),
              Expanded(
                child: _buildStatItem('Slow Queries', '${firestore['slow_queries']}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ...collections.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value['count']} queries',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${entry.value['avg_ms']}ms',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3498DB),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNetworkPerformanceCard() {
    final network = _analyticsData['network_requests'];
    final endpoints = network['endpoints'] as Map<String, dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud, size: 20, color: Color(0xFF9B59B6)),
              const SizedBox(width: 8),
              Text(
                'Network Performance',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Requests', '${network['total_count']}'),
              ),
              Expanded(
                child: _buildStatItem('Avg Time', '${network['avg_duration_ms']}ms'),
              ),
              Expanded(
                child: _buildStatItem('Failures', '${network['failed_requests']}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ...endpoints.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                  ),
                  if (entry.value['errors'] > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${entry.value['errors']} err',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE74C3C),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${entry.value['avg_ms']}ms',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9B59B6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1E3F),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenEngagementCard() {
    final engagement = _analyticsData['screen_engagement'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.screen_share, size: 20, color: Color(0xFF2ECC71)),
              const SizedBox(width: 8),
              Text(
                'Screen Engagement',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Most Visited Screens',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      (engagement['most_visited'] as List).length,
                      (index) {
                        final screen = engagement['most_visited'][index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2ECC71),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  screen['screen'],
                                  style: GoogleFonts.sourceCodePro(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1E3F),
                                  ),
                                ),
                              ),
                              Text(
                                '${screen['visits']} visits',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Longest Engagement',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      (engagement['longest_engagement'] as List).length,
                      (index) {
                        final screen = engagement['longest_engagement'][index];
                        final minutes = (screen['avg_duration_s'] / 60).floor();
                        final seconds = screen['avg_duration_s'] % 60;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  screen['screen'],
                                  style: GoogleFonts.sourceCodePro(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1E3F),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${minutes}m ${seconds}s',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2ECC71),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
