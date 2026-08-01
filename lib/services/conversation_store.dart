import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/conversation.dart';

/// Durable store for AI chats — local first, then Supabase when signed in.
class ConversationStore extends ChangeNotifier {
  ConversationStore._();
  static final ConversationStore instance = ConversationStore._();

  static const _prefsKey = 'bible_xpress_conversations_v1';
  static const _legacyFileName = 'conversations.json';
  final _uuid = const Uuid();
  final List<Conversation> _conversations = [];
  final Set<String> _pendingCloudIds = {};
  bool _loaded = false;

  List<Conversation> get conversations => List.unmodifiable(_conversations);

  /// Conversations that have at least one saved message (ready to reopen).
  List<Conversation> get savedConversations => _conversations
      .where((c) => c.messages.any((m) => m.content.trim().isNotEmpty))
      .toList(growable: false);

  bool get hasPendingCloudSync => _pendingCloudIds.isNotEmpty;
  bool get isSignedIn => Supabase.instance.client.auth.currentUser != null;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_prefsKey);

      // One-time migrate from older file-based store (mobile/desktop).
      if ((raw == null || raw.isEmpty) && !kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$_legacyFileName');
          if (await file.exists()) {
            final migrated = await file.readAsString();
            if (migrated.isNotEmpty) {
              raw = migrated;
              await prefs.setString(_prefsKey, migrated);
            }
          }
        } catch (e) {
          debugPrint('ConversationStore legacy migrate skipped: $e');
        }
      }

      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _conversations
          ..clear()
          ..addAll(
            list.cast<Map<String, dynamic>>().map(Conversation.fromJson),
          );
        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    } catch (e) {
      debugPrint('ConversationStore.load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Conversation? getConversation(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Most recent saved chat for a verse reference, if any.
  Conversation? forVerse(String book, int chapter, int verse) {
    Conversation? best;
    for (final c in _conversations) {
      if (c.book != book || c.chapter != chapter || c.verse != verse) continue;
      if (!c.messages.any((m) => m.content.trim().isNotEmpty)) continue;
      if (best == null || c.updatedAt.isAfter(best.updatedAt)) {
        best = c;
      }
    }
    return best;
  }

  bool hasChatForVerse(String book, int chapter, int verse) =>
      forVerse(book, chapter, verse) != null;

  /// Insert or replace a conversation and persist immediately (local + cloud).
  Future<Conversation> upsertConversation(Conversation conversation) async {
    await load();
    final updated = conversation.copyWith(updatedAt: DateTime.now());
    final i = _conversations.indexWhere((c) => c.id == updated.id);
    if (i >= 0) {
      // Preserve original createdAt.
      _conversations[i] = Conversation(
        id: updated.id,
        book: updated.book,
        chapter: updated.chapter,
        verse: updated.verse,
        title: updated.title,
        messages: updated.messages,
        createdAt: _conversations[i].createdAt,
        updatedAt: updated.updatedAt,
      );
    } else {
      _conversations.insert(0, updated);
    }
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistLocal();
    await _upsertRemote(_conversations.firstWhere((c) => c.id == updated.id));
    notifyListeners();
    return _conversations.firstWhere((c) => c.id == updated.id);
  }

  Future<Conversation> createConversation({
    String? id,
    required String book,
    required int chapter,
    required int verse,
    String? title,
    List<ChatMessage> messages = const [],
  }) {
    final now = DateTime.now();
    return upsertConversation(
      Conversation(
        id: id ?? _uuid.v4(),
        book: book,
        chapter: chapter,
        verse: verse,
        title: title ?? '$book $chapter:$verse',
        messages: messages,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> saveConversation(Conversation conversation) =>
      upsertConversation(conversation);

  Future<void> deleteConversation(String id) async {
    await load();
    _conversations.removeWhere((c) => c.id == id);
    _pendingCloudIds.remove(id);
    await _persistLocal();
    await _deleteRemote(id);
    notifyListeners();
  }

  /// Push any chats that failed to reach the cloud earlier.
  Future<void> retryPendingCloudSync() async {
    if (!isSignedIn) return;
    final ids = List<String>.from(_pendingCloudIds);
    for (final id in ids) {
      final c = getConversation(id);
      if (c != null) {
        await _upsertRemote(c);
      } else {
        _pendingCloudIds.remove(id);
      }
    }
    notifyListeners();
  }

  Future<void> syncFromCloud() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    await load();

    // Always push local first so nothing device-only is lost before merge.
    for (final c in List<Conversation>.from(_conversations)) {
      await _upsertRemote(c);
    }

    final rows = await client
        .from('conversations')
        .select('*, chat_messages(*)')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);

    final remote = <Conversation>[];
    for (final row in rows as List<dynamic>) {
      final r = row as Map<String, dynamic>;
      final msgs = (r['chat_messages'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(
            (m) => ChatMessage(
              id: m['id'] as String,
              role: m['role'] as String,
              content: m['content'] as String,
              createdAt:
                  DateTime.tryParse(m['created_at'] as String? ?? '') ??
                      DateTime.now(),
            ),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      remote.add(
        Conversation(
          id: r['id'] as String,
          book: r['book'] as String,
          chapter: r['chapter'] as int,
          verse: r['verse'] as int,
          title: r['title'] as String? ?? 'Saved Conversation',
          messages: msgs,
          createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }

    final map = <String, Conversation>{
      for (final c in _conversations) c.id: c,
    };
    for (final c in remote) {
      final existing = map[c.id];
      if (existing == null) {
        map[c.id] = c;
      } else {
        map[c.id] = _mergeConversations(existing, c);
      }
    }

    _conversations
      ..clear()
      ..addAll(map.values);
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistLocal();

    // Re-push merged result so both sides match.
    for (final c in _conversations) {
      await _upsertRemote(c);
    }
    notifyListeners();
  }

  Conversation _mergeConversations(Conversation a, Conversation b) {
    final byId = <String, ChatMessage>{
      for (final m in a.messages) m.id: m,
      for (final m in b.messages) m.id: m,
    };
    final messages = byId.values.toList()
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
    final newer = a.updatedAt.isAfter(b.updatedAt) ? a : b;
    final older = identical(newer, a) ? b : a;
    return Conversation(
      id: newer.id,
      book: newer.book,
      chapter: newer.chapter,
      verse: newer.verse,
      title: newer.title.isNotEmpty ? newer.title : older.title,
      messages: messages,
      createdAt: a.createdAt.isBefore(b.createdAt) ? a.createdAt : b.createdAt,
      updatedAt:
          a.updatedAt.isAfter(b.updatedAt) ? a.updatedAt : b.updatedAt,
    );
  }

  Future<void> _upsertRemote(Conversation conversation) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _pendingCloudIds.add(conversation.id);
      return;
    }
    try {
      await client.from('conversations').upsert({
        'id': conversation.id,
        'user_id': user.id,
        'book': conversation.book,
        'chapter': conversation.chapter,
        'verse': conversation.verse,
        'title': conversation.title,
        'created_at': conversation.createdAt.toIso8601String(),
        'updated_at': conversation.updatedAt.toIso8601String(),
      });

      if (conversation.messages.isNotEmpty) {
        // Upsert by id — never delete-all first (that can wipe cloud on failure).
        await client.from('chat_messages').upsert(
              conversation.messages
                  .map(
                    (m) => {
                      'id': m.id,
                      'conversation_id': conversation.id,
                      'user_id': user.id,
                      'role': m.role,
                      'content': m.content,
                      'created_at': m.createdAt.toIso8601String(),
                    },
                  )
                  .toList(),
              onConflict: 'id',
            );
      }

      // Remove remote orphans that were deleted locally.
      final remoteMsgs = await client
          .from('chat_messages')
          .select('id')
          .eq('conversation_id', conversation.id)
          .eq('user_id', user.id);
      final localIds = conversation.messages.map((m) => m.id).toSet();
      for (final row in remoteMsgs as List<dynamic>) {
        final id = (row as Map<String, dynamic>)['id'] as String;
        if (!localIds.contains(id)) {
          await client
              .from('chat_messages')
              .delete()
              .eq('id', id)
              .eq('user_id', user.id);
        }
      }

      _pendingCloudIds.remove(conversation.id);
    } catch (e) {
      _pendingCloudIds.add(conversation.id);
      debugPrint('conversation sync failed: $e');
    }
  }

  Future<void> _deleteRemote(String id) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('conversations')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('conversation delete failed: $e');
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(_conversations.map((c) => c.toJson()).toList());
    final ok = await prefs.setString(_prefsKey, encoded);
    if (!ok) {
      throw StateError('Failed to write conversations to local storage');
    }
    // Mirror to documents file as a durable backup.
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_legacyFileName');
        await file.writeAsString(encoded, flush: true);
      } catch (e) {
        debugPrint('ConversationStore file backup failed: $e');
      }
    }
  }
}
