enum HighlightColor {
  yellow,
  green,
  blue,
  pink;

  static HighlightColor fromName(String name) {
    return HighlightColor.values.firstWhere(
      (c) => c.name == name,
      orElse: () => HighlightColor.yellow,
    );
  }

  ColorValue get material {
    switch (this) {
      case HighlightColor.yellow:
        return const ColorValue(0xFFFFF59D);
      case HighlightColor.green:
        return const ColorValue(0xFFA5D6A7);
      case HighlightColor.blue:
        return const ColorValue(0xFF90CAF9);
      case HighlightColor.pink:
        return const ColorValue(0xFFF48FB1);
    }
  }
}

/// Tiny color holder so the model file stays Flutter-free of Material imports.
class ColorValue {
  final int value;
  const ColorValue(this.value);
}

class Highlight {
  final String id;
  final String book;
  final int chapter;
  final int verse;
  final HighlightColor color;
  final String? note;
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.color,
    this.note,
    required this.createdAt,
  });

  String get reference => '$book $chapter:$verse';

  Map<String, dynamic> toJson() => {
        'id': id,
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'color': color.name,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      id: json['id'] as String,
      book: json['book'] as String,
      chapter: json['chapter'] as int,
      verse: json['verse'] as int,
      color: HighlightColor.fromName(json['color'] as String? ?? 'yellow'),
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Highlight copyWith({
    String? id,
    String? book,
    int? chapter,
    int? verse,
    HighlightColor? color,
    String? note,
    DateTime? createdAt,
  }) {
    return Highlight(
      id: id ?? this.id,
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      color: color ?? this.color,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
