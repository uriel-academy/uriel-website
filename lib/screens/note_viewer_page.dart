import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final doc = await FirebaseFirestore.instance.collection('notes').doc(widget.noteId).get();
    if (!mounted) return;
    setState(() { _note = doc.data(); });
  }

  Future<void> _fetchSignedUrl() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      // Prefer callable function (handles auth automatically)
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('getNoteSignedUrlCallable');
        final resp = await callable.call(<String, dynamic>{'noteId': widget.noteId});
        final data = resp.data as Map<String, dynamic>;
        if (data['ok'] == true && data['signedUrl'] != null) {
          if (!mounted) return;
          setState(() { _signedUrl = data['signedUrl']; });
          return;
        }
      } catch (_) {
        // Fallback to HTTP endpoint (older clients)
      }

      // Fallback: HTTP endpoint using ID token
      final idToken = await user.getIdToken();
      final uri = Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/getNoteSignedUrl');
      final body = jsonEncode({'noteId': widget.noteId});
      final r = await http.post(uri, headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken' }, body: body);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        if (j['ok'] == true && j['signedUrl'] != null) {
          if (!mounted) return;
          setState(() { _signedUrl = j['signedUrl']; });
          return;
        }
      }
      throw Exception('Failed to fetch signed url: ${r.statusCode}');
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    // Capture messenger synchronously to avoid using BuildContext after awaits
    final messenger = ScaffoldMessenger.of(context);
    final can = await canLaunchUrl(uri);
    if (!can) {
      messenger.showSnackBar(const SnackBar(content: Text('Cannot open file')));
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger.showSnackBar(const SnackBar(content: Text('Cannot open file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Scaffold(
      appBar: AppBar(title: const Text('Note')),
      body: note == null ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(note['title'] ?? 'Untitled', style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if ((note['subject'] ?? '').toString().isNotEmpty) Text(note['subject'], style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 12),
          if ((note['text'] ?? '').toString().isNotEmpty) Text(note['text'], style: GoogleFonts.montserrat(fontSize: 16)),
          const SizedBox(height: 20),
          if (note['filePath'] != null || note['fileUrl'] != null) ...[
            if (_signedUrl != null) ConstrainedBox(constraints: const BoxConstraints(maxHeight: 420), child: Image.network(_signedUrl!, width: double.infinity, fit: BoxFit.contain)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _loading ? null : _fetchSignedUrl, icon: const Icon(Icons.link), label: Text(_signedUrl == null ? 'Fetch file' : 'Refresh link'))),
            const SizedBox(height: 8),
            if (_signedUrl != null) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _openExternalUrl(_signedUrl!), icon: const Icon(Icons.open_in_new), label: const Text('Open file'))),
            if (_signedUrl == null && note['fileUrl'] != null) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _openExternalUrl(note['fileUrl']), icon: const Icon(Icons.open_in_new), label: const Text('Open public file'))),
          ],
        ]),
      ),
    );
  }
}
