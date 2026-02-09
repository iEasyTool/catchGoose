import 'dart:ui';

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ItemComponent extends PositionComponent {
  ItemComponent({
    required this.renderId,
    required this.typeId,
    required this.sprite,
    required Vector2 position,
    required Vector2 size,
    required int depth,
    this.showVisual = false,
  })  : depth = depth,
        _basePosition = position.clone() + Vector2(0, depth * 0.6),
        _hitPosition = position.clone() + Vector2(0, depth * 0.6),
        _phase = Random().nextDouble() * pi * 2,
        super(position: position, size: size, priority: depth, anchor: Anchor.center);

  final String renderId;
  final String typeId;
  final Sprite sprite;
  final int depth;
  final bool showVisual;
  final Vector2 _basePosition;
  final Vector2 _hitPosition;
  final double _phase;
  double _cameraDepth = double.infinity;
  double _time = 0;
  bool highlighted = false;
  late final double _baseScale = (1.02 - depth * 0.003).clamp(0.85, 1.02);

  Vector2 get scenePosition => _basePosition;
  Vector2 get hitPosition => _hitPosition;
  double get cameraDepth => _cameraDepth;

  void setHitPosition(Vector2 value) {
    _hitPosition.setFrom(value);
  }

  void setCameraDepth(double value) {
    _cameraDepth = value;
  }

  Rect get worldRect => Rect.fromCenter(
        center: Offset(_hitPosition.x, _hitPosition.y),
        width: size.x,
        height: size.y,
      );

  bool containsPoint(Vector2 point) {
    final padding = showVisual ? 8.0 : 12.0;
    return worldRect.inflate(padding).contains(Offset(point.x, point.y));
  }

  void clearHighlight() => highlighted = false;

  void setHighlight(bool value) => highlighted = value;

  @override
  void update(double dt) {
    super.update(dt);
    if (!showVisual) {
      position.setFrom(_hitPosition);
      angle = 0;
      scale = Vector2.all(_baseScale);
      return;
    }
    _time += dt;
    final wobble = sin(_time * 2.2 + _phase);
    final offset = Vector2(wobble * 2.0, cos(_time * 1.7 + _phase) * 1.5);
    position = _basePosition + offset;
    angle = wobble * 0.06;
    scale = Vector2.all(_baseScale);
  }

  @override
  void render(Canvas canvas) {
    if (!showVisual) {
      return;
    }

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
