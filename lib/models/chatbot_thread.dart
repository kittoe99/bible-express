import 'conversation.dart' show ChatMessage;

/// Free-form religious chatbot thread (not tied to a verse explanation).
class ChatbotThread {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatbotThread({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatbotThread.fromJson(Map<String, dynamic> json) {
    final raw = (json['messages'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return ChatbotThread(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New chat',
      messages: raw.map(ChatMessage.fromJson).toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  ChatbotThread copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) {
    return ChatbotThread(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get preview {
    for (final m in messages.reversed) {
      if (m.content.trim().isNotEmpty) {
        final t = m.content.trim();
        return t.length > 100 ? '${t.substring(0, 100)}…' : t;
      }
    }
    return 'New religious chat';
  }
}
