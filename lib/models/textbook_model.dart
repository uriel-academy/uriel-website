class Textbook {
  final String id;
  final String title;
  final String author;
  final String publisher;
  final String subject;
  final String level;
  final int pages;
  final String description;
  final String downloadUrl;
  final bool isNew;
  final DateTime publishedDate;
  final List<String> topics;
  final double rating;
  final int downloads;

  Textbook({
    required this.id,
    required this.title,
    required this.author,
    required this.publisher,
    required this.subject,
    required this.level,
    required this.pages,
    required this.description,
    required this.downloadUrl,
    this.isNew = false,
    required this.publishedDate,
    required this.topics,
    this.rating = 0.0,
    this.downloads = 0,
  });

  factory Textbook.fromJson(Map<String, dynamic> json) {
    return Textbook(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      publisher: json['publisher'] ?? '',
      subject: json['subject'] ?? '',
      level: json['level'] ?? '',
      pages: json['pages'] ?? 0,
      description: json['description'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      isNew: json['isNew'] ?? false,
      publishedDate: DateTime.parse(json['publishedDate'] ?? DateTime.now().toIso8601String()),
      topics: List<String>.from(json['topics'] ?? []),
      rating: (json['rating'] ?? 0.0).toDouble(),
      downloads: json['downloads'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'publisher': publisher,
      'subject': subject,
      'level': level,
      'pages': pages,
      'description': description,
      'downloadUrl': downloadUrl,
      'isNew': isNew,
      'publishedDate': publishedDate.toIso8601String(),
      'topics': topics,
      'rating': rating,
      'downloads': downloads,
    };
  }
}
