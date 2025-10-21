import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class ImageStorage {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadBytes(Uint8List bytes, String filename) async {
    // Allow up to 25 MB uploads
    if (bytes.lengthInBytes > 25 * 1024 * 1024) {
      throw Exception('File too large (max 25MB).');
    }

    final ext = p.extension(filename).toLowerCase();
    final contentType = {
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.webp': 'image/webp'
    }[ext] ?? 'application/octet-stream';

    final path = 'uploads/chat/${DateTime.now().millisecondsSinceEpoch}_$filename';
    final ref = _storage.ref().child(path);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType, cacheControl: 'public,max-age=3600'),
    );

    return await ref.getDownloadURL();
  }
}
