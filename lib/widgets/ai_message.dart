import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'markdown_text.dart';
import 'thinking_label.dart';

/// Shared open-text AI reply — no bubble, border, or card.
class AiAssistantMessage extends StatelessWidget {
  final String content;
  final bool thinking;
  final String? messageId;

  const AiAssistantMessage({
    super.key,
    required this.content,
    this.thinking = false,
    this.messageId,
  });

  @override
  Widget build(BuildContext context) {
    if (thinking && content.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: ThinkingLabel(),
      );
    }

    final style = GoogleFonts.plusJakartaSans(
      fontSize: 16,
      height: 1.65,
      letterSpacing: -0.15,
      color: Bx.ink,
      fontWeight: FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: MarkdownText(content, style: style),
    );
  }
}

/// Compact user bubble for follow-ups / Ask chat.
class AiUserMessage extends StatelessWidget {
  final String content;

  const AiUserMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width * 0.82).clamp(0, 420),
        ),
        decoration: const BoxDecoration(
          color: Bx.grove,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          content,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
