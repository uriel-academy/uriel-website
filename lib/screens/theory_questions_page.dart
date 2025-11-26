import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theory_year_questions_list.dart';

class TheoryQuestionsPage extends StatefulWidget {
  const TheoryQuestionsPage({super.key});

  @override
  State<TheoryQuestionsPage> createState() => _TheoryQuestionsPageState();
}

class _TheoryQuestionsPageState extends State<TheoryQuestionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedSubject = 'all';
  bool _isLoading = true;

  List<String> _subjects = [];
  Map<String, List<int>> _subjectYears = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Get all theory questions to organize by subject and year
      final snapshot =
          await _firestore.collection('theoryQuestions').get();

      final subjects = <String>{};
      final yearsBySubject = <String, Set<int>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final subjectDisplay = data['subjectDisplay'] as String?;
        final year = data['year'] as int?;

        if (subjectDisplay != null && year != null) {
          subjects.add(subjectDisplay);
          yearsBySubject.putIfAbsent(subjectDisplay, () => <int>{});
          yearsBySubject[subjectDisplay]!.add(year);
        }
      }

      setState(() {
        _subjects = subjects.toList()..sort();
        _subjectYears = yearsBySubject.map((subject, years) {
          final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
          return MapEntry(subject, sortedYears);
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  List<int> _getFilteredYears() {
    if (_selectedSubject == 'all') {
      // Get all unique years across all subjects
      final allYears = <int>{};
      for (var years in _subjectYears.values) {
        allYears.addAll(years);
      }
      final sortedYears = allYears.toList()..sort((a, b) => b.compareTo(a));
      return sortedYears;
    } else {
      return _subjectYears[_selectedSubject] ?? [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theory Questions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Subject filter
                _buildSubjectFilter(),
                const Divider(height: 1),

                // Year collections list
                Expanded(
                  child: _buildYearsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSubjectFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedSubject,
        decoration: const InputDecoration(
          labelText: 'Subject',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All Subjects')),
          ..._subjects.map((subject) => DropdownMenuItem(
                value: subject,
                child: Text(subject),
              )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedSubject = value!;
          });
        },
      ),
    );
  }

  Widget _buildYearsList() {
    final years = _getFilteredYears();

    if (years.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No theory questions found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different subject',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        return _buildYearCard(year);
      },
    );
  }

  Widget _buildYearCard(int year) {
    // Count questions for this year (and subject if filtered)
    return FutureBuilder<int>(
      future: _getQuestionCount(year),
      builder: (context, snapshot) {
        final questionCount = snapshot.data ?? 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: questionCount > 0
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TheoryYearQuestionsList(
                          subject: _selectedSubject == 'all' ? null : _selectedSubject,
                          year: year,
                        ),
                      ),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BECE ${_selectedSubject == 'all' ? 'Theory' : _selectedSubject} $year',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          snapshot.hasData
                              ? '$questionCount question${questionCount == 1 ? '' : 's'}'
                              : 'Loading...',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<int> _getQuestionCount(int year) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection('theoryQuestions').where('year', isEqualTo: year);

      if (_selectedSubject != 'all') {
        query = query.where('subjectDisplay', isEqualTo: _selectedSubject);
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
