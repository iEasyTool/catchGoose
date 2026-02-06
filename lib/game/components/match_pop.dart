import 'dart:math';

import 'package:flame/components.dart';
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
        ) {
    _initParticles();
  }

  double _elapsed = 0;
  double _alpha = 1.0;
  VoidCallback? _onComplete;
  final List<_PopParticle> _particles = [];
  double _ringRadius = 0;
  double _ringAlpha = 1.0;

  void _initParticles() {
    final rand = Random();
    for (int i = 0; i < 10; i++) {
      final angle = rand.nextDouble() * pi * 2;
      final speed = 40 + rand.nextDouble() * 40;
      _particles.add(
        _PopParticle(
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        ),
      );
    }
  }

  void play(VoidCallback onComplete) {
    _onComplete = onComplete;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    const total = 0.9;
    if (_elapsed >= total) {
      _onComplete?.call();
      return;
    }

    final t = _elapsed / total;
    if (t < 0.25) {
      final s = 1.0 + (t / 0.25) * 0.55;
      scale = Vector2.all(s);
    } else {
      final s = 1.55 - ((t - 0.25) / 0.75) * 1.55;
      scale = Vector2.all(s < 0 ? 0 : s);
    }
    _alpha = 1.0 - (t * 0.85);

    _ringRadius = 10 + t * 40;
    _ringAlpha = (1.0 - t).clamp(0.0, 1.0);

    for (final p in _particles) {
      p.elapsed += dt;
      final progress = (p.elapsed / total).clamp(0.0, 1.0);
      p.position = p.velocity * progress;
    }
  }

  @override
  void render(Canvas canvas) {
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(_ringAlpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), _ringRadius, ringPaint);

    final particlePaint = Paint()..color = Colors.white.withOpacity(_alpha * 0.8);
    for (final p in _particles) {
      canvas.drawCircle(
        Offset(size.x / 2 + p.position.dx, size.y / 2 + p.position.dy),
        2.2,
        particlePaint,
      );
    }

    final paint = Paint()..color = Colors.white.withOpacity(_alpha);
    sprite?.render(canvas, size: size, overridePaint: paint);
  }
}

class _PopParticle {
  _PopParticle({required this.velocity});

  final Offset velocity;
  Offset position = Offset.zero;
  double elapsed = 0;
}
