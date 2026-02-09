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
    final paint = Paint()..color = const Color(0xE0D46A3A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      paint,
    );

    final insetRect = rect.deflate(8);
    final insetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x0EF2A35F),
          Color(0x08D88A4C),
          Color(0x12B06F3E),
        ],
      ).createShader(insetRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(insetRect, const Radius.circular(20)),
      insetPaint,
    );

    _drawInnerShadow(canvas, insetRect);
  }

  void _drawSquare(Canvas canvas) {
    final rect = size.toRect();
    final paint = Paint()..color = const Color(0xD8B95E2E);
    canvas.drawRect(rect, paint);

    final insetRect = rect.deflate(6);
    final insetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x10EFA05E),
          Color(0x08DD8448),
          Color(0x14A86A3C),
        ],
      ).createShader(insetRect);
    canvas.drawRect(insetRect, insetPaint);

    _drawInnerShadow(canvas, insetRect);
  }

  void _drawBasket(Canvas canvas) {
    final rect = size.toRect();
    final center = rect.center;
    final radius = rect.shortestSide / 2;
    final basketRect = Rect.fromCircle(center: center, radius: radius);

    final base = Paint()..color = const Color(0xD6C97A3A);
    canvas.drawOval(basketRect, base);

    final rimRect = basketRect.deflate(6);
    final rimPaint = Paint()..color = const Color(0xD69F4F28);
    canvas.drawOval(rimRect, rimPaint);

    final insetRect = basketRect.deflate(14);
    final insetPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x10FFD5A0),
          Color(0x14E3A566),
        ],
      ).createShader(insetRect);
    canvas.drawOval(insetRect, insetPaint);

    _drawInnerShadow(canvas, insetRect);
  }

  void _drawInnerShadow(Canvas canvas, Rect rect) {
    final innerShadowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0x66000000),
          const Color(0x00000000),
          const Color(0x4A000000),
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
