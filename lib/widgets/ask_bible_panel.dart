import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/bible_data.dart';
import '../data/books_data.dart';
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
  }

  @override
  void dispose() {
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
                      color: selected ? Bx.grove.withValues(alpha: 0.2) : Bx.mistDeep,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? Bx.grove : Bx.borderStrong,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    final verses = BibleData.instance.getVerses(_book, _chapter);
    final max = chapterCount(_book);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
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
                final verse = verses[index - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: SelectableText.rich(
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
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
