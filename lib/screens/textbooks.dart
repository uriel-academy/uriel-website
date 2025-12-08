import 'package:flutter/material.dart';

class TextbooksPage extends StatelessWidget {
  final VoidCallback? onTextbookRead;
  const TextbooksPage({super.key, this.onTextbookRead});

  @override
  Widget build(BuildContext context) {
    final subjects = [
      'Math', 'English', 'Biology', 'Chemistry', 'Physics', 'Economics', 'Literature', 'Civic', 'Geography', 'History', 'Computer',
    ];
    String selectedSubject = subjects[0];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Textbooks Library'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Subject:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(subjects[i]),
                  selected: selectedSubject == subjects[i],
                  onSelected: (selected) {
                    // TODO: Implement subject filter logic
                  },
                  selectedColor: const Color(0xFFD62828),
                  backgroundColor: const Color(0xFFF0F0F0),
                  labelStyle: TextStyle(
                    color: selectedSubject == subjects[i] ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 8, // TODO: Replace with filtered textbook count
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.menu_book, color: Color(0xFFD62828)),
                    title: Text('Textbook ${i + 1}'),
                    subtitle: Text('Subject: $selectedSubject | NACCA-aligned'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () {
                          // TODO: Implement download/open logic
                          if (onTextbookRead != null) onTextbookRead!();
                        },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
