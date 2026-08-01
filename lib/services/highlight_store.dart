import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/highlight.dart';

class HighlightStore extends ChangeNotifier {
  HighlightStore._();
  static final HighlightStore instance = HighlightStore._();

  static const _fileName = 'highlights.json';
  final _uuid = const Uuid();
  final List<Highlight> _highlights = [];
  bool _loaded = false;
  bool highlightMode = false;

  List<Highlight> get highlights => List.unmodifiable(_highlights);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
        _highlights
          ..clear()
          ..addAll(raw.cast<Map<String, dynamic>>().map(Highlight.fromJson));
      }
    } catch (_) {
      _highlights.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  Highlight? forVerse(String book, int chapter, int verse) {
    for (final h in _highlights) {
      if (h.book == book && h.chapter == chapter && h.verse == verse) {
        return h;
      }
    }
    return null;
  }

  bool highlightsExist(String book, int chapter) {
    return _highlights.any((h) => h.book == book && h.chapter == chapter);
  }

  Color? getHighlightColorForType(HighlightColor color) {
    return Color(color.material.value);
  }

  void setHighlightMode(bool enabled) {
    highlightMode = enabled;
    notifyListeners();
  }

  Future<Highlight> addHighlight({
    required String book,
    required int chapter,
    required int verse,
    HighlightColor color = HighlightColor.yellow,
    String? note,
  }) async {
    await load();
    _highlights.removeWhere(
      (h) => h.book == book && h.chapter == chapter && h.verse == verse,
    );
    final highlight = Highlight(
      id: _uuid.v4(),
      book: book,
      chapter: chapter,
      verse: verse,
      color: color,
      note: note,
      createdAt: DateTime.now(),
    );
    _highlights.insert(0, highlight);
    await _persistLocal();
    await _upsertRemote(highlight);
    notifyListeners();
    return highlight;
  }

  Future<void> updateHighlight(Highlight highlight) async {
    await load();
    final i = _highlights.indexWhere((h) => h.id == highlight.id);
    if (i >= 0) {
      _highlights[i] = highlight;
    } else {
      _highlights.insert(0, highlight);
    }
    await _persistLocal();
    await _upsertRemote(highlight);
    notifyListeners();
  }

  Future<void> removeHighlight(String book, int chapter, int verse) async {
    await load();
    Highlight? removed;
    _highlights.removeWhere((h) {
      final match = h.book == book && h.chapter == chapter && h.verse == verse;
      if (match) removed = h;
      return match;
    });
    await _persistLocal();
    if (removed != null) {
      await _deleteRemote(removed!);
    }
    notifyListeners();
  }

  Future<void> syncFromCloud() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final rows = await client
        .from('highlights')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final remote = (rows as List<dynamic>).map((row) {
      final r = row as Map<String, dynamic>;
      return Highlight(
        id: r['id'] as String,
        book: r['book'] as String,
        chapter: r['chapter'] as int,
        verse: r['verse'] as int,
        color: HighlightColor.fromName(r['color'] as String? ?? 'yellow'),
        note: r['note'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();

    await load();
    final map = <String, Highlight>{};
    for (final h in [..._highlights, ...remote]) {
      final key = '${h.book}:${h.chapter}:${h.verse}';
      final existing = map[key];
      if (existing == null || h.createdAt.isAfter(existing.createdAt)) {
        map[key] = h;
      }
    }
    _highlights
      ..clear()
      ..addAll(map.values);
    await _persistLocal();
    for (final h in _highlights) {
      await _upsertRemote(h);
    }
    notifyListeners();
  }

  Future<void> _upsertRemote(Highlight highlight) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client.from('highlights').upsert(
        {
          'id': highlight.id,
          'user_id': user.id,
          'book': highlight.book,
          'chapter': highlight.chapter,
          'verse': highlight.verse,
          'color': highlight.color.name,
          'note': highlight.note,
          'created_at': highlight.createdAt.toIso8601String(),
        },
        onConflict: 'user_id,book,chapter,verse',
      );
    } catch (_) {}
  }

  Future<void> _deleteRemote(Highlight highlight) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('highlights')
          .delete()
          .eq('user_id', user.id)
          .eq('book', highlight.book)
          .eq('chapter', highlight.chapter)
          .eq('verse', highlight.verse);
    } catch (_) {}
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> _persistLocal() async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(_highlights.map((h) => h.toJson()).toList()),
    );
  }
}
