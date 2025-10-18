import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes Library',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse, upload, and manage study notes (text, photo, mixed).',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          // Placeholder: show a friendly empty state and Upload button
          Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.menu_book, size: 72, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Notes will appear here',
                  style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload text or photo notes to help students across Ghana.',
                  style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/upload_note');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Upload Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
