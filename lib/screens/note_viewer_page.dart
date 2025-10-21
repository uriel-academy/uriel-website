import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NoteViewerPage extends StatefulWidget {
  final String noteId;

  const NoteViewerPage({super.key, required this.noteId});

  @override
  State<NoteViewerPage> createState() => _NoteViewerPageState();
}

class _NoteViewerPageState extends State<NoteViewerPage> {
  Map<String, dynamic>? _note;
  String? _signedUrl;
  bool _loading = false;
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final doc = await FirebaseFirestore.instance.collection('notes').doc(widget.noteId).get();
    if (!mounted) return;
    setState(() => _note = doc.data());
  }

  Future<void> _fetchSignedUrl() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      // Try callable first (preferred)
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('getNoteSignedUrlCallable');
        final resp = await callable.call(<String, dynamic>{'noteId': widget.noteId});
        final data = resp.data as Map<String, dynamic>;
        if (data['ok'] == true && data['signedUrl'] != null) {
          if (!mounted) return;
          setState(() => _signedUrl = data['signedUrl'] as String);
          return;
        }
      } catch (_) {
        // fallthrough to HTTP fallback
      }

      // HTTP fallback
      final idToken = await user.getIdToken();
      final uri = Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/getNoteSignedUrl');
      final body = jsonEncode({'noteId': widget.noteId});
      final r = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      }, body: body);

      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        if (j['ok'] == true && j['signedUrl'] != null) {
          if (!mounted) return;
          setState(() => _signedUrl = j['signedUrl'] as String);
          return;
        }
      }

      throw Exception('Failed to fetch signed url: ${r.statusCode}');
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    final messenger = ScaffoldMessenger.of(context);
    final can = await canLaunchUrl(uri);
    if (!can) {
      messenger.showSnackBar(const SnackBar(content: Text('Cannot open file')));
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) messenger.showSnackBar(const SnackBar(content: Text('Cannot open file')));
  }

  List<String> _collectImageUrls(Map<String, dynamic> note) {
    final urls = <String>[];
    if (note['signedUrl'] != null) urls.add(note['signedUrl'] as String);
    if (note['fileUrl'] != null) urls.add(note['fileUrl'] as String);
    final images = note['images'];
    if (images is List) {
      for (final it in images) {
        if (it is String && !urls.contains(it)) urls.add(it);
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final imageUrls = note == null ? const <String>[] : _collectImageUrls(note);

    return Scaffold(
      appBar: AppBar(
        title: Text(note == null ? 'Note' : (note['title'] ?? 'Note')),
        actions: [
          if (note != null && (note['filePath'] != null || note['fileUrl'] != null))
            IconButton(onPressed: _loading ? null : _fetchSignedUrl, icon: const Icon(Icons.link)),
          if (_signedUrl != null)
            IconButton(onPressed: () => _openExternalUrl(_signedUrl!), icon: const Icon(Icons.open_in_new)),
        ],
      ),
      body: note == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 720;

                if (isSmall) {
                  // Mobile stacked layout
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note['title'] ?? 'Untitled',
                          style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        if ((note['subject'] ?? '').toString().isNotEmpty)
                          Chip(label: Text(note['subject'], style: GoogleFonts.montserrat(fontSize: 12))),
                        const SizedBox(height: 12),

                        if (imageUrls.isNotEmpty) ...[
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              imageUrls[_selectedImageIndex],
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (ctx, i) {
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedImageIndex = i),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    width: 96,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: i == _selectedImageIndex ? Colors.blue : Colors.transparent,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        imageUrls[i],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => const SizedBox(width: 4),
                              itemCount: imageUrls.length,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if ((note['text'] ?? '').toString().isNotEmpty)
                          Text(note['text'], style: GoogleFonts.montserrat(fontSize: 16, height: 1.5)),

                        const SizedBox(height: 16),

                        if (note['filePath'] != null || note['fileUrl'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _loading ? null : _fetchSignedUrl,
                                  icon: const Icon(Icons.link),
                                  label: Text(_signedUrl == null ? 'Fetch link' : 'Refresh'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_signedUrl != null)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openExternalUrl(_signedUrl!),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Desktop / wide layout: two columns
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: images / gallery
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note['title'] ?? 'Untitled',
                                    style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if ((note['subject'] ?? '').toString().isNotEmpty)
                                        Chip(label: Text(note['subject'], style: GoogleFonts.montserrat(fontSize: 12))),
                                      const SizedBox(width: 8),
                                      Text(
                                        'By ${note['uploaderName'] ?? 'Anonymous'}',
                                        style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  if (imageUrls.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrls[_selectedImageIndex],
                                        fit: BoxFit.contain,
                                        alignment: Alignment.topCenter,
                                        width: double.infinity,
                                        height: 420,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                                      ),
                                    ),

                                  if (imageUrls.length > 1) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 96,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemBuilder: (ctx, i) {
                                          return GestureDetector(
                                            onTap: () => setState(() => _selectedImageIndex = i),
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 6),
                                              width: 120,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: i == _selectedImageIndex ? Colors.blue : Colors.transparent,
                                                  width: 2,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.network(
                                                  imageUrls[i],
                                                  fit: BoxFit.cover,
                                                  alignment: Alignment.topCenter,
                                                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                                        itemCount: imageUrls.length,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Right: text/details
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((note['text'] ?? '').toString().isNotEmpty)
                                      Text(note['text'], style: GoogleFonts.montserrat(fontSize: 16, height: 1.6)),
                                    const SizedBox(height: 12),

                                    if (note['filePath'] != null || note['fileUrl'] != null)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _loading ? null : _fetchSignedUrl,
                                              icon: const Icon(Icons.link),
                                              label: Text(_signedUrl == null ? 'Fetch link' : 'Refresh'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          if (_signedUrl != null)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _openExternalUrl(_signedUrl!),
                                                icon: const Icon(Icons.open_in_new),
                                                label: const Text('Open'),
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
