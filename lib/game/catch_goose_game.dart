import 'dart:convert';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'components/item_component.dart';
import 'components/slot_bar.dart';
import 'components/flying_item.dart';
import 'components/hud_component.dart';
import 'components/match_pop.dart';
import 'components/bin_background.dart';

class CatchGooseGame extends FlameGame with DragCallbacks {
  static const int slotCapacity = 7;
  static const double roundSeconds = 180;

  SlotBar? _slotBar;
  TextComponent? _timerText;
  TextComponent? _levelText;
  TextComponent? _stateText;
  TextComponent? _bannerText;
  HudComponent? _hud;
  final Map<String, Sprite> _sprites = {};

  bool _isGameOver = false;
  double _timeRemaining = roundSeconds;
  double _levelTimerSeconds = roundSeconds;
  int _remainingItems = 0;
  bool _spawned = false;
  bool _levelLoaded = false;
  ItemComponent? _activeItem;
  Vector2? _lastPanPosition;
  Rect _binRect = Rect.zero;
  bool _selectionCanceled = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await _generateSprites();

    _hud = HudComponent(size: size);
    _slotBar = SlotBar(
      capacity: slotCapacity,
      position: Vector2(size.x / 2, size.y - 110),
      size: Vector2(size.x - 32, 96),
    )..priority = 11000;

    _timerText = TextComponent(
      text: _formatTime(_timeRemaining),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    )..priority = 12000;

    _levelText = TextComponent(
      text: '第2关',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    )..priority = 12000;

    _stateText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 36,
          fontWeight: FontWeight.w700,
        ),
      ),
      anchor: Anchor.center,
    )..priority = 13000;

    _bannerText = TextComponent(
      text: '买点调料',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      anchor: Anchor.center,
    )..priority = 12000;

    add(_hud!);
    add(_slotBar!);
    add(_timerText!);
    add(_levelText!);
    add(_stateText!);
    add(_bannerText!);

    await _loadLevel();
    _layout();
    _ensureSpawned();
  }

  @override
  Color backgroundColor() => const Color(0xFF87C7E9);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
    _ensureSpawned();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isGameOver) {
      return;
    }

    _timeRemaining -= dt;
    if (_timeRemaining <= 0) {
      _timeRemaining = 0;
      _triggerGameOver('时间到');
    }
    _timerText?.text = _formatTime(_timeRemaining);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_isGameOver) {
      return;
    }
    _selectionCanceled = false;
    _lastPanPosition = event.localPosition;

    final items = children.whereType<ItemComponent>().toList();
    final hits = items.where((item) => item.containsPoint(event.localPosition)).toList();
    if (hits.isEmpty) {
      return;
    }
    hits.sort((a, b) {
      final da = a.position.distanceToSquared(event.localPosition);
      final db = b.position.distanceToSquared(event.localPosition);
      return da.compareTo(db);
    });
    _activeItem = hits.first;
    _activeItem?.setHighlight(true);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_selectionCanceled) {
      return;
    }
    _lastPanPosition = event.localPosition;
    if (!_binRect.contains(Offset(event.localPosition.x, event.localPosition.y))) {
      _cancelSelection();
      _selectionCanceled = true;
      return;
    }
    final items = children.whereType<ItemComponent>().toList();
    final hits = items.where((item) => item.containsPoint(event.localPosition)).toList();
    if (hits.isEmpty) {
      _activeItem?.clearHighlight();
      _activeItem = null;
      return;
    }
    hits.sort((a, b) {
      final da = a.position.distanceToSquared(event.localPosition);
      final db = b.position.distanceToSquared(event.localPosition);
      return da.compareTo(db);
    });
    final newItem = hits.first;
    if (_activeItem != newItem) {
      _activeItem?.clearHighlight();
      _activeItem = newItem;
    }
    _activeItem?.setHighlight(true);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _commitSelection();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _cancelSelection();
  }

  void _layout() {
    if (size.isZero()) {
      return;
    }

    if (_hud == null) {
      return;
    }
    _hud!.size = size;
    _slotBar
      ?..position = Vector2(size.x / 2, size.y - 120)
      ..size = Vector2(size.x - 32, 96);

    final binWidth = size.x - 60;
    final binHeight = size.y * 0.55;
    final binTop = 120.0;
    _binRect = Rect.fromLTWH(30, binTop, binWidth, binHeight);

    _timerText?.position = Vector2(size.x / 2 - 42, 32);
    _levelText?.position = Vector2(28, 32);
    _bannerText?.position = Vector2(size.x / 2, 114);
    _stateText?.position = Vector2(size.x / 2, size.y / 2);
  }

  void _spawnItems() {
    final binWidth = size.x - 60;
    final binHeight = size.y * 0.55;
    final binTop = 120.0;

    for (final entry in _levelItems) {
      final typeId = entry.typeId;
      final sprite = _sprites[typeId];
      if (sprite == null) {
        continue;
      }
      final position = Vector2(
        30 + entry.x * binWidth,
        binTop + entry.y * binHeight,
      );
      final item = ItemComponent(
        typeId: typeId,
        sprite: sprite,
        position: position,
        size: Vector2(64, 64),
        depth: entry.depth,
      );
      _remainingItems += 1;
      add(item);
    }

    final binBackground = BinBackground(
      position: Vector2(_binRect.left, _binRect.top),
      size: Vector2(_binRect.width, _binRect.height),
    );
    add(binBackground);
  }

  void _ensureSpawned() {
    if (_spawned || size.isZero() || !_levelLoaded) {
      return;
    }
    _spawned = true;
    _spawnItems();
  }

  void _spawnFlyToSlot(ItemComponent item, int targetIndex) {
    final sprite = _sprites[item.typeId];
    if (sprite == null) {
      return;
    }
    final start = item.position.clone();
    final slotBar = _slotBar;
    if (slotBar == null) {
      return;
    }
    final target = slotBar.slotCenterForIndex(targetIndex);
    final worldTarget = slotBar.position + target - Vector2(slotBar.size.x / 2, 0);

    final flying = FlyingItem(sprite: sprite, position: start, size: item.size.clone());
    add(flying);
    flying.add(
      MoveEffect.to(
        worldTarget,
        EffectController(duration: 0.2, curve: Curves.easeInOut),
        onComplete: () => flying.removeFromParent(),
      ),
    );
  }

  void _cancelSelection() {
    _activeItem?.clearHighlight();
    _activeItem = null;
    _lastPanPosition = null;
  }

  void _commitSelection() {
    if (_activeItem == null || _selectionCanceled) {
      _cancelSelection();
      return;
    }
    final slotBar = _slotBar;
    final lastPos = _lastPanPosition;
    if (slotBar == null || lastPos == null) {
      _cancelSelection();
      return;
    }
    if (!_binRect.contains(Offset(lastPos.x, lastPos.y))) {
      _cancelSelection();
      return;
    }
    if (!_activeItem!.containsPoint(lastPos)) {
      _cancelSelection();
      return;
    }

    final targetIndex = slotBar.items.length;
    final accepted = slotBar.addItem(
      SlotItem(
        typeId: _activeItem!.typeId,
        sprite: _sprites[_activeItem!.typeId]!,
      ),
    );
    if (!accepted) {
      _triggerGameOver('槽位已满');
      _cancelSelection();
      return;
    }

    final item = _activeItem!;
    _cancelSelection();

    _spawnFlyToSlot(item, targetIndex);
    item.removeFromParent();
    _remainingItems -= 1;

    final matched = slotBar.resolveMatches();
    if (matched.isNotEmpty) {
      for (final match in matched) {
        final center = slotBar.slotCenterForIndex(match.index);
        final worldCenter = slotBar.position + center - Vector2(slotBar.size.x / 2, 0);
        final pop = MatchPop(
          sprite: match.item.sprite,
          position: worldCenter,
          size: Vector2(56, 56),
        );
        add(pop);
        pop.play(() => pop.removeFromParent());
      }
    }

    if (_remainingItems <= 0) {
      _triggerGameOver('通关');
    } else if (slotBar.isFull && matched.isEmpty) {
      _triggerGameOver('槽位已满');
    }
  }

  Future<void> _generateSprites() async {
    final types = <String, Color>{
      'A': const Color(0xFFE57373),
      'B': const Color(0xFF64B5F6),
      'C': const Color(0xFF81C784),
      'D': const Color(0xFFFFB74D),
      'E': const Color(0xFFBA68C8),
    };

    _sprites.clear();

    for (final entry in types.entries) {
      final sprite = await _buildPlaceholderSprite(entry.key, entry.value);
      _sprites[entry.key] = sprite;
    }
  }

  Future<Sprite> _buildPlaceholderSprite(String label, Color baseColor) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(128, 128);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect.shift(const Offset(0, 6)), shadowPaint);

    final paint = Paint()..color = baseColor;
    canvas.drawRRect(rrect, paint);

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.55), Colors.transparent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(rrect, highlightPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 44,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    return Sprite(image);
  }

  void _triggerGameOver(String message) {
    _isGameOver = true;
    _stateText?.text = message;
  }

  String _formatTime(double seconds) {
    final int value = seconds.ceil().clamp(0, _levelTimerSeconds.toInt());
    final int minutes = value ~/ 60;
    final int secs = value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  late final List<_LevelItem> _levelItems = [];

  Future<void> _loadLevel() async {
    final raw = await assets.readFile('levels/level_001.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final levelName = data['levelName'] as String? ?? '第1关';
    _levelTimerSeconds = (data['timerSeconds'] as num?)?.toDouble() ?? roundSeconds;
    _timeRemaining = _levelTimerSeconds;
    _levelText?.text = levelName;

    final items = data['items'] as List<dynamic>? ?? [];
    _levelItems
      ..clear()
      ..addAll(items.map((dynamic item) {
        final map = item as Map<String, dynamic>;
        return _LevelItem(
          typeId: map['type'] as String,
          x: (map['x'] as num).toDouble(),
          y: (map['y'] as num).toDouble(),
          depth: (map['depth'] as num).toInt(),
        );
      }));
    _levelLoaded = true;
  }
}

class _LevelItem {
  _LevelItem({
    required this.typeId,
    required this.x,
    required this.y,
    required this.depth,
  });

  final String typeId;
  final double x;
  final double y;
  final int depth;
}
