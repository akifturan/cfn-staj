import 'package:flutter/material.dart';

/// Brand mark: two overlapping circles, matching the app launcher icon.
class AppMark extends StatelessWidget {
  final double size;
  const AppMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final scale = size / 100;
    final diameter = 54 * scale;

    Widget circle(double centerX, Color color, {double opacity = 1}) {
      return Positioned(
        left: centerX * scale - diameter / 2,
        top: size / 2 - diameter / 2,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          circle(36, const Color(0xFF14213D)),
          circle(64, const Color(0xFF2DD4BF), opacity: 0.85),
        ],
      ),
    );
  }
}
