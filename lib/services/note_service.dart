import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoteService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Toggle like for the current user on [noteId]. This will add/remove a
  /// document under notes/{noteId}/likes/{uid} and increment/decrement the
  /// notes/{noteId}.likeCount field. It will also add/remove a lightweight
  /// entry under users/{uid}/my_notes/{noteId} so liked notes appear in the
  /// user's My Notes section.
  static Future<void> toggleLike(String noteId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final noteRef = _db.collection('notes').doc(noteId);
    final likeRef = noteRef.collection('likes').doc(uid);
    final myNotesRef = _db.collection('users').doc(uid).collection('my_notes').doc(noteId);

    await _db.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final noteSnap = await tx.get(noteRef);

      // Verify note exists before proceeding
      if (!noteSnap.exists) {
        throw Exception('Note does not exist');
      }

      if (likeSnap.exists) {
        // remove like
        tx.delete(likeRef);
        tx.delete(myNotesRef);
        // Use set with merge to ensure field exists before decrementing
        final currentLikes = (noteSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;
        final newLikes = (currentLikes - 1).clamp(0, 1000000000);
        tx.set(noteRef, {'likeCount': newLikes}, SetOptions(merge: true));
      } else {
        // add like
        tx.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        // Use set with merge to safely increment
        final currentLikes = (noteSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;
        final newLikes = currentLikes + 1;
        tx.set(noteRef, {'likeCount': newLikes}, SetOptions(merge: true));

        // add lightweight my_notes entry
        final noteData = noteSnap.data()!;
        tx.set(myNotesRef, {
          'noteId': noteId,
          'title': noteData['title'] ?? '',
          'subject': noteData['subject'] ?? '',
          'uploaderName': noteData['uploaderName'] ?? '',
          'thumbnail': (noteData['images'] is List && (noteData['images'] as List).isNotEmpty) ? (noteData['images'] as List).first : (noteData['fileUrl'] ?? noteData['signedUrl']),
          'addedAt': FieldValue.serverTimestamp(),
        },
            );
      }
    });
  }

  static Future<bool> isLikedByUser(String noteId, String uid) async {
    final likeRef = _db.collection('notes').doc(noteId).collection('likes').doc(uid);
    final snap = await likeRef.get();
    return snap.exists;
  }

  static Stream<int> likeCountStream(String noteId) {
    return _db.collection('notes').doc(noteId).snapshots().map((s) {
      if (!s.exists) return 0;
      final data = s.data();
      if (data == null) return 0;
      final v = data['likeCount'];
      if (v is int) return v;
      if (v is double) return v.toInt();
      return 0;
    });
  }

  // Update an existing note instead of creating a new one
  static Future<void> updateNote(String noteId, Map<String, dynamic> updatedData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Preserve existing images unless explicitly removed
    final existingNote = await _db.collection('notes').doc(noteId).get();
    final existingImages = existingNote.data()?['images'] ?? [];
    final newImages = updatedData['images'] ?? [];
    updatedData['images'] = [...existingImages, ...newImages]; // Merge, assuming newImages are additions

    // Ensure author is set correctly
    updatedData['authorName'] = user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous';
    updatedData['authorId'] = user.uid;
    updatedData['updatedAt'] = FieldValue.serverTimestamp();

    await _db.collection('notes').doc(noteId).update(updatedData);
  }

  // Create a new note (for reference)
  static Future<String> createNote(Map<String, dynamic> noteData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    noteData['authorName'] = user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous';
    noteData['authorId'] = user.uid;
    noteData['createdAt'] = FieldValue.serverTimestamp();

    final docRef = await _db.collection('notes').add(noteData);
    return docRef.id;
  }
}
