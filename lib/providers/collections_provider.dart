import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_collection_model.dart';
import '../models/question_model.dart';
import '../services/question_service.dart';

// Filter State Model
class CollectionFilters {
  final String questionType;
  final String subject;
  final String topic;
  final String year;
  final String searchQuery;
  final bool randomizeQuestions;

  const CollectionFilters({
    this.questionType = 'All Types',
    this.subject = 'All Subjects',
    this.topic = 'All Topics',
    this.year = 'All Years',
    this.searchQuery = '',
    this.randomizeQuestions = false,
  });

  bool get isActive =>
      questionType != 'All Types' ||
      subject != 'All Subjects' ||
      topic != 'All Topics' ||
      year != 'All Years' ||
      searchQuery.isNotEmpty;

  CollectionFilters copyWith({
    String? questionType,
    String? subject,
    String? topic,
    String? year,
    String? searchQuery,
    bool? randomizeQuestions,
  }) {
    return CollectionFilters(
      questionType: questionType ?? this.questionType,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      year: year ?? this.year,
      searchQuery: searchQuery ?? this.searchQuery,
      randomizeQuestions: randomizeQuestions ?? this.randomizeQuestions,
    );
  }

  // Save filters to SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('filter_questionType', questionType);
      await prefs.setString('filter_subject', subject);
      await prefs.setString('filter_topic', topic);
      await prefs.setString('filter_year', year);
      await prefs.setBool('randomize_questions', randomizeQuestions);
    } catch (e) {
      print('⚠️ Could not save filters: $e');
    }
  }

  // Load filters from SharedPreferences
  static Future<CollectionFilters> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return CollectionFilters(
        questionType: prefs.getString('filter_questionType') ?? 'All Types',
        subject: prefs.getString('filter_subject') ?? 'All Subjects',
        topic: prefs.getString('filter_topic') ?? 'All Topics',
        year: prefs.getString('filter_year') ?? 'All Years',
        randomizeQuestions: prefs.getBool('randomize_questions') ?? false,
      );
    } catch (e) {
      print('⚠️ Could not load filters: $e');
      return const CollectionFilters();
    }
  }
}

// Collections State
class CollectionsState {
  final List<QuestionCollection> collections;
  final List<QuestionCollection> filteredCollections;
  final bool isLoading;
  final String? error;
  final CollectionFilters filters;
  final int currentPage;
  final int pageSize;

  const CollectionsState({
    this.collections = const [],
    this.filteredCollections = const [],
    this.isLoading = false,
    this.error,
    this.filters = const CollectionFilters(),
    this.currentPage = 0,
    this.pageSize = 12,
  });

  CollectionsState copyWith({
    List<QuestionCollection>? collections,
    List<QuestionCollection>? filteredCollections,
    bool? isLoading,
    String? error,
    CollectionFilters? filters,
    int? currentPage,
    int? pageSize,
  }) {
    return CollectionsState(
      collections: collections ?? this.collections,
      filteredCollections: filteredCollections ?? this.filteredCollections,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filters: filters ?? this.filters,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  List<QuestionCollection> get paginatedCollections {
    final startIndex = currentPage * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filteredCollections.length);
    if (startIndex >= filteredCollections.length) return [];
    return filteredCollections.sublist(startIndex, endIndex);
  }

  bool get hasMorePages => (currentPage + 1) * pageSize < filteredCollections.length;
}

// Collections StateNotifier
class CollectionsNotifier extends StateNotifier<CollectionsState> {
  final QuestionService _questionService;

  CollectionsNotifier(this._questionService) : super(const CollectionsState()) {
    loadCollections();
    _loadSavedFilters();
  }

  Future<void> _loadSavedFilters() async {
    final filters = await CollectionFilters.load();
    state = state.copyWith(filters: filters);
    applyFilters();
  }

  Future<void> loadCollections() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      print('🚀 Loading collection metadata from Firestore...');
      final collectionsData = await _questionService.getQuestionCollections(activeOnly: true);
      print('📚 Found ${collectionsData.length} collections');

      final allCollections = <QuestionCollection>[];
      for (final data in collectionsData) {
        try {
          // Skip inactive collections (already filtered by service)
          allCollections.add(QuestionCollection(
            id: data['id'] as String,
            title: data['title'] as String,
            subject: Subject.values.firstWhere(
              (s) => s.name == data['subject'],
              orElse: () => Subject.mathematics,
            ),
            examType: ExamType.values.firstWhere(
              (e) => e.name == data['examType'],
              orElse: () => ExamType.bece,
            ),
            year: data['year'] as String,
            questionType: QuestionType.values.firstWhere(
              (q) => q.name == data['questionType'],
              orElse: () => QuestionType.multipleChoice,
            ),
            questionCount: data['questionCount'] as int,
            description: data['description'] as String?,
            imageUrl: data['imageUrl'] as String?,
            questions: [], // Empty for now, load on demand
            questionIds: (data['questionIds'] as List?)?.cast<String>(),
          ));
        } catch (e) {
          print('⚠️ Error parsing collection: $e');
        }
      }

      allCollections.sort((a, b) => b.year.compareTo(a.year));
      
      state = state.copyWith(
        collections: allCollections,
        isLoading: false,
      );
      
      applyFilters();
    } catch (e) {
      print('❌ Error loading collections: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void updateFilters(CollectionFilters newFilters) {
    state = state.copyWith(filters: newFilters, currentPage: 0);
    newFilters.save(); // Persist filters
    applyFilters();
  }

  void updateQuestionType(String type) {
    final newFilters = state.filters.copyWith(questionType: type);
    updateFilters(newFilters);
  }

  void updateSubject(String subject) {
    final newFilters = state.filters.copyWith(
      subject: subject,
      topic: 'All Topics', // Reset topic when subject changes
    );
    updateFilters(newFilters);
  }

  void updateTopic(String topic) {
    final newFilters = state.filters.copyWith(topic: topic);
    updateFilters(newFilters);
  }

  void updateYear(String year) {
    final newFilters = state.filters.copyWith(year: year);
    updateFilters(newFilters);
  }

  void updateSearchQuery(String query) {
    final newFilters = state.filters.copyWith(searchQuery: query);
    state = state.copyWith(filters: newFilters, currentPage: 0);
    applyFilters();
  }

  void toggleRandomize() {
    final newFilters = state.filters.copyWith(
      randomizeQuestions: !state.filters.randomizeQuestions,
    );
    updateFilters(newFilters);
  }

  void applyFilters() {
    var filtered = List<QuestionCollection>.from(state.collections);
    final filters = state.filters;

    // Apply question type filter
    if (filters.questionType != 'All Types') {
      filtered = filtered.where((c) {
        final isMCQ = c.questionType == QuestionType.multipleChoice;
        final isTheory = c.questionType == QuestionType.essay;
        if (filters.questionType == 'MCQ' && !isMCQ) return false;
        if (filters.questionType == 'Theory' && !isTheory) return false;
        return true;
      }).toList();
    }

    // Apply subject filter
    if (filters.subject != 'All Subjects') {
      filtered = filtered.where((c) => _getSubjectName(c.subject) == filters.subject).toList();
    }

    // Apply year filter
    if (filters.year != 'All Years') {
      filtered = filtered.where((c) => c.year.toString() == filters.year).toList();
    }

    // Apply search query
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      filtered = filtered.where((c) =>
        c.title.toLowerCase().contains(query) ||
        _getSubjectName(c.subject).toLowerCase().contains(query) ||
        (c.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    state = state.copyWith(
      filteredCollections: filtered,
      currentPage: 0,
    );
  }

  String _getSubjectName(Subject subject) {
    switch (subject) {
      case Subject.mathematics:
        return 'Mathematics';
      case Subject.english:
        return 'English';
      case Subject.integratedScience:
        return 'Integrated Science';
      case Subject.socialStudies:
        return 'Social Studies';
      case Subject.religiousMoralEducation:
        return 'Religious and Moral Education';
      case Subject.ga:
        return 'Ga';
      case Subject.asanteTwi:
        return 'Asante Twi';
      case Subject.french:
        return 'French';
      case Subject.ict:
        return 'ICT';
      case Subject.creativeArts:
        return 'Creative Arts';
      case Subject.careerTechnology:
        return 'Career Technology';
      case Subject.trivia:
        return 'Trivia';
    }
  }

  void resetFilters() {
    updateFilters(const CollectionFilters());
  }

  void nextPage() {
    if (state.hasMorePages) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  void goToPage(int page) {
    state = state.copyWith(currentPage: page);
  }
}

// Provider
final questionServiceProvider = Provider<QuestionService>((ref) {
  return QuestionService();
});

final collectionsProvider = StateNotifierProvider<CollectionsNotifier, CollectionsState>((ref) {
  final questionService = ref.watch(questionServiceProvider);
  return CollectionsNotifier(questionService);
});

// Derived providers for easy access
final filteredCollectionsProvider = Provider<List<QuestionCollection>>((ref) {
  return ref.watch(collectionsProvider).filteredCollections;
});

final paginatedCollectionsProvider = Provider<List<QuestionCollection>>((ref) {
  return ref.watch(collectionsProvider).paginatedCollections;
});

final collectionsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(collectionsProvider).isLoading;
});

final filtersProvider = Provider<CollectionFilters>((ref) {
  return ref.watch(collectionsProvider).filters;
});
