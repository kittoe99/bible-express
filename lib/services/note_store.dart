import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/bible_note.dart';

class NoteStore extends ChangeNotifier {
  NoteStore._();
  static final NoteStore instance = NoteStore._();

  static const _prefsKey = 'bible_xpress_notes_v1';
  static const _backupFileName = 'bible_notes.json';
  final _uuid = const Uuid();
  final List<BibleNote> _notes = [];
  final Set<String> _pendingCloudIds = {};
  bool _loaded = false;

  List<BibleNote> get notes => List.unmodifiable(_notes);

  List<BibleNote> get savedNotes =>
      _notes.where((n) => n.hasContent).toList(growable: false);

  bool get hasPendingCloudSync => _pendingCloudIds.isNotEmpty;
  bool get isSignedIn => Supabase.instance.client.auth.currentUser != null;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_prefsKey);

      if ((raw == null || raw.isEmpty) && !kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$_backupFileName');
          if (await file.exists()) {
            final migrated = await file.readAsString();
            if (migrated.isNotEmpty) {
              raw = migrated;
              await prefs.setString(_prefsKey, migrated);
            }
          }
        } catch (e) {
          debugPrint('NoteStore backup migrate skipped: $e');
        }
      }

      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _notes
          ..clear()
          ..addAll(list.cast<Map<String, dynamic>>().map(BibleNote.fromJson));
        _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    } catch (e) {
      debugPrint('NoteStore.load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  BibleNote? getNote(String id) {
    for (final n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<BibleNote> forVerse(String book, int chapter, int verse) {
    final list = _notes
        .where((n) =>
            n.book == book && n.chapter == chapter && n.verse == verse)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<BibleNote> forChapter(String book, int chapter) {
    final list = _notes
        .where((n) => n.book == book && n.chapter == chapter)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  BibleNote? latestForVerse(String book, int chapter, int verse) {
    final list = forVerse(book, chapter, verse);
    return list.isEmpty ? null : list.first;
  }

  bool hasNotesForVerse(String book, int chapter, int verse) =>
      forVerse(book, chapter, verse).isNotEmpty;

  Future<BibleNote> createNote({
    required String book,
    required int chapter,
    required int verse,
    String? title,
    String body = '',
  }) {
    final now = DateTime.now();
    return upsertNote(
      BibleNote(
        id: _uuid.v4(),
        book: book,
        chapter: chapter,
        verse: verse,
        title: title ?? '',
        body: body,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<BibleNote> upsertNote(BibleNote note) async {
    await load();
    final updated = note.copyWith(updatedAt: DateTime.now());
    final i = _notes.indexWhere((n) => n.id == updated.id);
    if (i >= 0) {
      _notes[i] = BibleNote(
        id: updated.id,
        book: updated.book,
        chapter: updated.chapter,
        verse: updated.verse,
        title: updated.title,
        body: updated.body,
        createdAt: _notes[i].createdAt,
        updatedAt: updated.updatedAt,
      );
    } else {
      _notes.insert(0, updated);
    }
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistLocal();
    final saved = _notes.firstWhere((n) => n.id == updated.id);
    await _upsertRemote(saved);
    notifyListeners();
    return saved;
  }

  Future<void> deleteNote(String id) async {
    await load();
    _notes.removeWhere((n) => n.id == id);
    _pendingCloudIds.remove(id);
    await _persistLocal();
    await _deleteRemote(id);
    notifyListeners();
  }

  Future<void> retryPendingCloudSync() async {
    if (!isSignedIn) return;
    final ids = _pendingCloudIds.toList();
    for (final id in ids) {
      final n = getNote(id);
      if (n != null) await _upsertRemote(n);
    }
  }

  Future<void> syncFromCloud() async {
    await load();
    if (!isSignedIn) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final rows = await client
        .from('bible_notes')
        .select()
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);

    final remote = <BibleNote>[];
    for (final r in rows as List<dynamic>) {
      final m = r as Map<String, dynamic>;
      int asInt(dynamic v, [int fallback = 0]) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse('$v') ?? fallback;
      }

      remote.add(
        BibleNote(
          id: m['id'] as String,
          book: m['book'] as String,
          chapter: asInt(m['chapter'], 1),
          verse: asInt(m['verse']),
          title: m['title'] as String? ?? '',
          body: m['body'] as String? ?? '',
          createdAt:
              DateTime.tryParse(m['created_at'] as String? ?? '') ??
                  DateTime.now(),
          updatedAt:
              DateTime.tryParse(m['updated_at'] as String? ?? '') ??
                  DateTime.now(),
        ),
      );
    }

    final map = <String, BibleNote>{for (final n in _notes) n.id: n};
    for (final n in remote) {
      final existing = map[n.id];
      if (existing == null) {
        map[n.id] = n;
      } else {
        map[n.id] = existing.updatedAt.isAfter(n.updatedAt) ? existing : n;
      }
    }

    _notes
      ..clear()
      ..addAll(map.values);
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistLocal();

    for (final n in _notes) {
      if (n.hasContent) await _upsertRemote(n);
    }
    notifyListeners();
  }

  Future<void> _upsertRemote(BibleNote note) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _pendingCloudIds.add(note.id);
      return;
    }
    try {
      await client.from('bible_notes').upsert(
        {
          'id': note.id,
          'user_id': user.id,
          'book': note.book,
          'chapter': note.chapter,
          'verse': note.verse,
          'title': note.title,
          'body': note.body,
          'created_at': note.createdAt.toUtc().toIso8601String(),
          'updated_at': note.updatedAt.toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );
      _pendingCloudIds.remove(note.id);
    } catch (e) {
      _pendingCloudIds.add(note.id);
      debugPrint('note sync failed: $e');
    }
  }

  Future<void> _deleteRemote(String id) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('bible_notes')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('note delete failed: $e');
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_notes.map((n) => n.toJson()).toList());
    final ok = await prefs.setString(_prefsKey, encoded);
    if (!ok) {
      throw StateError('Failed to write notes to local storage');
    }
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_backupFileName');
        await file.writeAsString(encoded, flush: true);
      } catch (e) {
        debugPrint('NoteStore file backup failed: $e');
      }
    }
  }
}
