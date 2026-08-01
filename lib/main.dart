import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'data/bible_data.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/chatbot_store.dart';
import 'services/conversation_store.dart';
import 'services/highlight_store.dart';
import 'services/note_store.dart';
import 'services/reading_history.dart';
import 'theme/app_theme.dart';
import 'widgets/app_atmosphere.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Bx.mist,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BibleXpressApp());
}

class BibleXpressApp extends StatelessWidget {
  const BibleXpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible Xpress',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _AppBootstrap(),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap>
    with SingleTickerProviderStateMixin {
  late final Future<void> _ready = _init();
  late final AnimationController _fade;
  String _status = 'Starting…';

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _status = 'Connecting…');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );

    setState(() => _status = 'Loading Scripture…');
    await BibleData.instance.load();

    setState(() => _status = 'Restoring your progress…');
    await Future.wait([
      ReadingHistory.instance.load(),
      HighlightStore.instance.load(),
      ConversationStore.instance.load(),
      ChatbotStore.instance.load(),
      NoteStore.instance.load(),
    ]);

    await AuthService.instance.init();
    if (AuthService.instance.isSignedIn) {
      setState(() => _status = 'Syncing…');
      await AuthService.instance.syncAll();
      await ConversationStore.instance.retryPendingCloudSync();
      await NoteStore.instance.retryPendingCloudSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: AtmosphereBackground(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text('Could not start Bible Xpress',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: AtmosphereBackground(
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandMark(size: 40),
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Bx.grove,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Bx.muted,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const HomeScreen();
      },
    );
  }
}
