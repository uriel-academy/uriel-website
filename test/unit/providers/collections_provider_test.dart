import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/providers/collections_provider.dart';
import 'package:uriel_mainapp/models/question_collection_model.dart';
import 'package:uriel_mainapp/models/question_model.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('CollectionFilters Tests', () {
    test('should initialize with default values', () {
      const filters = CollectionFilters();
      
      expect(filters.questionType, 'All Types');
      expect(filters.subject, 'All Subjects');
      expect(filters.topic, 'All Topics');
      expect(filters.year, 'All Years');
      expect(filters.searchQuery, '');
      expect(filters.randomizeQuestions, false);
    });

    test('should identify inactive filters correctly', () {
      const defaultFilters = CollectionFilters();
      expect(defaultFilters.isActive, false);

      const activeFilters = CollectionFilters(questionType: 'MCQ');
      expect(activeFilters.isActive, true);

      const searchFilters = CollectionFilters(searchQuery: 'math');
      expect(searchFilters.isActive, true);
    });

    test('should copyWith correctly', () {
      const filters = CollectionFilters(
        questionType: 'MCQ',
        subject: 'Mathematics',
      );

      final updated = filters.copyWith(subject: 'English');
      
      expect(updated.questionType, 'MCQ'); // Unchanged
      expect(updated.subject, 'English'); // Updated
      expect(updated.topic, 'All Topics'); // Unchanged
    });

    test('should copy all fields when all parameters provided', () {
      const filters = CollectionFilters();

      final updated = filters.copyWith(
        questionType: 'Theory',
        subject: 'Science',
        topic: 'Physics',
        year: '2024',
        searchQuery: 'test',
        randomizeQuestions: true,
      );

      expect(updated.questionType, 'Theory');
      expect(updated.subject, 'Science');
      expect(updated.topic, 'Physics');
      expect(updated.year, '2024');
      expect(updated.searchQuery, 'test');
      expect(updated.randomizeQuestions, true);
    });
  });

  group('CollectionsState Tests', () {
    test('should initialize with default values', () {
      const state = CollectionsState();

      expect(state.collections, isEmpty);
      expect(state.filteredCollections, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.currentPage, 0);
      expect(state.pageSize, 12);
    });

    test('should copyWith correctly', () {
      const state = CollectionsState(isLoading: true);

      final updated = state.copyWith(isLoading: false, error: 'Test error');

      expect(updated.isLoading, false);
      expect(updated.error, 'Test error');
    });

    test('should paginate collections correctly', () {
      final collections = List.generate(
        25,
        (i) => QuestionCollection(
          id: 'col_$i',
          title: 'Collection $i',
          subject: Subject.mathematics,
          examType: ExamType.bece,
          year: '2024',
          questionType: QuestionType.multipleChoice,
          questionCount: 10,
          questions: [],
        ),
      );

      final state = CollectionsState(
        filteredCollections: collections,
        currentPage: 0,
        pageSize: 12,
      );

      // First page should have 12 items
      expect(state.paginatedCollections.length, 12);
      expect(state.paginatedCollections.first.id, 'col_0');
      expect(state.paginatedCollections.last.id, 'col_11');
      expect(state.hasMorePages, true);

      // Second page should have 12 items
      final page2State = state.copyWith(currentPage: 1);
      expect(page2State.paginatedCollections.length, 12);
      expect(page2State.paginatedCollections.first.id, 'col_12');
      expect(page2State.paginatedCollections.last.id, 'col_23');
      expect(page2State.hasMorePages, true);

      // Third page should have 1 item (25 total - 24 from first 2 pages)
      final page3State = state.copyWith(currentPage: 2);
      expect(page3State.paginatedCollections.length, 1);
      expect(page3State.paginatedCollections.first.id, 'col_24');
      expect(page3State.hasMorePages, false);
    });

    test('should handle pagination beyond available items', () {
      final collections = List.generate(5, (i) => QuestionCollection(
        id: 'col_$i',
        title: 'Collection $i',
        subject: Subject.mathematics,
        examType: ExamType.bece,
        year: '2024',
        questionType: QuestionType.multipleChoice,
        questionCount: 10,
        questions: [],
      ));

      final state = CollectionsState(
        filteredCollections: collections,
        currentPage: 5, // Way beyond available pages
        pageSize: 12,
      );

      expect(state.paginatedCollections, isEmpty);
      expect(state.hasMorePages, false);
    });

    test('should handle empty collections', () {
      const state = CollectionsState();

      expect(state.paginatedCollections, isEmpty);
      expect(state.hasMorePages, false);
    });
  });
}
