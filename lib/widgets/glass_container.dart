import 'dart:ui';
import 'package:flutter/material.dart';

/// Liquid Glass эффект — полупрозрачный контейнер с blur и тонкой границей.
/// Используется для NavigationBar, AppBar и других элементов UI.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Alignment? gradientBegin;
  final Alignment? gradientEnd;

  const GlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 20.0,
    this.height,
    this.borderRadius,
    this.padding,
    this.gradientBegin,
    this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final glassColor = isDark
        ? cs.surface.withAlpha(160)
        : cs.surface.withAlpha(210);
    final borderColor = isDark
        ? Colors.white.withAlpha(20)
        : Colors.white.withAlpha(180);
    final tintColor = isDark
        ? cs.primary.withAlpha(10)
        : cs.primary.withAlpha(8);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: gradientBegin ?? Alignment.topLeft,
              end: gradientEnd ?? Alignment.bottomRight,
              colors: [
                glassColor,
                tintColor,
                glassColor.withAlpha(isDark ? 140 : 190),
              ],
            ),
            border: Border(
              top: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Liquid Glass AppBar — используется в виде flexibleSpace
class GlassAppBarBackground extends StatelessWidget {
  const GlassAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      cs.surface.withAlpha(200),
                      cs.surface.withAlpha(160),
                    ]
                  : [
                      cs.surface.withAlpha(230),
                      cs.surface.withAlpha(200),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withAlpha(15)
                    : cs.primary.withAlpha(20),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
