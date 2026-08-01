import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyManager {
  ApiKeyManager._();
  static final ApiKeyManager instance = ApiKeyManager._();

  static const _secureKey = 'deepseek_api_key';
  static const _prefsKey = 'bible_xpress_deepseek_api_key_v1';

  /// Built-in key from the previous Bible Xpress build — used until you replace it.
  static const defaultKey = 'sk-8b2366fd8b9c40a7908a54e8f59e273a';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Always returns a usable key. Never empty.
  Future<String> getKey() async {
    try {
      final custom = await _readCustom();
      if (custom != null && custom.isNotEmpty) return custom;
    } catch (e) {
      debugPrint('ApiKeyManager.getKey custom read failed: $e');
    }
    return defaultKey;
  }

  Future<String?> _readCustom() async {
    // Prefs first — more reliable on emulators than secure storage.
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromPrefs = prefs.getString(_prefsKey)?.trim();
      if (fromPrefs != null && fromPrefs.isNotEmpty) {
        // Ignore placeholder / accidental empties.
        if (fromPrefs == 'sk-' || fromPrefs.length < 10) {
          await prefs.remove(_prefsKey);
        } else {
          return fromPrefs;
        }
      }
    } catch (e) {
      debugPrint('ApiKey prefs read failed: $e');
    }

    try {
      final stored = (await _storage.read(key: _secureKey))?.trim();
      if (stored != null && stored.isNotEmpty && stored.length >= 10) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, stored);
        return stored;
      }
      // Clear bad empty secure entries so they can't confuse later reads.
      if (stored != null && stored.isEmpty) {
        await _storage.delete(key: _secureKey);
      }
    } catch (e) {
      debugPrint('ApiKey secure read failed: $e');
    }
    return null;
  }

  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty || trimmed.length < 10) {
      await removeKey();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, trimmed);
    } catch (e) {
      debugPrint('ApiKey prefs write failed: $e');
    }
    try {
      await _storage.write(key: _secureKey, value: trimmed);
    } catch (e) {
      debugPrint('ApiKey secure write failed: $e');
    }
  }

  Future<void> removeKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
    try {
      await _storage.delete(key: _secureKey);
    } catch (_) {}
  }

  /// True when a user-provided override is stored (not just the built-in default).
  Future<bool> hasCustomKey() async {
    final custom = await _readCustom();
    return custom != null && custom.isNotEmpty;
  }

  Future<bool> hasKey() async {
    final key = await getKey();
    return key.isNotEmpty;
  }
}
