import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.borderColor,
    this.blur = 10,
    this.opacity = 0.07,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(16);
    Widget card = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: br,
            border: Border.all(
              color: borderColor ?? AppColors.glassBorder,
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) card = GestureDetector(onTap: onTap, child: card);
    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}
