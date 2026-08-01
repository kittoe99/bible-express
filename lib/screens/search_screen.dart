import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/bible_data.dart';
import '../data/books_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_atmosphere.dart';

class _SearchResult {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  const _SearchResult({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<_SearchResult> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    await Future<void>.delayed(Duration.zero);
    final hits = <_SearchResult>[];
    for (final book in kAllBooks) {
      final chapters = chapterCount(book);
      for (var ch = 1; ch <= chapters; ch++) {
        final verses = BibleData.instance.getVerses(book, ch);
        for (final v in verses) {
          if (v.text.toLowerCase().contains(q)) {
            hits.add(
              _SearchResult(
                book: book,
                chapter: ch,
                verse: v.number,
                text: v.text,
              ),
            );
            if (hits.length >= 200) break;
          }
        }
        if (hits.length >= 200) break;
      }
      if (hits.length >= 200) break;
    }
    if (!mounted) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AtmosphereBackground(
        compact: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Search Scripture',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Word or phrase…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: _search,
                ),
              ),
              if (_searching)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: Bx.grove,
                  backgroundColor: Bx.mistDeep,
                ),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.trim().length < 2
                              ? 'Type at least 2 characters'
                              : 'No matches',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Bx.muted,
                              ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).pop((
                                book: r.book,
                                chapter: r.chapter,
                              ));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.book} ${r.chapter}:${r.verse}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: Bx.grove),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      height: 1.45,
                                      color: Bx.ink,
                                    ),
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
