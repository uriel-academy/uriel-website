import 'package:cloud_firestore/cloud_firestore.dart';

class Storybook {
  final String id;
  final String title;
  final String author;
  final String fileName;
  final String assetPath;
  final int fileSize;
  final String format;
  final String category;
  final String language;
  final bool isActive;
  final bool isFree;
  final int readCount;
  final String? coverImageUrl;
  final DateTime? createdAt;
  final String? description;
  final int? pageCount;

  Storybook({
    required this.id,
    required this.title,
    required this.author,
    required this.fileName,
    required this.assetPath,
    required this.fileSize,
    required this.format,
    required this.category,
    this.language = 'en',
    this.isActive = true,
    this.isFree = true,
    this.readCount = 0,
    this.coverImageUrl,
    this.createdAt,
    this.description,
    this.pageCount,
  });

  factory Storybook.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Storybook(
      id: doc.id,
      title: data['title'] ?? '',
      author: data['author'] ?? 'Unknown',
      fileName: data['fileName'] ?? '',
      assetPath: data['assetPath'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      format: data['format'] ?? 'epub',
      category: data['category'] ?? 'classic-literature',
      language: data['language'] ?? 'en',
      isActive: data['isActive'] ?? true,
      isFree: data['isFree'] ?? true,
      readCount: data['readCount'] ?? 0,
      coverImageUrl: data['coverImageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      description: data['description'],
      pageCount: data['pageCount'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'fileName': fileName,
      'assetPath': assetPath,
      'fileSize': fileSize,
      'format': format,
      'category': category,
      'language': language,
      'isActive': isActive,
      'isFree': isFree,
      'readCount': readCount,
      'coverImageUrl': coverImageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'description': description,
      'pageCount': pageCount,
    };
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  bool get isNewRelease {
    if (createdAt == null) return false;
    final daysSinceCreation = DateTime.now().difference(createdAt!).inDays;
    return daysSinceCreation <= 30; // New if added within last 30 days
  }
}
