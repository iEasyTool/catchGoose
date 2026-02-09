import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class SlotItemComponent extends SpriteComponent {
  SlotItemComponent({
    required this.typeId,
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
  }) : super(
          sprite: sprite,
          position: position,
          size: size,
          anchor: Anchor.center,
          priority: 12500,
        );

  final String typeId;

  void moveTo(Vector2 target) {
    add(
      MoveEffect.to(
        target,
        EffectController(duration: 0.18, curve: Curves.easeInOut),
      ),
    );
  }

  void pulse() {
    add(
      ScaleEffect.to(
        Vector2(1.12, 1.12),
        EffectController(duration: 0.08, reverseDuration: 0.12, curve: Curves.easeOut),
      ),
    );
  }
}
