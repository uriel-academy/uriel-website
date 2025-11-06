import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/performance_data.dart';
import '../services/grade_prediction_service.dart';

class GradePredictionCard extends StatefulWidget {
  final String? userId;
  final bool isCompact;

  const GradePredictionCard({
    Key? key,
    this.userId,
    this.isCompact = false,
  }) : super(key: key);

  @override
  State<GradePredictionCard> createState() => _GradePredictionCardState();
}

class _GradePredictionCardState extends State<GradePredictionCard> {
  final GradePredictionService _predictionService = GradePredictionService();
  Map<String, GradePrediction>? _predictions;
  bool _isLoading = true;
  String? _error;
  String _selectedSubject = 'religiousMoralEducation';

  final Map<String, String> _subjectLabels = {
    'religiousMoralEducation': 'RME',
    'ict': 'ICT',
    'mathematics': 'Mathematics',
    'english': 'English',
    'science': 'Science',
    'social_studies': 'Social Studies',
  };

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      final predictions = await _predictionService.predictAllGrades(
        userId: userId,
        subjects: _subjectLabels.keys.toList(),
      );

      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load predictions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1E3F),
              const Color(0xFF2A3150),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_isLoading)
                _buildLoadingState()
              else if (_error != null)
                _buildErrorState()
              else if (_predictions != null && _predictions!.isNotEmpty)
                widget.isCompact ? _buildCompactView() : _buildFullView()
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.trending_up,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BECE Grade Predictions',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI-powered performance forecasting',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadPredictions,
          tooltip: 'Refresh predictions',
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Analyzing your performance...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPredictions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              'Start practicing to see your predictions!',
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView() {
    // Show only top 3 subjects or selected subject
    final topSubjects = _predictions!.entries.take(3).toList();

    return Column(
      children: [
        ...topSubjects.map((entry) {
          final prediction = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSubjectPreview(entry.key, prediction),
          );
        }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            // Navigate to full view or expand
            setState(() {
              // Toggle compact mode via parent or navigate
            });
          },
          icon: const Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
          label: Text(
            'View All Subjects',
            style: GoogleFonts.montserrat(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullView() {
    return Column(
      children: [
        // Subject selector
        _buildSubjectSelector(),
        const SizedBox(height: 20),
        
        // Selected subject detailed prediction
        if (_predictions!.containsKey(_selectedSubject))
          _buildDetailedPrediction(_predictions![_selectedSubject]!),
        
        const SizedBox(height: 20),
        
        // All subjects overview
        _buildAllSubjectsOverview(),
      ],
    );
  }

  Widget _buildSubjectSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _subjectLabels.entries.map((entry) {
          final isSelected = entry.key == _selectedSubject;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedSubject = entry.key);
                }
              },
              selectedColor: const Color(0xFFD62828),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailedPrediction(GradePrediction prediction) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Grade display
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: prediction.gradeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: prediction.gradeColor, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Grade',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${prediction.predictedGrade}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.gradeLabel,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getTrendIcon(prediction.improvementTrend),
                          color: _getTrendColor(prediction.improvementTrend),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${prediction.predictedScore.toStringAsFixed(1)}%',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildConfidenceBadge(prediction),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Consistency',
                '${(prediction.studyConsistency * 100).toStringAsFixed(0)}%',
                Icons.calendar_today,
              ),
              _buildStatItem(
                'Trend',
                prediction.improvementTrend > 0 ? '+${(prediction.improvementTrend * 100).toStringAsFixed(0)}%' : '${(prediction.improvementTrend * 100).toStringAsFixed(0)}%',
                _getTrendIcon(prediction.improvementTrend),
              ),
              _buildStatItem(
                'Confidence',
                prediction.confidenceLevel,
                Icons.psychology,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          
          // Weak topics
          if (prediction.weakTopics.isNotEmpty) ...[
            _buildTopicsSection('Focus Areas', prediction.weakTopics, Colors.orange),
            const SizedBox(height: 12),
          ],
          
          // Strong topics
          if (prediction.strongTopics.isNotEmpty) ...[
            _buildTopicsSection('Strong Topics', prediction.strongTopics, Colors.green),
            const SizedBox(height: 12),
          ],
          
          // Recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD62828).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFD62828).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prediction.recommendation,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPreview(String subjectKey, GradePrediction prediction) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: prediction.gradeColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: prediction.gradeColor, width: 1.5),
            ),
            child: Center(
              child: Text(
                '${prediction.predictedGrade}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _subjectLabels[subjectKey] ?? subjectKey,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prediction.gradeLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _getTrendIcon(prediction.improvementTrend),
            color: _getTrendColor(prediction.improvementTrend),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAllSubjectsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Subjects Overview',
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ..._predictions!.entries.map((entry) {
          if (entry.key == _selectedSubject) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSubjectPreview(entry.key, entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildConfidenceBadge(GradePrediction prediction) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: prediction.confidenceColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: prediction.confidenceColor, width: 1),
      ),
      child: Text(
        '${prediction.confidenceLevel} Confidence',
        style: GoogleFonts.montserrat(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildTopicsSection(String title, List<String> topics, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              title.contains('Focus') ? Icons.error_outline : Icons.star,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: topics.take(5).map((topic) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text(
                topic,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getTrendIcon(double trend) {
    if (trend > 0.1) return Icons.trending_up;
    if (trend < -0.1) return Icons.trending_down;
    return Icons.trending_flat;
  }

  Color _getTrendColor(double trend) {
    if (trend > 0.1) return Colors.green;
    if (trend < -0.1) return Colors.red;
    return Colors.orange;
  }
}
