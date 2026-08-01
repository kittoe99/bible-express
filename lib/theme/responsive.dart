import 'package:flutter/material.dart';

/// Shared breakpoints for desktop-optimized layouts.
/// Keeps the same visual language; only spacing and column counts change.
class BxLayout {
  static const compactMax = 700.0;
  static const mediumMax = 1100.0;

  /// Library / list content column.
  static const contentMax = 1080.0;

  /// Comfortable reading measure for verse text.
  static const readingMax = 720.0;

  /// Ask / notes / history list measure.
  static const listMax = 820.0;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) =>
      widthOf(context) < compactMax;

  static bool isMedium(BuildContext context) {
    final w = widthOf(context);
    return w >= compactMax && w < mediumMax;
  }

  static bool isExpanded(BuildContext context) =>
      widthOf(context) >= mediumMax;

  /// Book grid columns: 1 on phone, 2 on tablet/laptop, 3 on wide desktop.
  static int bookColumns(BuildContext context) {
    final w = widthOf(context);
    if (w >= 1200) return 3;
    if (w >= 720) return 2;
    return 1;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = widthOf(context);
    if (w >= mediumMax) return const EdgeInsets.fromLTRB(40, 20, 40, 48);
    if (w >= compactMax) return const EdgeInsets.fromLTRB(28, 18, 28, 44);
    return const EdgeInsets.fromLTRB(20, 16, 20, 40);
  }

  /// Centers [child] and caps its width.
  static Widget constrain(
    BuildContext context, {
    required double maxWidth,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding == null
            ? child
            : Padding(padding: padding, child: child),
      ),
    );
  }
}
