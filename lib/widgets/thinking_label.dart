import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Shared waiting label for every AI chatbot surface.
class ThinkingLabel extends StatelessWidget {
  const ThinkingLabel({super.key});

  static const String text = 'Thinking...';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Bx.grove.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: Bx.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
