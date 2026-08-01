import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation_store.dart';
import 'chatbot_store.dart';
import 'highlight_store.dart';
import 'note_store.dart';
import 'reading_history.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  User? get user => Supabase.instance.client.auth.currentUser;
  bool get isSignedIn => user != null;
  String? get email => user?.email;

  Stream<AuthState> get authStateChanges =>
      Supabase.instance.client.auth.onAuthStateChange;

  Future<void> init() async {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      notifyListeners();
      if (data.session != null) {
        await syncAll();
      }
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final res = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
    );
    if (res.user == null) {
      throw AuthException('Sign up failed. Please try again.');
    }
    notifyListeners();
    if (res.session != null) {
      await syncAll();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    notifyListeners();
    await syncAll();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    notifyListeners();
  }

  Future<void> syncAll() async {
    try {
      await Future.wait([
        ReadingHistory.instance.syncFromCloud(),
        HighlightStore.instance.syncFromCloud(),
        ConversationStore.instance.syncFromCloud(),
        ChatbotStore.instance.syncFromCloud(),
        NoteStore.instance.syncFromCloud(),
      ]);
      await ConversationStore.instance.retryPendingCloudSync();
      await ChatbotStore.instance.retryPendingCloudSync();
      await NoteStore.instance.retryPendingCloudSync();
    } catch (e) {
      debugPrint('syncAll failed: $e');
    }
  }
}
