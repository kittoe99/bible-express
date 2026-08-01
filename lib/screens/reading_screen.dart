import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../data/bible_data.dart';
import '../data/books_data.dart';
import '../models/conversation.dart';
import '../models/highlight.dart';
import '../models/verse.dart';
import '../services/ai_service.dart';
import '../services/conversation_store.dart';
import '../services/highlight_store.dart';
import '../services/note_store.dart';
import '../services/reading_history.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/ai_message.dart';
import '../widgets/app_atmosphere.dart';
import '../widgets/note_editor.dart';

class ReadingScreen extends StatefulWidget {
  final String book;
  final int chapter;
  final String? initialConversationId;

  const ReadingScreen({
    super.key,
    required this.book,
    this.chapter = 1,
    this.initialConversationId,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late int _currentChapter;
  final _store = HighlightStore.instance;
  final _chats = ConversationStore.instance;
  final _notes = NoteStore.instance;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _store.addListener(_refresh);
    _chats.addListener(_refresh);
    _notes.addListener(_refresh);
    _store.load();
    _chats.load();
    _notes.load();
    ReadingHistory.instance.recordReading(widget.book, _currentChapter);
    if (widget.initialConversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = ConversationStore.instance
            .getConversation(widget.initialConversationId!);
        if (c != null && mounted) {
          _openAiChat(c.verse, existing: c);
        }
      });
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _store.removeListener(_refresh);
    _chats.removeListener(_refresh);
    _notes.removeListener(_refresh);
    _scroll.dispose();
    super.dispose();
  }

  int get _maxChapter => chapterCount(widget.book);

  Future<void> _goToChapter(int chapter) async {
    if (chapter < 1 || chapter > _maxChapter) return;
    setState(() => _currentChapter = chapter);
    await ReadingHistory.instance.recordReading(widget.book, chapter);
  }

  Future<void> _jumpDialog() async {
    // Desktop / wide: chapter grid. Compact: number field.
    if (!BxLayout.isCompact(context)) {
      final value = await showDialog<int>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Jump to Chapter · ${widget.book}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 1; i <= _maxChapter; i++)
                      SizedBox(
                        width: 52,
                        height: 40,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                i == _currentChapter ? Colors.white : Bx.ink,
                            backgroundColor:
                                i == _currentChapter ? Bx.grove : null,
                            side: BorderSide(
                              color: i == _currentChapter
                                  ? Bx.grove
                                  : Bx.borderStrong,
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, i),
                          child: Text('$i'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
      if (value != null) await _goToChapter(value);
      return;
    }

    final controller = TextEditingController(text: '$_currentChapter');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Chapter'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Chapter (1–$_maxChapter)',
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (value != null) await _goToChapter(value);
  }

  void _onVerseLongPress(Verse verse) {
    final existing = _store.forVerse(widget.book, _currentChapter, verse.number);
    final chat = _chats.forVerse(widget.book, _currentChapter, verse.number);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chat != null)
                ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: const Text('Open AI chat'),
                  subtitle: Text(
                    '${chat.messages.length} messages · ${chat.reference}',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAiChat(verse.number, existing: chat);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(chat == null ? 'Explain with AI' : 'New AI explanation'),
                subtitle: const Text('AI-powered verse explanations'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAiChat(verse.number);
                },
              ),
              ListTile(
                leading: Icon(
                  _notes.hasNotesForVerse(
                          widget.book, _currentChapter, verse.number)
                      ? Icons.edit_note_rounded
                      : Icons.note_add_rounded,
                  color: Bx.grove,
                ),
                title: Text(
                  _notes.hasNotesForVerse(
                          widget.book, _currentChapter, verse.number)
                      ? 'Notes'
                      : 'Add note',
                ),
                subtitle: Text(
                  _notes.hasNotesForVerse(
                          widget.book, _currentChapter, verse.number)
                      ? 'Continue or start a new note'
                      : 'Write thoughts on this verse',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  openNoteChooser(
                    context,
                    book: widget.book,
                    chapter: _currentChapter,
                    verse: verse.number,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.highlight),
                title: Text(existing == null ? 'Highlight' : 'Change highlight'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickHighlight(verse.number, existing);
                },
              ),
              if (existing != null)
                ListTile(
                  leading: const Icon(Icons.highlight_off),
                  title: const Text('Remove highlight'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _store.removeHighlight(
                      widget.book,
                      _currentChapter,
                      verse.number,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Highlight removed from ${widget.book} $_currentChapter:${verse.number}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy verse'),
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          '${widget.book} $_currentChapter:${verse.number} ${verse.text}',
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openVerseChatIfAny(Verse verse) {
    final chat = _chats.forVerse(widget.book, _currentChapter, verse.number);
    if (chat != null) {
      _openAiChat(verse.number, existing: chat);
    }
  }

  Future<void> _pickHighlight(int verse, Highlight? existing) async {
    final color = await showDialog<HighlightColor>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Highlight'),
        children: HighlightColor.values.map((c) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(c.material.value),
                ),
                const SizedBox(width: 12),
                Text(c.name),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (color == null) return;
    await _store.addHighlight(
      book: widget.book,
      chapter: _currentChapter,
      verse: verse,
      color: color,
    );
  }

  void _openAiChat(int verse, {Conversation? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AIChatSheet(
        book: widget.book,
        chapter: _currentChapter,
        verse: verse,
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verses = BibleData.instance.getVerses(widget.book, _currentChapter);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AtmosphereBackground(
        compact: true,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            'Chapter $_currentChapter',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _store.highlightMode
                          ? 'Highlight mode on'
                          : 'Highlight mode',
                      onPressed: () =>
                          _store.setHighlightMode(!_store.highlightMode),
                      icon: Icon(
                        Icons.highlight_rounded,
                        color: _store.highlightMode ? Bx.brass : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Jump to Chapter',
                      onPressed: _jumpDialog,
                      icon: const Icon(Icons.tag_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_currentChapter),
                  child: BxLayout.constrain(
                    context,
                    maxWidth: BxLayout.readingMax,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        BxLayout.isCompact(context) ? 22 : 28,
                        12,
                        BxLayout.isCompact(context) ? 22 : 28,
                        28,
                      ),
                      itemCount: verses.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.book} $_currentChapter',
                                  style: GoogleFonts.instrumentSerif(
                                    fontSize:
                                        BxLayout.isCompact(context) ? 28 : 34,
                                    fontWeight: FontWeight.w400,
                                    color: Bx.ink,
                                    height: 1.15,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return _buildVerseRow(verses[index - 1], scheme);
                      },
                    ),
                  ),
                ),
              ),
            ),
            _buildChapterNav(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseRow(Verse verse, ColorScheme scheme) {
    final highlight =
        _store.forVerse(widget.book, _currentChapter, verse.number);
    final chat = _chats.forVerse(widget.book, _currentChapter, verse.number);
    final hasNote =
        _notes.hasNotesForVerse(widget.book, _currentChapter, verse.number);
    final bg = highlight == null
        ? null
        : Color(highlight.color.material.value).withValues(alpha: 0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onSecondaryTap: () {
          _onVerseLongPress(verse);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _onVerseLongPress(verse);
        },
        onTap: () {
          if (_store.highlightMode) {
            if (highlight == null) {
              _pickHighlight(verse.number, null);
            } else {
              _store.removeHighlight(
                  widget.book, _currentChapter, verse.number);
            }
            return;
          }
          // Tapping a highlighted/explained verse reopens its saved chat.
          if (chat != null) {
            _openVerseChatIfAny(verse);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: EdgeInsets.symmetric(
            horizontal: BxLayout.isCompact(context) ? 10 : 14,
            vertical: BxLayout.isCompact(context) ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${verse.number}  ',
                        style: GoogleFonts.plusJakartaSans(
                          color: Bx.grove,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                      TextSpan(
                        text: verse.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: BxLayout.isCompact(context) ? 18 : 19,
                          height: 1.65,
                          color: Bx.ink,
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasNote) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    size: 15,
                    color: Bx.grove.withValues(alpha: 0.85),
                  ),
                ),
              ],
              if (chat != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Open AI chat',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Bx.grove.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterNav(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: Bx.paper.withValues(alpha: 0.94),
        border: const Border(
          top: BorderSide(color: Bx.borderStrong),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BxLayout.constrain(
          context,
          maxWidth: BxLayout.readingMax,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _currentChapter > 1
                      ? () => _goToChapter(_currentChapter - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _jumpDialog,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(
                            'CHAPTER',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      letterSpacing: 1.4,
                                      color: Bx.grove,
                                    ),
                          ),
                          Text(
                            '$_currentChapter of $_maxChapter',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _currentChapter < _maxChapter
                      ? () => _goToChapter(_currentChapter + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AIChatSheet extends StatefulWidget {
  final String book;
  final int chapter;
  final int verse;
  final Conversation? existing;

  const _AIChatSheet({
    required this.book,
    required this.chapter,
    required this.verse,
    this.existing,
  });

  @override
  State<_AIChatSheet> createState() => _AIChatSheetState();
}

class _AIChatSheetState extends State<_AIChatSheet> {
  final _uuid = const Uuid();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late Conversation _conversation;
  bool _streaming = false;
  String _streamBuffer = '';
  String? _streamingMessageId;
  bool _disposed = false;
  bool _verseExpanded = true;
  bool _autoCollapsedVerse = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.existing ??
        Conversation(
          id: _uuid.v4(),
          book: widget.book,
          chapter: widget.chapter,
          verse: widget.verse,
          title: '${widget.book} ${widget.chapter}:${widget.verse}',
          messages: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    // Existing chats with explanations start with the verse collapsed.
    if (widget.existing != null &&
        widget.existing!.messages
            .any((m) => m.role == 'assistant' && m.content.trim().isNotEmpty)) {
      _verseExpanded = false;
      _autoCollapsedVerse = true;
    }
    // Persist the chat shell immediately so it cannot be lost if the sheet closes.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _persist();
      if (widget.existing == null && mounted && !_disposed) {
        await _startExplanation();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // Best-effort flush of any in-progress reply before teardown.
    _commitStreamBufferSync();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _commitStreamBufferSync() {
    final partial = _streamBuffer.trim();
    if (!_streaming || partial.isEmpty) return;
    final id = _streamingMessageId ?? _uuid.v4();
    final msgs = List<ChatMessage>.from(_conversation.messages);
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
    _conversation = _conversation.copyWith(messages: msgs);
    // Fire-and-forget; store writes are awaited internally.
    ConversationStore.instance.saveConversation(_conversation);
  }

  void _collapseVerseOnceAiStarts() {
    if (_autoCollapsedVerse || !_verseExpanded) return;
    _autoCollapsedVerse = true;
    if (mounted && !_disposed) {
      setState(() => _verseExpanded = false);
    } else {
      _verseExpanded = false;
    }
  }

  Future<void> _persist() async {
    await ConversationStore.instance.saveConversation(_conversation);
  }

  Future<void> _upsertStreamingAssistant(String content) async {
    final id = _streamingMessageId ?? _uuid.v4();
    _streamingMessageId = id;
    final msgs = List<ChatMessage>.from(_conversation.messages);
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
    _conversation = _conversation.copyWith(messages: msgs);
    // Throttle disk/cloud writes while streaming (every ~800ms worth of chunks
    // is handled by callers; always persist final).
    await _persist();
  }

  Future<void> _startExplanation() async {
    final verseObj =
        BibleData.instance.getVerse(widget.book, widget.chapter, widget.verse);
    if (verseObj == null) return;
    final surrounding = BibleData.instance.surroundingVerses(
      widget.book,
      widget.chapter,
      widget.verse,
    );

    // Seed a user prompt so the conversation is never empty on disk.
    final prompt = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content:
          'Please explain ${widget.book} ${widget.chapter}:${widget.verse}',
      createdAt: DateTime.now(),
    );
    _streamingMessageId = _uuid.v4();
    setState(() {
      _conversation = _conversation.copyWith(
        messages: [..._conversation.messages, prompt],
      );
      _streaming = true;
      _streamBuffer = '';
    });
    await _persist();

    final buffer = StringBuffer();
    var lastSave = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final chunk in AIService.instance.explainVerseStream(
        book: widget.book,
        chapter: widget.chapter,
        verse: widget.verse,
        verseText: verseObj.text,
        surrounding: surrounding,
      )) {
        if (_disposed) break;
        buffer.write(chunk);
        final text = buffer.toString();
        _collapseVerseOnceAiStarts();
        setState(() => _streamBuffer = text);
        _scrollToEnd();
        final now = DateTime.now();
        if (now.difference(lastSave) > const Duration(milliseconds: 900)) {
          lastSave = now;
          await _upsertStreamingAssistant(text);
        }
      }
    } finally {
      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        _collapseVerseOnceAiStarts();
        await _upsertStreamingAssistant(reply);
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
      await _persist();
    }
  }

  Future<void> _sendFollowUp() async {
    final question = _input.text.trim();
    if (question.isEmpty || _streaming) return;
    _input.clear();

    _streamingMessageId = _uuid.v4();
    setState(() {
      _conversation = _conversation.copyWith(
        messages: [
          ..._conversation.messages,
          ChatMessage(
            id: _uuid.v4(),
            role: 'user',
            content: question,
            createdAt: DateTime.now(),
          ),
        ],
      );
      _streaming = true;
      _streamBuffer = '';
    });
    await _persist();

    final history = _conversation.messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    final prior = history.length > 1
        ? history.sublist(0, history.length - 1)
        : <Map<String, String>>[];

    final buffer = StringBuffer();
    var lastSave = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final chunk in AIService.instance.followUpStream(
        history: prior,
        question: question,
      )) {
        if (_disposed) break;
        buffer.write(chunk);
        final text = buffer.toString();
        _collapseVerseOnceAiStarts();
        setState(() => _streamBuffer = text);
        _scrollToEnd();
        final now = DateTime.now();
        if (now.difference(lastSave) > const Duration(milliseconds: 900)) {
          lastSave = now;
          await _upsertStreamingAssistant(text);
        }
      }
    } finally {
      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        _collapseVerseOnceAiStarts();
        await _upsertStreamingAssistant(reply);
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
      await _persist();
    }
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

  bool _isSeedExplainPrompt(ChatMessage m) {
    if (m.role != 'user') return false;
    final t = m.content.trim();
    return t.startsWith('Please explain ${widget.book}');
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.88;
    final verse = BibleData.instance
        .getVerse(widget.book, widget.chapter, widget.verse);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        _commitStreamBufferSync();
      },
      child: SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Chat · ${widget.book} ${widget.chapter}:${widget.verse}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _commitStreamBufferSync();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (verse != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
              child: _CollapsibleVerseTopic(
                reference: '${widget.book} ${widget.chapter}:${widget.verse}',
                verseText: '${verse.number}. ${verse.text}',
                expanded: _verseExpanded,
                onToggle: () =>
                    setState(() => _verseExpanded = !_verseExpanded),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                for (final m in _conversation.messages)
                  if (!_streaming || m.id != _streamingMessageId)
                    if (_isSeedExplainPrompt(m))
                      const SizedBox.shrink()
                    else if (m.role == 'assistant')
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
          _buildChatInput(),
        ],
      ),
    ),
    );
  }

  Widget _buildChatInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: !_streaming,
                decoration: const InputDecoration(
                  hintText: 'Ask a follow-up...',
                ),
                onSubmitted: (_) => _sendFollowUp(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _streaming ? null : _sendFollowUp,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleVerseTopic extends StatelessWidget {
  final String reference;
  final String verseText;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollapsibleVerseTopic({
    required this.reference,
    required this.verseText,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 18, color: Bx.grove),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reference,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Bx.brandSoft,
                        ),
                  ),
                ),
                Text(
                  expanded ? 'Hide verse' : 'Show verse',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Bx.grove,
                      ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Bx.grove,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  verseText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: Bx.muted,
                  ),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState: expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}

