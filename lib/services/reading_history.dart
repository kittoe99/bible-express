import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReadingEntry {
  final String book;
  final int chapter;
  final int verse;
  final DateTime lastReadAt;

  const ReadingEntry({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.lastReadAt,
  });

  String get reference => '$book $chapter';

  Map<String, dynamic> toJson() => {
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'lastReadAt': lastReadAt.toIso8601String(),
      };

  factory ReadingEntry.fromJson(Map<String, dynamic> json) {
    return ReadingEntry(
      book: json['book'] as String,
      chapter: json['chapter'] as int,
      verse: (json['verse'] as int?) ?? 1,
      lastReadAt: DateTime.tryParse(json['lastReadAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ReadingHistory {
  ReadingHistory._();
  static final ReadingHistory instance = ReadingHistory._();

  static const _fileName = 'reading_history.json';
  List<ReadingEntry> _entries = [];
  bool _loaded = false;

  List<ReadingEntry> get entries => List.unmodifiable(_entries);

  ReadingEntry? get continueReading =>
      _entries.isEmpty ? null : _entries.first;

  List<ReadingEntry> getRecent({int limit = 12}) =>
      _entries.take(limit).toList();

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
        _entries = raw
            .cast<Map<String, dynamic>>()
            .map(ReadingEntry.fromJson)
            .toList()
          ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
      }
    } catch (_) {
      _entries = [];
    }
    _loaded = true;
  }

  Future<void> recordReading(String book, int chapter, {int verse = 1}) async {
    await load();
    final now = DateTime.now();
    _entries.removeWhere((e) => e.book == book && e.chapter == chapter);
    _entries.insert(
      0,
      ReadingEntry(book: book, chapter: chapter, verse: verse, lastReadAt: now),
    );
    if (_entries.length > 100) {
      _entries = _entries.take(100).toList();
    }
    await _persistLocal();
    await _upsertRemote(book, chapter, verse, now);
  }

  Future<void> syncFromCloud() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final rows = await client
        .from('reading_progress')
        .select()
        .eq('user_id', user.id)
        .order('last_read_at', ascending: false);

    final remote = (rows as List<dynamic>).map((row) {
      final r = row as Map<String, dynamic>;
      return ReadingEntry(
        book: r['book'] as String,
        chapter: r['chapter'] as int,
        verse: (r['verse'] as int?) ?? 1,
        lastReadAt: DateTime.tryParse(r['last_read_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();

    await load();
    final map = <String, ReadingEntry>{};
    for (final e in [..._entries, ...remote]) {
      final key = '${e.book}:${e.chapter}';
      final existing = map[key];
      if (existing == null || e.lastReadAt.isAfter(existing.lastReadAt)) {
        map[key] = e;
      }
    }
    _entries = map.values.toList()
      ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    await _persistLocal();

    // Push merged set so cloud matches.
    for (final e in _entries.take(50)) {
      await _upsertRemote(e.book, e.chapter, e.verse, e.lastReadAt);
    }
  }

  Future<void> _upsertRemote(
    String book,
    int chapter,
    int verse,
    DateTime at,
  ) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client.from('reading_progress').upsert(
        {
          'user_id': user.id,
          'book': book,
          'chapter': chapter,
          'verse': verse,
          'last_read_at': at.toIso8601String(),
        },
        onConflict: 'user_id,book,chapter',
      );
    } catch (_) {
      // Offline / RLS — local still saved.
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _persistLocal() async {
    final file = await _file();
    await file.writeAsString(jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }
}
