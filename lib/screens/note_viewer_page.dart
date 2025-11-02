import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/note_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NoteViewerPage extends StatefulWidget {
  final String noteId;

  const NoteViewerPage({super.key, required this.noteId});

  @override
  State<NoteViewerPage> createState() => _NoteViewerPageState();
}

class _NoteViewerPageState extends State<NoteViewerPage> {
  Map<String, dynamic>? _note;
  String? _signedUrl;
  List<String> _imageUrls = [];
  bool _loading = false;
  int _selectedImageIndex = 0;
  bool _likedByMe = false;
  int _likeCount = 0;
  Stream<int>? _likeCountSub;
  bool _likeAnimating = false;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final doc = await FirebaseFirestore.instance.collection('notes').doc(widget.noteId).get();
    if (!mounted) return;
    setState(() => _note = doc.data());

    // Resolve image URLs immediately so images display fast when viewer opens
    _resolveImageUrls();

    // subscribe to like count
    _likeCountSub = NoteService.likeCountStream(widget.noteId);
    _likeCountSub?.listen((count) {
      if (!mounted) return;
      setState(() => _likeCount = count);
    });

    // check if current user liked
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final liked = await NoteService.isLikedByUser(widget.noteId, uid);
      if (mounted) setState(() => _likedByMe = liked);
    }

    // If running on web, proactively try to fetch a signed URL when there's
    // a file attached but no public URL/images. This helps the desktop web
    // viewer load images that are stored in protected Firebase Storage.
    try {
      final note = _note;
      if (kIsWeb && note != null) {
        final images = note['images'];
        final hasImages = images is List && images.isNotEmpty;
        final hasFile = note['filePath'] != null || note['fileUrl'] != null || note['signedUrl'] != null;
        if (!hasImages && hasFile && _signedUrl == null) {
          // fire-and-forget; _fetchSignedUrl will set state when done
          _fetchSignedUrl();
        }
      }
    } catch (_) {
      // ignore
    }
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

  Future<void> _toggleLike() async {
    final messenger = ScaffoldMessenger.of(context);
    final wasLiked = _likedByMe;

    // Optimistic UI update
    setState(() {
      _likedByMe = !_likedByMe;
      _likeCount = (_likeCount + (_likedByMe ? 1 : -1)).clamp(0, 1000000000);
      _likeAnimating = true;
    });

    // reset animation after short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _likeAnimating = false);
    });

    try {
      await NoteService.toggleLike(widget.noteId);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(_likedByMe ? 'Saved to My Notes' : 'Removed from My Notes')));
    } catch (e) {
      // revert optimistic update on error
      if (mounted) {
        setState(() {
          _likedByMe = wasLiked;
          _likeCount = (wasLiked ? _likeCount + 1 : (_likeCount - 1)).clamp(0, 1000000000);
        });
        messenger.showSnackBar(SnackBar(content: Text('Error updating like: $e')));
      }
    }
  }

  void _shareNote() {
    final note = _note;
    if (note == null) return;

    final title = note['title'] ?? 'Note on Uriel Academy';
    final shareUrl = Uri.base.replace(path: '/note', queryParameters: {'noteId': widget.noteId}).toString();
    final message = 'Check out this note on uriel.academy:\n$title\n$shareUrl';
    Share.share(message, subject: title);
  }

  List<String> _collectImageUrls(Map<String, dynamic> note) {
    // Keep existing stored sources but prefer resolved, fresher URLs stored in _imageUrls
    final urls = <String>[];
    urls.addAll(_imageUrls);
    final images = note['images'];
    if (images is List) {
      for (final it in images) {
        if (it is String && !urls.contains(it)) urls.add(it);
      }
    }
    if (note['fileUrl'] != null && !urls.contains(note['fileUrl'])) urls.add(note['fileUrl'] as String);
    if (note['signedUrl'] != null && !urls.contains(note['signedUrl'])) urls.add(note['signedUrl'] as String);
    return urls;
  }

  /// Open a full-screen image viewer for the image at [index].
  /// Ensures a download URL is available (resolves Storage URL or fetches a signed URL)
  /// and shows a dialog with the image. Shows a loading spinner while resolving.
  Future<void> _openImageViewer(int index) async {
    final note = _note;
    if (note == null) return;

    // Ensure image URLs are resolved
    if (_imageUrls.isEmpty) {
      await _resolveImageUrls();
    }

    String? url;
    if (index >= 0 && index < _imageUrls.length) url = _imageUrls[index];

    // If not resolved, try to trigger a callable signed URL
    if ((url == null || url.isEmpty) && (note['filePath'] != null || note['signedUrl'] != null)) {
      await _fetchSignedUrl();
      // after fetch, re-run resolve
      await _resolveImageUrls();
      if (index >= 0 && index < _imageUrls.length) url = _imageUrls[index];
    }

    // If still no url, fallback to fileUrl or images array
    if ((url == null || url.isEmpty)) {
      final fallback = _collectImageUrls(note);
      if (index >= 0 && index < fallback.length) url = fallback[index];
    }

    // Show dialog with image or error
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(8),
          backgroundColor: Colors.black,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                if (url == null || url.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  Center(
                    child: InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resolveImageUrls() async {
    final note = _note;
    if (note == null) return;
    final resolved = <String>[];

    // 1) If explicit images array exists, add them first
    final images = note['images'];
    if (images is List) {
      for (final it in images) {
        if (it is String) resolved.add(it);
      }
    }

    // 2) If there's a filePath, try to get a Storage download URL (most reliable)
    try {
      final filePath = note['filePath'] as String?;
      if (filePath != null && filePath.isNotEmpty) {
        try {
          final url = await FirebaseStorage.instance.ref(filePath).getDownloadURL();
          if (url.isNotEmpty && !resolved.contains(url)) {
            resolved.insert(0, url);
            // Prefetch for snappy display
            try {
              await precacheImage(CachedNetworkImageProvider(url), context);
            } catch (_) {}
          }
        } catch (_) {
          // ignore, will try signedUrl/callable below
        }
      }
    } catch (_) {}

    // 3) If there is a stored signedUrl or fileUrl, add them
    final signed = note['signedUrl'] as String?;
    if (signed != null && signed.isNotEmpty && !resolved.contains(signed)) resolved.add(signed);
    final fileUrl = note['fileUrl'] as String?;
    if (fileUrl != null && fileUrl.isNotEmpty && !resolved.contains(fileUrl)) resolved.add(fileUrl);

    if (resolved.isEmpty) {
      // Attempt to call server to mint a signed URL if allowed (fire-and-forget)
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('getNoteSignedUrlCallable');
        final resp = await callable.call(<String, dynamic>{'noteId': widget.noteId});
        final data = resp.data as Map<String, dynamic>;
        final url = data['signedUrl'] as String?;
        if (url != null && url.isNotEmpty) {
          resolved.add(url);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _imageUrls = resolved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final imageUrls = note == null ? const <String>[] : _collectImageUrls(note);

    return Scaffold(
      appBar: AppBar(
        title: Text(note == null ? 'Note' : (note['title'] ?? 'Note')),
        actions: [
          // Like button with count
          if (note != null)
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: AnimatedScale(
                    scale: _likeAnimating ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _likedByMe ? Icons.favorite : Icons.favorite_border,
                      color: _likedByMe ? Colors.redAccent : null,
                      size: 22,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text('$_likeCount'),
                ),
              ],
            ),

          // Share button
          if (note != null)
            IconButton(onPressed: _shareNote, icon: const Icon(Icons.share)),
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
                        Text(
                          'By ${note['authorName'] ?? 'Anonymous'}',
                          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 6),
                        if ((note['subject'] ?? '').toString().isNotEmpty)
                          Chip(label: Text(note['subject'], style: GoogleFonts.montserrat(fontSize: 12))),
                        const SizedBox(height: 12),

                        if (imageUrls.isNotEmpty) ...[
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: GestureDetector(
                              onTap: () => _openImageViewer(_selectedImageIndex),
                              child: CachedNetworkImage(
                                imageUrl: imageUrls[_selectedImageIndex],
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                width: double.infinity,
                                placeholder: (_, __) => Container(color: Colors.grey[300]),
                                errorWidget: (_, __, ___) => Container(color: Colors.grey[300]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (ctx, i) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedImageIndex = i);
                                    _openImageViewer(i);
                                  },
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
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrls[i],
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: Colors.grey[200]),
                                        errorWidget: (_, __, ___) => Container(color: Colors.grey[200]),
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
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
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
                                        'By ${note['authorName'] ?? 'Anonymous'}',
                                        style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  if (imageUrls.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: GestureDetector(
                                        onTap: () => _openImageViewer(_selectedImageIndex),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrls[_selectedImageIndex],
                                          fit: BoxFit.contain,
                                          alignment: Alignment.topCenter,
                                          width: double.infinity,
                                          height: 420,
                                          placeholder: (_, __) => Container(color: Colors.grey[200]),
                                          errorWidget: (_, __, ___) => Container(color: Colors.grey[200]),
                                        ),
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
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() => _selectedImageIndex = i);
                                                    _openImageViewer(i);
                                                  },
                                                  child: CachedNetworkImage(
                                                    imageUrl: imageUrls[i],
                                                    fit: BoxFit.cover,
                                                    alignment: Alignment.topCenter,
                                                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                                                    errorWidget: (_, __, ___) => Container(color: Colors.grey[200]),
                                                  ),
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
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
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
