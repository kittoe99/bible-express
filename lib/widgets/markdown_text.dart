import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight markdown renderer for AI replies (bold, italics, headers, lists).
class MarkdownText extends StatelessWidget {
  final String data;
  final TextStyle? style;

  const MarkdownText(this.data, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Bx.ink,
              height: 1.65,
            );
    return Text.rich(
      TextSpan(children: _parse(data, base)),
      style: base,
    );
  }

  List<InlineSpan> _parse(String text, TextStyle? base) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      TextStyle? lineStyle = base;
      if (line.startsWith('### ')) {
        line = line.substring(4);
        lineStyle = base?.copyWith(
          fontSize: (base.fontSize ?? 16) + 1,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.4,
        );
      } else if (line.startsWith('## ')) {
        line = line.substring(3);
        lineStyle = base?.copyWith(
          fontSize: (base.fontSize ?? 16) + 3,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.35,
        );
      } else if (line.startsWith('# ')) {
        line = line.substring(2);
        lineStyle = base?.copyWith(
          fontSize: (base.fontSize ?? 16) + 5,
          fontWeight: FontWeight.w700,
          color: Bx.brandSoft,
          height: 1.3,
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        line = '  •  ${line.substring(2)}';
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        line = '  $line';
      }
      spans.addAll(_inline(line, lineStyle));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }

  List<InlineSpan> _inline(String text, TextStyle? style) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: style));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: style?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ));
      } else if (token.startsWith('*')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: style?.copyWith(
            fontStyle: FontStyle.italic,
            color: Bx.brandSoft,
          ),
        ));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: style?.copyWith(
            fontFamily: 'monospace',
            fontSize: (style.fontSize ?? 16) * 0.92,
            color: Bx.grove,
            backgroundColor: Bx.mistDeep,
          ),
        ));
      }
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return spans;
  }
}
