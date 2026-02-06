import 'dart:ui';

import 'package:flame/components.dart';

class HudComponent extends PositionComponent {
  HudComponent({required Vector2 size})
      : super(size: size, anchor: Anchor.topLeft, priority: 10000);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFB72D2B);
    final topRect = Rect.fromLTWH(16, 16, size.x - 32, 56);
    canvas.drawRRect(
      RRect.fromRectAndRadius(topRect, const Radius.circular(24)),
      paint,
    );

    final trayRect = Rect.fromLTWH(16, size.y - 170, size.x - 32, 160);
    final trayPaint = Paint()..color = const Color(0xFF9C632B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trayRect, const Radius.circular(24)),
      trayPaint,
    );
  }
}
