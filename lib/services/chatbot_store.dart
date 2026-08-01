import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/chatbot_thread.dart';
import '../models/conversation.dart';

class ChatbotStore extends ChangeNotifier {
  ChatbotStore._();
  static final ChatbotStore instance = ChatbotStore._();

  static const _prefsKey = 'bible_xpress_chatbot_threads_v1';
  static const _backupFileName = 'chatbot_threads.json';
  final _uuid = const Uuid();
  final List<ChatbotThread> _threads = [];
  final Set<String> _pendingCloudIds = {};
  bool _loaded = false;

  List<ChatbotThread> get threads => List.unmodifiable(_threads);

  List<ChatbotThread> get savedThreads => _threads
      .where((t) => t.messages.any((m) => m.content.trim().isNotEmpty))
      .toList(growable: false);

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
          debugPrint('ChatbotStore backup migrate skipped: $e');
        }
      }

      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _threads
          ..clear()
          ..addAll(
            list.cast<Map<String, dynamic>>().map(ChatbotThread.fromJson),
          );
        _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    } catch (e) {
      debugPrint('ChatbotStore.load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  ChatbotThread? getThread(String id) {
    for (final t in _threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<ChatbotThread> createThread({String? title}) async {
    final now = DateTime.now();
    final thread = ChatbotThread(
      id: _uuid.v4(),
      title: title ?? 'New chat',
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );
    return upsertThread(thread);
  }

  Future<ChatbotThread> upsertThread(ChatbotThread thread) async {
    await load();
    final updated = thread.copyWith(updatedAt: DateTime.now());
    final i = _threads.indexWhere((t) => t.id == updated.id);
    if (i >= 0) {
      _threads[i] = ChatbotThread(
        id: updated.id,
        title: updated.title,
        messages: updated.messages,
        createdAt: _threads[i].createdAt,
        updatedAt: updated.updatedAt,
      );
    } else {
      _threads.insert(0, updated);
    }
    _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistLocal();
    final saved = _threads.firstWhere((t) => t.id == updated.id);
    await _upsertRemote(saved);
    notifyListeners();
    return saved;
  }

  Future<void> deleteThread(String id) async {
    await load();
    _threads.removeWhere((t) => t.id == id);
    _pendingCloudIds.remove(id);
    await _persistLocal();
    await _deleteRemote(id);
    notifyListeners();
  }

  Future<void> renameThread(String id, String title) async {
    final t = getThread(id);
    if (t == null) return;
    await upsertThread(t.copyWith(title: title.trim().isEmpty ? t.title : title.trim()));
  }

  /// Auto-title from the first user message if still "New chat".
  Future<void> maybeAutotitle(ChatbotThread thread) async {
    if (thread.title != 'New chat') return;
    ChatMessage? firstUser;
    for (final m in thread.messages) {
      if (m.role == 'user' && m.content.trim().isNotEmpty) {
        firstUser = m;
        break;
      }
    }
    if (firstUser == null) return;
    var title = firstUser.content.trim();
    if (title.length > 48) title = '${title.substring(0, 48)}…';
    await upsertThread(thread.copyWith(title: title));
  }

  Future<void> retryPendingCloudSync() async {
    if (!isSignedIn) return;
    for (final id in List<String>.from(_pendingCloudIds)) {
      final t = getThread(id);
      if (t != null) {
        await _upsertRemote(t);
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
    for (final t in List<ChatbotThread>.from(_threads)) {
      await _upsertRemote(t);
    }

    final rows = await client
        .from('chatbot_conversations')
        .select('*, chatbot_messages(*)')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);

    final remote = <ChatbotThread>[];
    for (final row in rows as List<dynamic>) {
      final r = row as Map<String, dynamic>;
      final msgs = (r['chatbot_messages'] as List<dynamic>? ?? [])
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
        ChatbotThread(
          id: r['id'] as String,
          title: r['title'] as String? ?? 'New chat',
          messages: msgs,
          createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }

    final map = <String, ChatbotThread>{for (final t in _threads) t.id: t};
    for (final t in remote) {
      final existing = map[t.id];
      if (existing == null) {
        map[t.id] = t;
      } else {
        map[t.id] = _merge(existing, t);
      }
    }
    _threads
      ..clear()
      ..addAll(map.values);
    _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistLocal();
    for (final t in _threads) {
      await _upsertRemote(t);
    }
    notifyListeners();
  }

  ChatbotThread _merge(ChatbotThread a, ChatbotThread b) {
    final byId = <String, ChatMessage>{
      for (final m in a.messages) m.id: m,
      for (final m in b.messages) m.id: m,
    };
    final messages = byId.values.toList()
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
    final newer = a.updatedAt.isAfter(b.updatedAt) ? a : b;
    return ChatbotThread(
      id: newer.id,
      title: newer.title,
      messages: messages,
      createdAt: a.createdAt.isBefore(b.createdAt) ? a.createdAt : b.createdAt,
      updatedAt: a.updatedAt.isAfter(b.updatedAt) ? a.updatedAt : b.updatedAt,
    );
  }

  Future<void> _upsertRemote(ChatbotThread thread) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      _pendingCloudIds.add(thread.id);
      return;
    }
    try {
      await client.from('chatbot_conversations').upsert({
        'id': thread.id,
        'user_id': user.id,
        'title': thread.title,
        'created_at': thread.createdAt.toIso8601String(),
        'updated_at': thread.updatedAt.toIso8601String(),
      });

      if (thread.messages.isNotEmpty) {
        await client.from('chatbot_messages').upsert(
              thread.messages
                  .map(
                    (m) => {
                      'id': m.id,
                      'conversation_id': thread.id,
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

      final remoteMsgs = await client
          .from('chatbot_messages')
          .select('id')
          .eq('conversation_id', thread.id)
          .eq('user_id', user.id);
      final localIds = thread.messages.map((m) => m.id).toSet();
      for (final row in remoteMsgs as List<dynamic>) {
        final id = (row as Map<String, dynamic>)['id'] as String;
        if (!localIds.contains(id)) {
          await client
              .from('chatbot_messages')
              .delete()
              .eq('id', id)
              .eq('user_id', user.id);
        }
      }
      _pendingCloudIds.remove(thread.id);
    } catch (e) {
      _pendingCloudIds.add(thread.id);
      debugPrint('chatbot sync failed: $e');
    }
  }

  Future<void> _deleteRemote(String id) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    try {
      await client
          .from('chatbot_conversations')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('chatbot delete failed: $e');
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_threads.map((t) => t.toJson()).toList());
    final ok = await prefs.setString(_prefsKey, encoded);
    if (!ok) {
      throw StateError('Failed to write chatbot threads to local storage');
    }
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$_backupFileName');
        await file.writeAsString(encoded, flush: true);
      } catch (e) {
        debugPrint('ChatbotStore file backup failed: $e');
      }
    }
  }
}
