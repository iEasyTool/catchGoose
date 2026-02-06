import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/cupertino.dart';

enum BinStyle { roundedRect, basketRound, square }

class BinBackground extends PositionComponent {
  BinBackground({required Vector2 position, required Vector2 size, BinStyle? style})
      : style = style ?? BinStyle.values[Random().nextInt(BinStyle.values.length)],
        super(position: position, size: size, anchor: Anchor.topLeft, priority: -100);

  final BinStyle style;

  @override
  void render(Canvas canvas) {
    switch (style) {
      case BinStyle.roundedRect:
        _drawRounded(canvas);
        return;
      case BinStyle.basketRound:
        _drawBasket(canvas);
        return;
      case BinStyle.square:
        _drawSquare(canvas);
        return;
    }
  }

  void _drawRounded(Canvas canvas) {
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

    _drawInnerShadow(canvas, insetRect);
  }

  void _drawSquare(Canvas canvas) {
    final rect = size.toRect();
    final paint = Paint()..color = const Color(0xFFB95E2E);
    canvas.drawRect(rect, paint);

    final insetRect = rect.deflate(6);
    final insetPaint = Paint()..color = const Color(0xFFDD8448);
    canvas.drawRect(insetRect, insetPaint);

    _drawInnerShadow(canvas, insetRect);
  }

  void _drawBasket(Canvas canvas) {
    final rect = size.toRect();
    final center = rect.center;
    final radius = rect.shortestSide / 2;
    final basketRect = Rect.fromCircle(center: center, radius: radius);

    final base = Paint()..color = const Color(0xFFC97A3A);
    canvas.drawOval(basketRect, base);

    final rimRect = basketRect.deflate(6);
    final rimPaint = Paint()..color = const Color(0xFF9F4F28);
    canvas.drawOval(rimRect, rimPaint);

    final insetRect = basketRect.deflate(14);
    final insetPaint = Paint()..color = const Color(0xFFE3A566);
    canvas.drawOval(insetRect, insetPaint);

    _drawInnerShadow(canvas, insetRect);
  }

  void _drawInnerShadow(Canvas canvas, Rect rect) {
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
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(18)),
      innerShadowPaint,
    );
  }
}
