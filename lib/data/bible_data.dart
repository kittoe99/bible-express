import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/books_data.dart';
import '../models/bible_book.dart';
import '../models/verse.dart';

class BibleData {
  BibleData._();
  static final BibleData instance = BibleData._();

  Map<String, Map<String, List<Verse>>>? _data;
  final Map<String, List<Verse>> _cache = {};

  Future<void> load() async {
    if (_data != null) return;
    final raw = await rootBundle.loadString('assets/kjv_bible.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final parsed = <String, Map<String, List<Verse>>>{};
    for (final bookEntry in decoded.entries) {
      final chapters = <String, List<Verse>>{};
      final chapterMap = bookEntry.value as Map<String, dynamic>;
      for (final chEntry in chapterMap.entries) {
        final verses = (chEntry.value as List<dynamic>)
            .map((v) => Verse.fromJson(v as Map<String, dynamic>))
            .toList();
        chapters[chEntry.key] = verses;
      }
      parsed[bookEntry.key] = chapters;
    }
    _data = parsed;
  }

  List<BibleBook> get books {
    return kAllBooks
        .map(
          (name) => BibleBook(
            name: name,
            chapters: chapterCount(name),
            isOldTestament: isOldTestament(name),
          ),
        )
        .toList();
  }

  List<Verse> getVerses(String book, int chapter) {
    final key = '$book:$chapter';
    final cached = _cache[key];
    if (cached != null) return cached;
    final verses = _data?[book]?['$chapter'] ?? const <Verse>[];
    _cache[key] = verses;
    return verses;
  }

  List<Verse> surroundingVerses(
    String book,
    int chapter,
    int verse, {
    int radius = 2,
  }) {
    final verses = getVerses(book, chapter);
    if (verses.isEmpty) return const [];
    final start = (verse - radius).clamp(1, verses.length);
    final end = (verse + radius).clamp(1, verses.length);
    return verses.where((v) => v.number >= start && v.number <= end).toList();
  }

  Verse? getVerse(String book, int chapter, int verse) {
    final verses = getVerses(book, chapter);
    for (final v in verses) {
      if (v.number == verse) return v;
    }
    return null;
  }
}
