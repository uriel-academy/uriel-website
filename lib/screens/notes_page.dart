import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          // Real-time list of user's notes
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notes')
                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.menu_book, size: 72, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No notes yet', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Text('Upload text or photo notes to help students across Ghana.', style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/upload_note'), icon: const Icon(Icons.add), label: const Text('Upload Note'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066CC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final title = (d['title'] ?? '').toString();
                  final subject = (d['subject'] ?? '').toString();
                  final text = (d['text'] ?? '').toString();
                  final signedUrl = d['signedUrl'] as String?;
                  final filePath = d['filePath'] as String?;

                  return ListTile(
                    leading: signedUrl != null
                        ? Image.network(signedUrl, width: 64, height: 64, fit: BoxFit.cover)
                        : (filePath != null ? Icon(Icons.image, size: 48, color: Colors.grey[400]) : Icon(Icons.article, size: 48, color: Colors.grey[400])),
                    title: Text(title.isNotEmpty ? title : 'Untitled', style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ if (subject.isNotEmpty) Text(subject, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700])), if (text.isNotEmpty) Text(text.length > 120 ? '${text.substring(0, 120)}…' : text, style: GoogleFonts.montserrat(fontSize: 13)) ]),
                    onTap: () {
                      // TODO: open note viewer
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
