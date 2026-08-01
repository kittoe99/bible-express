import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../models/bible_book.dart';
import '../services/api_key.dart';
import '../services/auth_service.dart';
import '../services/chatbot_store.dart';
import '../services/conversation_store.dart';
import '../services/note_store.dart';
import '../services/reading_history.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/app_atmosphere.dart';
import '../widgets/note_editor.dart';
import 'auth_screen.dart';
import 'chatbot_screen.dart';
import 'reading_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;
  late final AnimationController _entrance;
  String _query = '';

  /// Desktop embedded reader (keeps left nav visible).
  String? _readingBook;
  int _readingChapter = 1;
  String? _readingConversationId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    AuthService.instance.addListener(_onAuth);
    ConversationStore.instance.addListener(_refresh);
    ChatbotStore.instance.addListener(_refresh);
    NoteStore.instance.addListener(_refresh);
    ReadingHistory.instance.load().then((_) {
      if (mounted) setState(() {});
    });
    ConversationStore.instance.load();
    ChatbotStore.instance.load();
    NoteStore.instance.load();
  }

  void _onAuth() => setState(() {});
  void _refresh() => setState(() {});

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuth);
    ConversationStore.instance.removeListener(_refresh);
    ChatbotStore.instance.removeListener(_refresh);
    NoteStore.instance.removeListener(_refresh);
    _tabs.dispose();
    _entrance.dispose();
    super.dispose();
  }

  List<BibleBook> get _filteredBooks {
    final books = BibleData.instance.books;
    if (_query.trim().isEmpty) return books;
    final q = _query.trim().toLowerCase();
    return books.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _openAuth() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _openSettings() async {
    final hasCustom = await ApiKeyManager.instance.hasCustomKey();
    if (!mounted) return;
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final signedIn = AuthService.instance.isSignedIn;
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Settings',
                        style: Theme.of(ctx).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      signedIn
                          ? 'Notes, chats, and highlights sync to your account.'
                          : 'Settings save on this device. Sign in to sync across devices.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'DeepSeek API key (optional)',
                        hintText: 'sk-...',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Model · deepseek-v4-flash · key stays on this device',
                      style: Theme.of(ctx).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          await ApiKeyManager.instance.saveKey(text);
                        }
                        if (signedIn) {
                          await AuthService.instance.syncAll();
                        }
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              signedIn
                                  ? 'Settings saved & synced'
                                  : 'Settings saved on this device',
                            ),
                          ),
                        );
                        setSheet(() {});
                      },
                      child: const Text('Save settings'),
                    ),
                    if (hasCustom)
                      TextButton(
                        onPressed: () async {
                          await ApiKeyManager.instance.removeKey();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Reverted to built-in key'),
                              ),
                            );
                          }
                          setSheet(() {});
                        },
                        child: const Text('Use built-in key'),
                      ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        AuthService.instance.isSignedIn
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: Bx.grove,
                      ),
                      title: Text(
                        AuthService.instance.isSignedIn
                            ? (AuthService.instance.email ?? 'Signed in')
                            : 'Not signed in',
                      ),
                      subtitle: Text(
                        AuthService.instance.isSignedIn
                            ? 'Progress, chats, and notes sync'
                            : 'Sign in to save across devices',
                      ),
                      trailing: AuthService.instance.isSignedIn
                          ? TextButton(
                              onPressed: () async {
                                await AuthService.instance.signOut();
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Sign out'),
                            )
                          : FilledButton.tonal(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _openAuth();
                              },
                              child: const Text('Sign in'),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  void _openBook(
    String book, {
    int chapter = 1,
    String? conversationId,
  }) {
    if (!BxLayout.isCompact(context)) {
      setState(() {
        _readingBook = book;
        _readingChapter = chapter;
        _readingConversationId = conversationId;
      });
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ReadingScreen(
          book: book,
          chapter: chapter,
          initialConversationId: conversationId,
        ),
        transitionsBuilder: (_, a, __, child) {
          return FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _closeReading() {
    setState(() {
      _readingBook = null;
      _readingConversationId = null;
    });
  }

  static const _destinations = [
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Library'),
    (Icons.history_outlined, Icons.history_rounded, 'History'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Ask'),
    (Icons.edit_note_outlined, Icons.edit_note_rounded, 'Notes'),
    (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Saved'),
  ];

  @override
  Widget build(BuildContext context) {
    final continueReading = ReadingHistory.instance.continueReading;
    final recent = ReadingHistory.instance.getRecent();
    final desktop = !BxLayout.isCompact(context);

    final pages = [
      _buildBooksTab(continueReading),
      _buildRecentSection(recent),
      _buildAskTab(),
      _buildNotesTab(),
      _buildConversationsTab(),
    ];

    return Scaffold(
      body: AtmosphereBackground(
        child: SafeArea(
          child: desktop
              ? _buildDesktopShell(pages)
              : _buildCompactShell(pages),
        ),
      ),
    );
  }

  Widget _buildCompactShell(List<Widget> pages) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              const Expanded(child: BrandMark(size: 30)),
              ..._headerActions(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final d in _destinations) Tab(text: d.$3),
              ],
            ),
          ),
        ),
        Expanded(child: _animatedBody(pages)),
      ],
    );
  }

  Widget _buildDesktopShell(List<Widget> pages) {
    final reading = _readingBook;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) {
            return _DesktopSideNav(
              selectedIndex: reading != null ? -1 : _tabs.index,
              onSelect: (i) {
                // Switching tabs returns to browse mode.
                if (reading != null) _closeReading();
                _tabs.animateTo(i);
              },
              actions: _headerActions(),
              destinations: _destinations,
            );
          },
        ),
        Expanded(
          child: reading != null
              ? ReadingScreen(
                  key: ValueKey(
                    '$reading-$_readingChapter-${_readingConversationId ?? ''}',
                  ),
                  book: reading,
                  chapter: _readingChapter,
                  initialConversationId: _readingConversationId,
                  embedded: true,
                  onClose: _closeReading,
                )
              : _animatedBody(pages),
        ),
      ],
    );
  }

  List<Widget> _headerActions() {
    return [
      IconButton(
        tooltip: 'Search Scripture',
        onPressed: () async {
          final result = await Navigator.of(context).push<({String book, int chapter})>(
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
          if (result != null && mounted) {
            _openBook(result.book, chapter: result.chapter);
          }
        },
        icon: const Icon(Icons.search_rounded),
      ),
      IconButton(
        tooltip: AuthService.instance.isSignedIn ? 'Account' : 'Sign in',
        onPressed:
            AuthService.instance.isSignedIn ? _openSettings : _openAuth,
        icon: Icon(
          AuthService.instance.isSignedIn
              ? Icons.person_outline_rounded
              : Icons.login_rounded,
        ),
      ),
      IconButton(
        tooltip: 'Settings',
        onPressed: _openSettings,
        icon: const Icon(Icons.tune_rounded),
      ),
    ];
  }

  Widget _animatedBody(List<Widget> pages) {
    final desktop = !BxLayout.isCompact(context);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entrance,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _entrance,
          curve: Curves.easeOutCubic,
        )),
        child: TabBarView(
          controller: _tabs,
          physics: desktop
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          children: pages,
        ),
      ),
    );
  }

  Widget _buildBooksTab(ReadingEntry? continueReading) {
    final books = _filteredBooks;
    final ot = books.where((b) => b.isOldTestament).toList();
    final nt = books.where((b) => !b.isOldTestament).toList();
    final wide = !BxLayout.isCompact(context);
    final headlineSize = wide ? 40.0 : 32.0;
    final accentSize = wide ? 42.0 : 34.0;

    return BxLayout.constrain(
      context,
      maxWidth: BxLayout.contentMax,
      child: ListView(
        padding: BxLayout.pagePadding(context),
        children: [
          Text(
            'King James Version',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 2.2,
                  color: Bx.grove,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    height: 1.15,
                    fontSize: headlineSize,
                  ),
              children: [
                TextSpan(
                  text: wide
                      ? 'Read with clarity. Ask with '
                      : 'Read with clarity.\nAsk with ',
                ),
                TextSpan(
                  text: 'wisdom.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Bx.grove,
                        fontStyle: FontStyle.italic,
                        fontSize: accentSize,
                        height: 1.15,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (continueReading != null) ...[
            _ContinueBand(
              reference: continueReading.reference,
              onTap: () => _openBook(
                continueReading.book,
                chapter: continueReading.chapter,
              ),
            ),
            const SizedBox(height: 22),
          ],
          TextField(
            decoration: const InputDecoration(
              hintText: 'Find a book…',
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 28),
          _SectionLabel('Old Testament'),
          const SizedBox(height: 8),
          _BookGrid(books: ot, onOpen: _openBook),
          const SizedBox(height: 28),
          _SectionLabel('New Testament'),
          const SizedBox(height: 8),
          _BookGrid(books: nt, onOpen: _openBook),
        ],
      ),
    );
  }

  Widget _buildRecentSection(List<ReadingEntry> recent) {
    if (recent.isEmpty) {
      return BxLayout.constrain(
        context,
        maxWidth: BxLayout.listMax,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Your reading path will appear here.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Bx.muted,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return BxLayout.constrain(
      context,
      maxWidth: BxLayout.listMax,
      child: ListView.builder(
        padding: BxLayout.pagePadding(context),
        itemCount: recent.length,
        itemBuilder: (context, i) {
          final e = recent[i];
          return _HoverInk(
            onTap: () => _openBook(e.book, chapter: e.chapter),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: i == 0 ? Bx.grove : Bx.mistDeep,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.reference,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('King James Version',
                            style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Bx.muted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAskTab() {
    final threads = ChatbotStore.instance.savedThreads;
    final signedIn = AuthService.instance.isSignedIn;
    final pending = ChatbotStore.instance.hasPendingCloudSync;
    return BxLayout.constrain(
      context,
      maxWidth: BxLayout.listMax,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              BxLayout.isCompact(context) ? 20 : 28,
              16,
              BxLayout.isCompact(context) ? 20 : 28,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAITH COMPANION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.4,
                              color: Bx.grove,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ask anything about Scripture, prayer, or Christian living.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Bx.muted,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final t = await ChatbotStore.instance.createThread();
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatbotScreen(initialThreadId: t.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          if (!signedIn || pending)
            Container(
              margin: EdgeInsets.fromLTRB(
                BxLayout.isCompact(context) ? 20 : 28,
                4,
                BxLayout.isCompact(context) ? 20 : 28,
                8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Bx.mistDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Bx.borderStrong),
              ),
              child: Row(
                children: [
                  Icon(
                    signedIn
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_off_outlined,
                    size: 18,
                    color: Bx.grove,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signedIn
                          ? 'Some chats are waiting to sync…'
                          : 'Sign in to sync faith chats across devices.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!signedIn)
                    TextButton(
                      onPressed: _openAuth,
                      child: const Text('Sign in'),
                    )
                  else
                    TextButton(
                      onPressed: () =>
                          ChatbotStore.instance.retryPendingCloudSync(),
                      child: const Text('Retry'),
                    ),
                ],
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
                            Icons.auto_stories_outlined,
                            size: 40,
                            color: Bx.grove.withValues(alpha: 0.75),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No chats yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a new religious conversation — separate from verse explanations.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Bx.muted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      BxLayout.isCompact(context) ? 20 : 28,
                      4,
                      BxLayout.isCompact(context) ? 20 : 28,
                      40,
                    ),
                    itemCount: threads.length,
                    itemBuilder: (context, i) {
                      final t = threads[i];
                      return _HoverInk(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatbotScreen(initialThreadId: t.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () =>
                                    ChatbotStore.instance.deleteThread(t.id),
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
    );
  }

  Widget _buildNotesTab() {
    final items = NoteStore.instance.savedNotes;
    final signedIn = AuthService.instance.isSignedIn;
    final pending = NoteStore.instance.hasPendingCloudSync;
    final side = BxLayout.isCompact(context) ? 20.0 : 28.0;

    return BxLayout.constrain(
      context,
      maxWidth: BxLayout.listMax,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 16, side, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR NOTES',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.4,
                              color: Bx.grove,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thoughts on verses and chapters.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Bx.muted,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: 'New note',
                  onPressed: () => openBlankNote(context),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          if (!signedIn || pending)
            Container(
              margin: EdgeInsets.fromLTRB(side, 4, side, 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Bx.mistDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Bx.borderStrong),
              ),
              child: Row(
                children: [
                  Icon(
                    signedIn
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_off_outlined,
                    size: 18,
                    color: Bx.grove,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signedIn
                          ? 'Some notes are waiting to sync…'
                          : 'Sign in to sync notes across devices.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!signedIn)
                    TextButton(
                      onPressed: _openAuth,
                      child: const Text('Sign in'),
                    )
                  else
                    TextButton(
                      onPressed: () =>
                          NoteStore.instance.retryPendingCloudSync(),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 40,
                            color: Bx.grove.withValues(alpha: 0.75),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No notes yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to start a note, or long-press a verse while reading.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Bx.muted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(side, 4, side, 40),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final n = items[i];
                      return _HoverInk(
                        onTap: () {
                          openNoteEditor(
                            context,
                            book: n.book,
                            chapter: n.chapter,
                            verse: n.verse,
                            existing: n,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title.trim().isEmpty
                                          ? n.reference
                                          : n.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.title.trim().isEmpty
                                          ? n.preview
                                          : '${n.reference} · ${n.preview}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () =>
                                    NoteStore.instance.deleteNote(n.id),
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
    );
  }

  Widget _buildConversationsTab() {
    final items = ConversationStore.instance.savedConversations;
    final signedIn = AuthService.instance.isSignedIn;
    final pending = ConversationStore.instance.hasPendingCloudSync;
    final side = BxLayout.isCompact(context) ? 20.0 : 28.0;

    if (items.isEmpty) {
      return BxLayout.constrain(
        context,
        maxWidth: BxLayout.listMax,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome,
                    size: 36, color: Bx.grove.withValues(alpha: 0.7)),
                const SizedBox(height: 14),
                Text(
                  'No verse chats yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Long-press any verse and choose Explain with AI.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Bx.muted,
                      ),
                ),
                if (!signedIn) ...[
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: _openAuth,
                    child: const Text('Sign in to sync chats'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return BxLayout.constrain(
      context,
      maxWidth: BxLayout.listMax,
      child: Column(
        children: [
          if (!signedIn || pending)
            Container(
              margin: EdgeInsets.fromLTRB(side, 12, side, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Bx.mistDeep,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Bx.borderStrong),
              ),
              child: Row(
                children: [
                  Icon(
                    signedIn
                        ? Icons.cloud_sync_outlined
                        : Icons.cloud_off_outlined,
                    color: Bx.grove,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signedIn
                          ? 'Syncing chats…'
                          : 'Sign in so chats follow you',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (signedIn)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          ConversationStore.instance.retryPendingCloudSync(),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    )
                  else
                    TextButton(
                        onPressed: _openAuth, child: const Text('Sign in')),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(side, 12, side, 40),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final c = items[i];
                final preview = c.messages
                    .where((m) =>
                        m.role == 'assistant' && m.content.trim().isNotEmpty)
                    .map((m) => m.content.trim())
                    .followedBy(
                      c.messages
                          .where((m) => m.content.trim().isNotEmpty)
                          .map((m) => m.content.trim()),
                    )
                    .firstOrNull;
                return _HoverInk(
                  onTap: () {
                    _openBook(
                      c.book,
                      chapter: c.chapter,
                      conversationId: c.id,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                preview == null
                                    ? c.reference
                                    : '${c.reference}  ·  ${preview.length > 90 ? '${preview.substring(0, 90)}…' : preview}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => ConversationStore.instance
                              .deleteConversation(c.id),
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
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.6,
            color: Bx.grove,
          ),
    );
  }
}

/// Left rail for desktop — same 5 destinations, Bx pink active state.
class _DesktopSideNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<Widget> actions;
  final List<(IconData, IconData, String)> destinations;

  const _DesktopSideNav({
    required this.selectedIndex,
    required this.onSelect,
    required this.actions,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final wide = BxLayout.isExpanded(context);
    final railWidth = wide ? 220.0 : 88.0;

    return Container(
      width: railWidth,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Bx.borderStrong),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 20 : 12, 16, wide ? 16 : 12, 20),
            child: wide
                ? const BrandMark(size: 26)
                : Center(
                    child: Text(
                      'Bx',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Bx.grove,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 8),
              itemCount: destinations.length,
              itemBuilder: (context, i) {
                final d = destinations[i];
                final selected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 14 : 0,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Bx.grove.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Bx.grove.withValues(alpha: 0.35)
                                : Colors.transparent,
                          ),
                        ),
                        child: wide
                            ? Row(
                                children: [
                                  Icon(
                                    selected ? d.$2 : d.$1,
                                    size: 20,
                                    color: selected ? Bx.grove : Bx.muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      d.$3,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: selected
                                                ? Bx.ink
                                                : Bx.muted,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  if (selected)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Bx.grove,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              )
                            : Column(
                                children: [
                                  Icon(
                                    selected ? d.$2 : d.$1,
                                    size: 22,
                                    color: selected ? Bx.grove : Bx.muted,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    d.$3,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: selected
                                              ? Bx.grove
                                              : Bx.muted,
                                          letterSpacing: 0.2,
                                          fontSize: 10,
                                        ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 8 : 4, 8, wide ? 8 : 4, 12),
            child: wide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: actions,
                  )
                : Column(
                    children: actions,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Multi-column book list that keeps the original flat ink-row style.
class _BookGrid extends StatelessWidget {
  final List<BibleBook> books;
  final void Function(String book) onOpen;

  const _BookGrid({required this.books, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No books match your search.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Bx.muted,
              ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = BxLayout.bookColumns(context);
        const gap = 12.0;
        if (cols == 1) {
          return Column(
            children: [
              for (final book in books)
                _BookTile(book: book, onOpen: onOpen),
            ],
          );
        }

        final colWidth =
            (constraints.maxWidth - gap * (cols - 1)) / cols;
        final rows = <Widget>[];
        for (var i = 0; i < books.length; i += cols) {
          final slice = books.skip(i).take(cols).toList();
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: i + cols < books.length ? 4 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: colWidth,
                      child: c < slice.length
                          ? _BookTile(book: slice[c], onOpen: onOpen)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _BookTile extends StatelessWidget {
  final BibleBook book;
  final void Function(String book) onOpen;

  const _BookTile({required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _HoverInk(
      onTap: () => onOpen(book.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${book.chapters} chapters',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_outward_rounded,
              size: 18,
              color: Bx.grove.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverInk extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverInk({required this.child, required this.onTap});

  @override
  State<_HoverInk> createState() => _HoverInkState();
}

class _HoverInkState extends State<_HoverInk> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: _hovered ? Bx.mistDeep.withValues(alpha: 0.65) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? Bx.borderHover : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ContinueBand extends StatefulWidget {
  final String reference;
  final VoidCallback onTap;

  const _ContinueBand({required this.reference, required this.onTap});

  @override
  State<_ContinueBand> createState() => _ContinueBandState();
}

class _ContinueBandState extends State<_ContinueBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Transform.translate(
          offset: Offset(0, -1.5 * t),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB30049), Bx.grove, Color(0xFFFF3387)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Bx.grove.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTINUE READING',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Bx.brandSoft,
                                letterSpacing: 1.8,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.reference,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'King James Version',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
