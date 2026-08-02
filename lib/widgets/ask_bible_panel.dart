import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/bible_data.dart';
import '../data/books_data.dart';
import '../models/highlight.dart';
import '../models/verse.dart';
import '../services/highlight_store.dart';
import '../services/reading_history.dart';
import '../theme/app_theme.dart';

/// Compact Scripture reader for the Ask split view (lookup while chatting).
class AskBiblePanel extends StatefulWidget {
  const AskBiblePanel({super.key});

  @override
  State<AskBiblePanel> createState() => _AskBiblePanelState();
}

class _AskBiblePanelState extends State<AskBiblePanel> {
  late String _book;
  late int _chapter;
  final _scroll = ScrollController();
  final _store = HighlightStore.instance;

  @override
  void initState() {
    super.initState();
    final cont = ReadingHistory.instance.continueReading;
    _book = cont?.book ?? 'John';
    _chapter = cont?.chapter ?? 1;
    if (!kAllBooks.contains(_book)) {
      _book = 'John';
      _chapter = 1;
    }
    final max = chapterCount(_book);
    if (_chapter < 1 || _chapter > max) _chapter = 1;
    _store.addListener(_onHighlights);
    _store.load();
  }

  void _onHighlights() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onHighlights);
    _scroll.dispose();
    super.dispose();
  }

  void _setBook(String book) {
    setState(() {
      _book = book;
      _chapter = 1;
    });
    _scrollToTop();
  }

  void _setChapter(int chapter) {
    final max = chapterCount(_book);
    final next = chapter.clamp(1, max);
    if (next == _chapter) return;
    setState(() => _chapter = next);
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });
  }

  Future<void> _pickChapter() async {
    final max = chapterCount(_book);
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('$_book — chapter'),
          content: SizedBox(
            width: 320,
            height: 360,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: max,
              itemBuilder: (_, i) {
                final n = i + 1;
                final selected = n == _chapter;
                return InkWell(
                  onTap: () => Navigator.pop(ctx, n),
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: selected
                          ? Bx.grove.withValues(alpha: 0.2)
                          : Bx.mistDeep,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? Bx.grove : Bx.borderStrong,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Bx.grove : Bx.ink,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (chosen != null) _setChapter(chosen);
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
      book: _book,
      chapter: _chapter,
      verse: verse,
      color: color,
    );
  }

  void _onVerseLongPress(Verse verse) {
    final existing = _store.forVerse(_book, _chapter, verse.number);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.highlight),
                title: Text(
                  existing == null ? 'Highlight' : 'Change highlight',
                ),
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
                      _book,
                      _chapter,
                      verse.number,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Highlight removed from $_book $_chapter:${verse.number}',
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
                      text: '$_book $_chapter:${verse.number} ${verse.text}',
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

  Widget _buildVerseRow(Verse verse) {
    final highlight = _store.forVerse(_book, _chapter, verse.number);
    final bg = highlight == null
        ? null
        : Color(highlight.color.material.value).withValues(alpha: 0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onSecondaryTap: () => _onVerseLongPress(verse),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _onVerseLongPress(verse);
        },
        onTap: () {
          if (_store.highlightMode) {
            if (highlight == null) {
              _pickHighlight(verse.number, null);
            } else {
              _store.removeHighlight(_book, _chapter, verse.number);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${verse.number}  ',
                  style: GoogleFonts.plusJakartaSans(
                    color: Bx.grove,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
                TextSpan(
                  text: verse.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    height: 1.6,
                    color: Bx.ink,
                    letterSpacing: -0.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verses = BibleData.instance.getVerses(_book, _chapter);
    final max = chapterCount(_book);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCRIPTURE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.4,
                            color: Bx.grove,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Look up a passage while you ask.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Bx.muted,
                          ),
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
                tooltip: 'Previous chapter',
                onPressed: _chapter > 1 ? () => _setChapter(_chapter - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              TextButton(
                onPressed: _pickChapter,
                child: Text('$_chapter / $max'),
              ),
              IconButton(
                tooltip: 'Next chapter',
                onPressed:
                    _chapter < max ? () => _setChapter(_chapter + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Book',
              prefixIcon: Icon(Icons.menu_book_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _book,
                isExpanded: true,
                items: [
                  for (final name in kAllBooks)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) {
                  if (v != null) _setBook(v);
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: ListView.builder(
              key: ValueKey('$_book-$_chapter'),
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              itemCount: verses.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 4),
                    child: Text(
                      '$_book $_chapter',
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: Bx.ink,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                  );
                }
                return _buildVerseRow(verses[index - 1]);
              },
            ),
          ),
        ),
      ],
    );
  }
}
