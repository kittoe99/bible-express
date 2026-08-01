class Verse {
  final int number;
  final String text;

  const Verse({required this.number, required this.text});

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      number: json['v'] as int,
      text: (json['t'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'v': number, 't': text};
}
