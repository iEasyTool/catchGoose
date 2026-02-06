import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/cupertino.dart';

class BinBackground extends PositionComponent {
  BinBackground({required Vector2 position, required Vector2 size})
      : super(position: position, size: size, anchor: Anchor.topLeft, priority: -100);

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final paint = Paint()..color = const Color(0xFFD46A3A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      paint,
    );

    final insetRect = rect.deflate(8);
    final insetPaint = Paint()..color = const Color(0xFFEB8A4A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(insetRect, const Radius.circular(20)),
      insetPaint,
    );

    final innerShadowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0x66000000),
          const Color(0x00000000),
          const Color(0x66000000),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(insetRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(insetRect.deflate(2), const Radius.circular(18)),
      innerShadowPaint,
    );
  }
}
