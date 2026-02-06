import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class MatchPop extends SpriteComponent {
  MatchPop({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
  }) : super(
          sprite: sprite,
          position: position,
          size: size,
          anchor: Anchor.center,
          priority: 9000,
        );

  void play(VoidCallback onComplete) {
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.2, curve: Curves.easeIn),
      ),
    );
    add(
      TimerComponent(
        period: 0.2,
        removeOnFinish: true,
        onTick: () => onComplete(),
      ),
    );
  }
}
