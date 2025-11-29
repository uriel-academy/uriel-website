import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question_collection_model.dart';
import '../providers/collections_provider.dart';

/// Riverpod-powered Question Collections Page
/// Clean state management with automatic filter persistence
class QuestionCollectionsPageRiverpod extends ConsumerWidget {
  final String? initialSubject;

  const QuestionCollectionsPageRiverpod({Key? key, this.initialSubject}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionsProvider);
    final notifier = ref.read(collectionsProvider.notifier);
    
    final isSmallScreen = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isSmallScreen),
            _buildFiltersSection(context, ref, isSmallScreen),
            Expanded(
              child: state.isLoading
                  ? _buildLoadingState()
                  : state.error != null
                      ? _buildErrorState(state.error!, notifier)
                      : state.filteredCollections.isEmpty
                          ? _buildEmptyState(state.filters.isActive)
                          : _buildCollectionsGrid(
                              context,
                              state.paginatedCollections,
                              isSmallScreen,
                            ),
            ),
            if (state.filteredCollections.isNotEmpty)
              _buildPaginationControls(context, state, notifier, isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isSmallScreen)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          Expanded(
            child: Text(
              'Question Collections',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 20 : 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context, WidgetRef ref, bool isSmallScreen) {
    final filters = ref.watch(filtersProvider);
    final notifier = ref.read(collectionsProvider.notifier);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      color: Colors.white,
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search collections...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: filters.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => notifier.updateSearchQuery(''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            onChanged: notifier.updateSearchQuery,
          ),
          const SizedBox(height: 12),
          // Filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                'Type: ${filters.questionType}',
                filters.questionType != 'All Types',
                () => _showTypeDialog(context, ref),
              ),
              _buildFilterChip(
                'Subject: ${filters.subject}',
                filters.subject != 'All Subjects',
                () => _showSubjectDialog(context, ref),
              ),
              _buildFilterChip(
                'Year: ${filters.year}',
                filters.year != 'All Years',
                () => _showYearDialog(context, ref),
              ),
              if (filters.isActive)
                _buildFilterChip(
                  'Reset',
                  true,
                  () => notifier.resetFilters(),
                  icon: Icons.clear,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, VoidCallback onTap, {IconData? icon}) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 16),
          if (icon != null) const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF007AFF),
      labelStyle: TextStyle(
        color: isActive ? Colors.white : Colors.black87,
        fontSize: 13,
      ),
    );
  }

  Widget _buildCollectionsGrid(
    BuildContext context,
    List<QuestionCollection> collections,
    bool isSmallScreen,
  ) {
    return GridView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 1 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isSmallScreen ? 2.5 : 1.8,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        return _buildCollectionCard(context, collection, isSmallScreen);
      },
    );
  }

  Widget _buildCollectionCard(
    BuildContext context,
    QuestionCollection collection,
    bool isSmallScreen,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToCollection(context, collection),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getCollectionIcon(collection),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${collection.year} • ${collection.questionIds?.length ?? collection.questionCount} questions',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (collection.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(
                  collection.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getCollectionIcon(QuestionCollection collection) {
    final isMCQ = collection.questionType.name.toLowerCase().contains('multiple');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMCQ ? Colors.blue[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isMCQ ? Icons.check_box : Icons.edit_note,
        color: isMCQ ? Colors.blue : Colors.green,
        size: 24,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String error, CollectionsNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => notifier.loadCollections(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool hasActiveFilters) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            hasActiveFilters
                ? 'No collections match your filters'
                : 'No collections available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(
    BuildContext context,
    CollectionsState state,
    CollectionsNotifier notifier,
    bool isSmallScreen,
  ) {
    final totalPages = (state.filteredCollections.length / state.pageSize).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${state.currentPage + 1} of $totalPages',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: state.currentPage > 0 ? notifier.previousPage : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: state.hasMorePages ? notifier.nextPage : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTypeDialog(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(collectionsProvider.notifier);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Question Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['All Types', 'MCQ', 'Theory']
              .map((type) => ListTile(
                    title: Text(type),
                    onTap: () {
                      notifier.updateQuestionType(type);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showSubjectDialog(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(collectionsProvider.notifier);
    final subjects = ['All Subjects', 'Mathematics', 'English', 'Science', 'Social Studies'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subject'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: subjects
                .map((subject) => ListTile(
                      title: Text(subject),
                      onTap: () {
                        notifier.updateSubject(subject);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showYearDialog(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(collectionsProvider.notifier);
    final years = ['All Years', ...List.generate(26, (i) => (2000 + i).toString())];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Year'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: years
                .map((year) => ListTile(
                      title: Text(year),
                      onTap: () {
                        notifier.updateYear(year);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _navigateToCollection(BuildContext context, QuestionCollection collection) {
    // TODO: Navigate to quiz/theory page
    print('Navigate to: ${collection.title}');
  }
}
