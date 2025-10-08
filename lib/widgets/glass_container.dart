import 'package:flutter/material.dart';
import 'dart:ui';

/// A reusable glass container widget with backdrop blur effect
class GlassContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final double blur;
  final BorderRadius borderRadius;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final Widget? child;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    this.width,
    this.height,
    this.blur = 10,
    required this.borderRadius,
    required this.color,
    required this.borderColor,
    this.borderWidth = 1,
    this.child,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: gradient == null ? color : null,
              gradient: gradient,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}





