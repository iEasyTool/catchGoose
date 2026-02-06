import 'package:flame/components.dart';

class FlyingItem extends SpriteComponent {
  FlyingItem({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
  }) : super(
          sprite: sprite,
          position: position,
          size: size,
          anchor: Anchor.center,
          priority: 9999,
        );
}
