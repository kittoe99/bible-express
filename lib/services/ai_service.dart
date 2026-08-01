import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/verse.dart';
import 'api_key.dart';

class AIService {
  AIService._();
  static final AIService instance = AIService._();

  static const _endpoint = 'https://api.deepseek.com/chat/completions';
  static const _model = 'deepseek-v4-flash';

  static const _explainSystem = '''
You are a knowledgeable biblical scholar and theologian. You explain scripture clearly, accurately, and respectfully.
When explaining a verse:
- Provide historical and cultural context if relevant
- Explain the original meaning and significance
- Note any cross-references to other parts of the Bible
- Offer practical application for modern readers
- Keep your tone warm, scholarly, and accessible
- Be concise but thorough
Always treat the text with reverence. Use the King James Version since that's what the user is reading.
''';

  static const _followUpSystem = '''
You are a knowledgeable biblical scholar. The user is asking a follow-up question about a Bible verse you previously explained. Continue the conversation naturally, referencing the previous discussion. Be concise, clear, and respectful.
''';

  static const _religiousChatSystem = '''
You are Bible Xpress Companion — a devout, knowledgeable Christian guide for prayer, Scripture, theology, and faith.

STRICT SCOPE (non-negotiable):
- You ONLY discuss religious, biblical, theological, spiritual, and Christian-faith topics.
- If asked about anything outside that scope (politics, coding, sports, entertainment, secular advice, etc.), briefly refuse and gently redirect back to faith, Scripture, prayer, or Christian living.
- Do not provide medical, legal, or financial advice. Encourage prayer and pastoral counsel when appropriate.
- Use the King James Version when quoting Scripture, unless the user specifies another translation.
- Be warm, reverent, clear, and concise. Never mock belief or Scripture.
''';

  Stream<String> explainVerseStream({
    required String book,
    required int chapter,
    required int verse,
    required String verseText,
    required List<Verse> surrounding,
  }) async* {
    var key = await ApiKeyManager.instance.getKey();
    if (key.isEmpty) key = ApiKeyManager.defaultKey;

    final contextLines = surrounding
        .map((v) => '${v.number}. ${v.text}')
        .join('\n');
    final userPrompt = '''
Please explain this Bible verse with full context:
BOOK: $book
CHAPTER: $chapter
VERSE TO EXPLAIN: Verse $verse — $verseText

CONTEXT (surrounding verses for reference):
$contextLines
''';

    yield* _streamChat(
      apiKey: key,
      system: _explainSystem,
      messages: [
        {'role': 'user', 'content': userPrompt},
      ],
    );
  }

  Stream<String> followUpStream({
    required List<Map<String, String>> history,
    required String question,
  }) async* {
    var key = await ApiKeyManager.instance.getKey();
    if (key.isEmpty) key = ApiKeyManager.defaultKey;

    yield* _streamChat(
      apiKey: key,
      system: _followUpSystem,
      messages: [
        ...history,
        {'role': 'user', 'content': question},
      ],
    );
  }

  /// Free-form religious chatbot (not verse-explain).
  Stream<String> religiousChatStream({
    required List<Map<String, String>> history,
    required String question,
  }) async* {
    var key = await ApiKeyManager.instance.getKey();
    if (key.isEmpty) key = ApiKeyManager.defaultKey;

    yield* _streamChat(
      apiKey: key,
      system: _religiousChatSystem,
      messages: [
        ...history,
        {'role': 'user', 'content': question},
      ],
    );
  }

  Stream<String> _streamChat({
    required String apiKey,
    required String system,
    required List<Map<String, String>> messages,
  }) async* {
    yield* _streamChatOnce(apiKey: apiKey, system: system, messages: messages);
  }

  Stream<String> _streamChatOnce({
    required String apiKey,
    required String system,
    required List<Map<String, String>> messages,
    bool allowDefaultFallback = true,
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(_endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      request.body = jsonEncode({
        'model': _model,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': system},
          ...messages,
        ],
      });

      final response = await client.send(request);
      if (response.statusCode == 401) {
        // Bad custom key → clear it and retry with the built-in key.
        if (allowDefaultFallback && apiKey != ApiKeyManager.defaultKey) {
          await ApiKeyManager.instance.removeKey();
          yield* _streamChatOnce(
            apiKey: ApiKeyManager.defaultKey,
            system: system,
            messages: messages,
            allowDefaultFallback: false,
          );
          return;
        }
        yield '[Error: Invalid API key. Please check your DeepSeek API key in Settings.]';
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield '[Error: API returned status ${response.statusCode}]';
        return;
      }

      final buffer = StringBuffer();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final parts = buffer.toString().split('\n');
        buffer.clear();
        if (parts.isNotEmpty) {
          buffer.write(parts.removeLast());
        }
        for (final line in parts) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
          final data = trimmed.substring(5).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {
            // skip malformed SSE chunks
          }
        }
      }
    } catch (e) {
      yield '[Error: API error ($e)]';
    } finally {
      client.close();
    }
  }
}
