class BibleNote {
  final String id;
  final String book;
  final int chapter;
  final int verse; // 0 = chapter-level note
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BibleNote({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  String get reference =>
      verse > 0 ? '$book $chapter:$verse' : '$book $chapter';

  String get preview {
    final t = body.trim();
    if (t.isEmpty) return 'Empty note';
    return t.length <= 120 ? t : '${t.substring(0, 117)}…';
  }

  bool get hasContent =>
      title.trim().isNotEmpty || body.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BibleNote.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    return BibleNote(
      id: json['id'] as String,
      book: json['book'] as String,
      chapter: asInt(json['chapter'], 1),
      verse: asInt(json['verse']),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  BibleNote copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
  }) {
    return BibleNote(
      id: id,
      book: book,
      chapter: chapter,
      verse: verse,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
