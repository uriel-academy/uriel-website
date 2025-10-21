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

      if (likeSnap.exists) {
        // remove like
        tx.delete(likeRef);
        tx.update(noteRef, {'likeCount': FieldValue.increment(-1)});
        tx.delete(myNotesRef);
      } else {
        // add like
        tx.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        // ensure note has a likeCount field
        if (!noteSnap.exists) {
          tx.set(noteRef, {'likeCount': 1}, SetOptions(merge: true));
        } else {
          tx.update(noteRef, {'likeCount': FieldValue.increment(1)});
        }

        // add lightweight my_notes entry
        final noteData = noteSnap.exists ? noteSnap.data()! : <String, dynamic>{};
        tx.set(myNotesRef, {
          'noteId': noteId,
          'title': noteData['title'] ?? '',
          'subject': noteData['subject'] ?? '',
          'uploaderName': noteData['uploaderName'] ?? '',
          'thumbnail': (noteData['images'] is List && (noteData['images'] as List).isNotEmpty) ? (noteData['images'] as List).first : (noteData['fileUrl'] ?? noteData['signedUrl'] ?? null),
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
}
