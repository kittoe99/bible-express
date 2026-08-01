import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/bible_data.dart';
import '../data/books_data.dart';
import '../models/bible_note.dart';
import '../services/note_store.dart';
import '../services/reading_history.dart';
import '../theme/app_theme.dart';
import 'app_atmosphere.dart';

/// Full-screen document editor — create or continue a note.
Future<void> openNoteEditor(
  BuildContext context, {
  required String book,
  required int chapter,
  required int verse,
  BibleNote? existing,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NoteDocumentPage(
        book: book,
        chapter: chapter,
        verse: verse,
        existing: existing,
      ),
    ),
  );
}

/// Open a blank note document (Notes tab "+"). Uses last reading as the link.
Future<void> openBlankNote(BuildContext context) async {
  final last = ReadingHistory.instance.continueReading;
  await openNoteEditor(
    context,
    book: last?.book ?? 'Genesis',
    chapter: last?.chapter ?? 1,
    verse: last?.verse ?? 0,
  );
}

/// Chooser when a verse already has notes: continue latest, pick one, or new.
Future<void> openNoteChooser(
  BuildContext context, {
  required String book,
  required int chapter,
  required int verse,
}) async {
  final notes = NoteStore.instance.forVerse(book, chapter, verse);
  if (notes.isEmpty) {
    await openNoteEditor(
      context,
      book: book,
      chapter: chapter,
      verse: verse,
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Bx.grove),
              title: const Text('Continue last note'),
              subtitle: Text(notes.first.preview),
              onTap: () {
                Navigator.pop(ctx);
                openNoteEditor(
                  context,
                  book: book,
                  chapter: chapter,
                  verse: verse,
                  existing: notes.first,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add_rounded, color: Bx.grove),
              title: const Text('New note'),
              subtitle: Text('$book $chapter:$verse'),
              onTap: () {
                Navigator.pop(ctx);
                openNoteEditor(
                  context,
                  book: book,
                  chapter: chapter,
                  verse: verse,
                );
              },
            ),
            if (notes.length > 1) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'OTHER NOTES',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: Bx.grove,
                          letterSpacing: 1.4,
                        ),
                  ),
                ),
              ),
              ...notes.skip(1).take(6).map(
                    (n) => ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(
                        n.title.trim().isEmpty ? n.reference : n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        n.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        openNoteEditor(
                          context,
                          book: book,
                          chapter: chapter,
                          verse: verse,
                          existing: n,
                        );
                      },
                    ),
                  ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _NoteDocumentPage extends StatefulWidget {
  final String book;
  final int chapter;
  final int verse;
  final BibleNote? existing;

  const _NoteDocumentPage({
    required this.book,
    required this.chapter,
    required this.verse,
    this.existing,
  });

  @override
  State<_NoteDocumentPage> createState() => _NoteDocumentPageState();
}

class _NoteDocumentPageState extends State<_NoteDocumentPage> {
  late BibleNote _note;
  late final TextEditingController _title;
  late final TextEditingController _body;
  final _bodyFocus = FocusNode();
  Timer? _debounce;
  bool _disposed = false;
  bool _saving = false;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _note = existing;
      _title = TextEditingController(text: existing.title);
      _body = TextEditingController(text: existing.body);
    } else {
      _isNew = true;
      final now = DateTime.now();
      _note = BibleNote(
        id: '',
        book: widget.book,
        chapter: widget.chapter,
        verse: widget.verse,
        title: '',
        body: '',
        createdAt: now,
        updatedAt: now,
      );
      _title = TextEditingController();
      _body = TextEditingController();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final created = await NoteStore.instance.createNote(
          book: widget.book,
          chapter: widget.chapter,
          verse: widget.verse,
        );
        if (!_disposed && mounted) {
          setState(() => _note = created);
        }
        if (mounted) _bodyFocus.requestFocus();
      });
    }
    _title.addListener(_scheduleSave);
    _body.addListener(_scheduleSave);
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _persist);
  }

  Future<void> _persist() async {
    if (_disposed) return;
    if (_note.id.isEmpty) return;
    setState(() => _saving = true);
    final saved = await NoteStore.instance.upsertNote(
      BibleNote(
        id: _note.id,
        book: _note.book,
        chapter: _note.chapter,
        verse: _note.verse,
        title: _title.text,
        body: _body.text,
        createdAt: _note.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    if (!_disposed && mounted) {
      setState(() {
        _note = saved;
        _saving = false;
      });
    }
  }

  Future<void> _flushAndClose() async {
    _debounce?.cancel();
    await _persist();
    if (_note.id.isNotEmpty && !_note.hasContent && _isNew) {
      final stillEmpty =
          _title.text.trim().isEmpty && _body.text.trim().isEmpty;
      if (stillEmpty) {
        await NoteStore.instance.deleteNote(_note.id);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteNote() async {
    final id = _note.id;
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NoteStore.instance.deleteNote(id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _changePassage() async {
    final picked = await showModalBottomSheet<_NotePassage>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PassagePickerSheet(
        book: _note.book,
        chapter: _note.chapter,
        verse: _note.verse,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _note = BibleNote(
        id: _note.id,
        book: picked.book,
        chapter: picked.chapter,
        verse: picked.verse,
        title: _title.text,
        body: _body.text,
        createdAt: _note.createdAt,
        updatedAt: DateTime.now(),
      );
    });
    await _persist();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  String get _ref =>
      _note.verse > 0
          ? '${_note.book} ${_note.chapter}:${_note.verse}'
          : '${_note.book} ${_note.chapter}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _flushAndClose();
      },
      child: Scaffold(
        body: AtmosphereBackground(
          compact: true,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _flushAndClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: _saving ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            'Saving…',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Bx.muted),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        onSelected: (value) {
                          if (value == 'passage') _changePassage();
                          if (value == 'delete') _deleteNote();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'passage',
                            child: Text('Link to passage…'),
                          ),
                          if (_note.id.isNotEmpty)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete note'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _bodyFocus.requestFocus(),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 48),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Bx.grove,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _changePassage,
                              child: Text(
                                _ref,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  color: Bx.grove,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _title,
                            style: GoogleFonts.instrumentSerif(
                              fontSize: 32,
                              height: 1.2,
                              letterSpacing: -0.5,
                              color: Bx.ink,
                              fontWeight: FontWeight.w400,
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _bodyFocus.requestFocus(),
                            decoration: InputDecoration(
                              hintText: 'Title',
                              hintStyle: GoogleFonts.instrumentSerif(
                                fontSize: 32,
                                height: 1.2,
                                letterSpacing: -0.5,
                                color: Bx.placeholder,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _body,
                            focusNode: _bodyFocus,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              height: 1.7,
                              letterSpacing: -0.15,
                              color: Bx.ink,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Start writing…',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                height: 1.7,
                                letterSpacing: -0.15,
                                color: Bx.placeholder,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          // Extra page space so the caret isn't stuck at the fold.
                          const SizedBox(height: 280),
                        ],
                      ),
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

class _NotePassage {
  final String book;
  final int chapter;
  final int verse;

  const _NotePassage({
    required this.book,
    required this.chapter,
    required this.verse,
  });
}

/// Lightweight passage linker — only shown when the user asks to change it.
class _PassagePickerSheet extends StatefulWidget {
  final String book;
  final int chapter;
  final int verse;

  const _PassagePickerSheet({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  @override
  State<_PassagePickerSheet> createState() => _PassagePickerSheetState();
}

class _PassagePickerSheetState extends State<_PassagePickerSheet> {
  late String _book;
  late int _chapter;
  late int _verse;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _chapter = widget.chapter;
    _verse = widget.verse;
    _clampSelection();
  }

  int get _maxChapter => chapterCount(_book);

  int get _maxVerse {
    final verses = BibleData.instance.getVerses(_book, _chapter);
    return verses.isEmpty ? 0 : verses.last.number;
  }

  void _clampSelection() {
    if (_chapter < 1 || _chapter > _maxChapter) {
      _chapter = _chapter.clamp(1, _maxChapter);
    }
    final maxV = _maxVerse;
    if (_verse < 0) _verse = 0;
    if (maxV == 0) {
      _verse = 0;
    } else if (_verse > maxV) {
      _verse = maxV;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Link to passage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _book,
            decoration: const InputDecoration(labelText: 'Book'),
            dropdownColor: Bx.paper,
            items: [
              for (final name in kAllBooks)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (name) {
              if (name == null) return;
              setState(() {
                _book = name;
                _clampSelection();
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _chapter,
                  decoration: const InputDecoration(labelText: 'Chapter'),
                  dropdownColor: Bx.paper,
                  items: [
                    for (var c = 1; c <= _maxChapter; c++)
                      DropdownMenuItem(value: c, child: Text('$c')),
                  ],
                  onChanged: (c) {
                    if (c == null) return;
                    setState(() {
                      _chapter = c;
                      _clampSelection();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _verse,
                  decoration: const InputDecoration(labelText: 'Verse'),
                  dropdownColor: Bx.paper,
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Chapter'),
                    ),
                    for (var v = 1; v <= _maxVerse; v++)
                      DropdownMenuItem(value: v, child: Text('$v')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _verse = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                _NotePassage(
                  book: _book,
                  chapter: _chapter,
                  verse: _verse,
                ),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
