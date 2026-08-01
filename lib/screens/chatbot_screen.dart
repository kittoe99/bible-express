import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/chatbot_thread.dart';
import '../models/conversation.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/chatbot_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_message.dart';
import '../widgets/app_atmosphere.dart';

/// Standalone religious chatbot — not tied to verse "Explain with AI".
class ChatbotScreen extends StatefulWidget {
  final String? initialThreadId;

  const ChatbotScreen({super.key, this.initialThreadId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _store = ChatbotStore.instance;
  ChatbotThread? _active;
  bool _openedDirectly = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _store.load().then((_) {
      if (!mounted) return;
      if (widget.initialThreadId != null) {
        setState(() {
          _active = _store.getThread(widget.initialThreadId!);
          _openedDirectly = _active != null;
        });
      }
    });
  }

  void _onStore() {
    if (!mounted) return;
    if (_active != null) {
      final refreshed = _store.getThread(_active!.id);
      setState(() => _active = refreshed);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  Future<void> _startNewChat() async {
    final thread = await _store.createThread();
    if (!mounted) return;
    setState(() {
      _active = thread;
      _openedDirectly = false;
    });
  }

  void _leaveRoom() {
    if (_openedDirectly) {
      Navigator.of(context).pop();
    } else {
      setState(() => _active = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_active != null) {
      return _ChatbotRoom(
        thread: _active!,
        onBack: _leaveRoom,
      );
    }

    final threads = _store.threads;
    final signedIn = AuthService.instance.isSignedIn;

    return Scaffold(
      body: AtmosphereBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Ask',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _startNewChat,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New chat'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Faith, Scripture, prayer, and theology — only.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Bx.muted,
                      ),
                ),
              ),
              if (!signedIn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Sign in to sync these chats across devices.',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              Expanded(
                child: threads.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.church_outlined,
                                size: 40,
                                color: Bx.grove.withValues(alpha: 0.75),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Start a religious conversation',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ask about Scripture, prayer, doctrine, or Christian living.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Bx.muted),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _startNewChat,
                                child: const Text('New chat'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: threads.length,
                        itemBuilder: (context, i) {
                          final t = threads[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _active = t),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          t.preview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
                                    onPressed: () =>
                                        _store.deleteThread(t.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatbotRoom extends StatefulWidget {
  final ChatbotThread thread;
  final VoidCallback onBack;

  const _ChatbotRoom({required this.thread, required this.onBack});

  @override
  State<_ChatbotRoom> createState() => _ChatbotRoomState();
}

class _ChatbotRoomState extends State<_ChatbotRoom> {
  final _uuid = const Uuid();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late ChatbotThread _thread;
  bool _streaming = false;
  String _streamBuffer = '';
  String? _streamingMessageId;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _thread = widget.thread;
    // Persist shell immediately so the chat cannot be lost if the user leaves.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) _persist(_thread);
    });
  }

  @override
  void didUpdateWidget(covariant _ChatbotRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.id != widget.thread.id) {
      _thread = widget.thread;
    } else if (!_streaming) {
      _thread = widget.thread;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _commitStreamBufferSync();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _commitStreamBufferSync() {
    final partial = _streamBuffer.trim();
    // Only flush an in-progress assistant reply — never recreate deleted stubs.
    if (!_streaming || partial.isEmpty) return;
    final id = _streamingMessageId ?? _uuid.v4();
    final msgs = List<ChatMessage>.from(_thread.messages);
    final idx = msgs.indexWhere((m) => m.id == id);
    final message = ChatMessage(
      id: id,
      role: 'assistant',
      content: partial,
      createdAt: DateTime.now(),
    );
    if (idx >= 0) {
      msgs[idx] = message;
    } else {
      msgs.add(message);
    }
    _thread = _thread.copyWith(messages: msgs);
    ChatbotStore.instance.upsertThread(_thread);
  }

  Future<void> _persist(ChatbotThread thread) async {
    final saved = await ChatbotStore.instance.upsertThread(thread);
    await ChatbotStore.instance.maybeAutotitle(saved);
    if (!_disposed && mounted) {
      setState(() => _thread = ChatbotStore.instance.getThread(saved.id) ?? saved);
    }
  }

  Future<void> _handleBack() async {
    _commitStreamBufferSync();
    final hasContent =
        _thread.messages.any((m) => m.content.trim().isNotEmpty);
    if (!hasContent) {
      await ChatbotStore.instance.deleteThread(_thread.id);
    } else {
      await ChatbotStore.instance.upsertThread(_thread);
    }
    if (!mounted) return;
    widget.onBack();
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _streaming) return;
    _input.clear();

    _streamingMessageId = _uuid.v4();
    final withUser = _thread.copyWith(
      messages: [
        ..._thread.messages,
        ChatMessage(
          id: _uuid.v4(),
          role: 'user',
          content: question,
          createdAt: DateTime.now(),
        ),
      ],
    );
    setState(() {
      _thread = withUser;
      _streaming = true;
      _streamBuffer = '';
    });
    await _persist(withUser);

    final history = _thread.messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    final prior = history.length > 1
        ? history.sublist(0, history.length - 1)
        : <Map<String, String>>[];

    final buffer = StringBuffer();
    var lastSave = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final chunk in AIService.instance.religiousChatStream(
        history: prior,
        question: question,
      )) {
        if (_disposed) break;
        buffer.write(chunk);
        final text = buffer.toString();
        setState(() => _streamBuffer = text);
        _scrollToEnd();
        final now = DateTime.now();
        if (now.difference(lastSave) > const Duration(milliseconds: 900)) {
          lastSave = now;
          await _upsertStreaming(text);
        }
      }
    } finally {
      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        await _upsertStreaming(reply);
      }
      if (!_disposed && mounted) {
        setState(() {
          _streaming = false;
          _streamBuffer = '';
          _streamingMessageId = null;
        });
      } else {
        _streaming = false;
        _streamBuffer = '';
        _streamingMessageId = null;
      }
      await _persist(_thread);
    }
  }

  Future<void> _upsertStreaming(String content) async {
    final id = _streamingMessageId ?? _uuid.v4();
    _streamingMessageId = id;
    final msgs = List<ChatMessage>.from(_thread.messages);
    final idx = msgs.indexWhere((m) => m.id == id);
    final message = ChatMessage(
      id: id,
      role: 'assistant',
      content: content,
      createdAt: DateTime.now(),
    );
    if (idx >= 0) {
      msgs[idx] = message;
    } else {
      msgs.add(message);
    }
    _thread = _thread.copyWith(messages: msgs);
    await _persist(_thread);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        body: AtmosphereBackground(
          compact: true,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _handleBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          _thread.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'New chat',
                        onPressed: () async {
                          _commitStreamBufferSync();
                          final t = await ChatbotStore.instance.createThread();
                          if (!mounted) return;
                          setState(() {
                            _thread = t;
                            _streaming = false;
                            _streamBuffer = '';
                            _streamingMessageId = null;
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Religious guidance only',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Bx.grove,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (_thread.messages.isEmpty && !_streaming)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Ask about a passage, prayer, doctrine, or how to walk in faith.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Bx.muted,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final m in _thread.messages)
                        if (!_streaming || m.id != _streamingMessageId)
                          if (m.role == 'assistant')
                            AiAssistantMessage(
                              content: m.content,
                              messageId: m.id,
                            )
                          else
                            AiUserMessage(content: m.content),
                      if (_streaming)
                        AiAssistantMessage(
                          content: _streamBuffer,
                          thinking: true,
                          messageId: _streamingMessageId,
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            enabled: !_streaming,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Ask in faith…',
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _streaming ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

