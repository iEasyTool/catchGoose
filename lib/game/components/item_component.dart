import 'dart:ui';

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ItemComponent extends PositionComponent {
  ItemComponent({
    required this.typeId,
    required this.sprite,
    required Vector2 position,
    required Vector2 size,
    required int depth,
  })  : depth = depth,
        _basePosition = position.clone() + Vector2(0, depth * 0.6),
        _phase = Random().nextDouble() * pi * 2,
        super(position: position, size: size, priority: depth, anchor: Anchor.center);

  final String typeId;
  final Sprite sprite;
  final int depth;
  final Vector2 _basePosition;
  final double _phase;
  double _time = 0;
  bool highlighted = false;
  late final double _baseScale = (1.02 - depth * 0.003).clamp(0.85, 1.02);

  Rect get worldRect => Rect.fromCenter(
        center: Offset(position.x, position.y),
        width: size.x,
        height: size.y,
      );

  bool containsPoint(Vector2 point) => worldRect.contains(Offset(point.x, point.y));

  void clearHighlight() => highlighted = false;

  void setHighlight(bool value) => highlighted = value;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final wobble = sin(_time * 2.2 + _phase);
    final offset = Vector2(wobble * 2.0, cos(_time * 1.7 + _phase) * 1.5);
    position = _basePosition + offset;
    angle = wobble * 0.06;
    scale = Vector2.all(_baseScale);
  }

  @override
  void render(Canvas canvas) {
    final shadowRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y * 0.78),
      width: size.x * 0.72,
      height: size.y * 0.22,
    );
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(shadowRect, shadowPaint);

    sprite.render(canvas, size: size);

    if (highlighted) {
      final rect = size.toRect();
      final paint = Paint()
        ..color = const Color(0xFFFFF2B3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        paint,
      );
    }
  }
}
