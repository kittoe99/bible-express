import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Near-black canvas + faint grid + pink glow orbs (Opek-style atmosphere).
class AtmosphereBackground extends StatelessWidget {
  final Widget child;
  final bool compact;

  const AtmosphereBackground({
    super.key,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final orbA = compact ? 180.0 : 220.0;
    final orbB = compact ? 200.0 : 260.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Bx.mist),
        const Positioned.fill(child: IgnorePointer(child: _GridOverlay())),
        Positioned(
          top: compact ? -60 : -80,
          right: -60,
          child: IgnorePointer(
            child: _GlowOrb(
              size: orbA,
              color: Bx.grove.withValues(alpha: 0.18),
            ),
          ),
        ),
        Positioned(
          bottom: compact ? 40 : 120,
          left: -80,
          child: IgnorePointer(
            child: _GlowOrb(
              size: orbB,
              color: Bx.grove.withValues(alpha: 0.10),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 90, spreadRadius: 20),
        ],
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x09FFFFFF)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Brand wordmark — hero-level signal with pink italic accent.
class BrandMark extends StatelessWidget {
  final double size;
  final bool lightOnDark;

  const BrandMark({
    super.key,
    this.size = 36,
    this.lightOnDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      height: 1.05,
      letterSpacing: -0.8,
    );
    final accent = GoogleFonts.instrumentSerif(
      fontSize: size + 2,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      color: Bx.grove,
      height: 1.05,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Bible', style: base),
          TextSpan(text: ' Xpress', style: accent),
        ],
      ),
    );
  }
}
