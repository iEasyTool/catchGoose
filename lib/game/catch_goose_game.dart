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
import 'components/slot_item_component.dart';
import 'shared/game_scene_bridge.dart';

class CatchGooseGame extends FlameGame with DragCallbacks {
  CatchGooseGame({
    this.sceneBridge,
    this.showBinBackground = false,
    this.showSlotSprite = true,
  });

  static const int slotCapacity = 7;
  static const double roundSeconds = 180;
  static const List<String> levelFiles = [
    'levels/level_001.json',
    'levels/level_002.json',
    'levels/level_003.json',
    'levels/level_004.json',
    'levels/level_005.json',
  ];
  final GameSceneBridge? sceneBridge;
  final bool showBinBackground;
  final bool showSlotSprite;

  SlotBar? _slotBar;
  TextComponent? _timerText;
  TextComponent? _levelText;
  TextComponent? _stateText;
  TextComponent? _debugText;
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
  int _levelIndex = 0;
  GameResult? _lastResult;
  String _resultMessage = '';
  BinStyle? _binStyle;
  int _binStyleIndex = 0;
  BinBackground? _binBackground;
  final List<SlotItemComponent> _slotItemComponents = [];
  int _itemSerial = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await _generateSprites();
    _binStyleIndex = 0;
    _binStyle = BinStyle.values[_binStyleIndex % BinStyle.values.length];

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
    )..priority = 15000;

    _debugText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF102030),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    )..priority = 15000;

    add(_hud!);
    add(_slotBar!);
    add(_timerText!);
    add(_levelText!);
    add(_stateText!);
    add(_debugText!);

    await _loadLevel();
    _layout();
    _ensureSpawned();
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
    _ensureSpawned();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _applyProjectedHitPositions();
    if (_isGameOver) {
      _syncSceneBridge();
      return;
    }

    _timeRemaining -= dt;
    if (_timeRemaining <= 0) {
      _timeRemaining = 0;
      _triggerGameOver('时间到', win: false);
    }
    _timerText?.text = _formatTime(_timeRemaining);
    final bridge = sceneBridge;
    if (bridge != null) {
      _debugText?.text = '3D pile:${bridge.renderedPileCount} slot:${bridge.renderedSlotCount}';
    }
    _syncSceneBridge();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_isGameOver) {
      return;
    }
    _selectionCanceled = false;
    _lastPanPosition = event.canvasPosition;

    final selected = _pickTopItem(event.canvasPosition);
    if (selected == null) {
      if (_binRect.contains(Offset(event.canvasPosition.x, event.canvasPosition.y))) {
        _cycleBinStyle();
      }
      return;
    }
    _activeItem = selected;
    _activeItem?.setHighlight(true);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_selectionCanceled) {
      return;
    }
    final position = event.canvasEndPosition;
    _lastPanPosition = position;
    if (!_binRect.contains(Offset(position.x, position.y))) {
      _cancelSelection();
      _selectionCanceled = true;
      return;
    }
    final selected = _pickTopItem(position);
    if (selected == null) {
      _activeItem?.clearHighlight();
      _activeItem = null;
      return;
    }
    final newItem = selected;
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

    _binRect = _buildBinRect();
    sceneBridge?.setBinRect(_binRect);

    _timerText?.position = Vector2(size.x / 2 - 42, 32);
    _levelText?.position = Vector2(28, 32);
    _stateText?.position = Vector2(size.x / 2, size.y / 2);
    _debugText?.position = Vector2(size.x - 170, 80);
  }

  void _spawnItems() {
    for (final entry in _levelItems) {
      final typeId = entry.typeId;
      final sprite = _sprites[typeId];
      if (sprite == null) {
        continue;
      }
      final position = Vector2(
        _binRect.left + entry.x * _binRect.width,
        _binRect.top + entry.y * _binRect.height,
      );
      final item = ItemComponent(
        renderId: 'item_${_itemSerial++}',
        typeId: typeId,
        sprite: sprite,
        position: position,
        size: Vector2(64, 64),
        depth: entry.depth,
        showVisual: false,
      );
      _remainingItems += 1;
      add(item);
    }

    if (showBinBackground) {
      final style = _binStyle ?? BinStyle.values[_levelIndex % BinStyle.values.length];
      final binBackground = BinBackground(
        position: Vector2(_binRect.left, _binRect.top),
        size: Vector2(_binRect.width, _binRect.height),
        style: style,
      );
      _binBackground = binBackground;
      add(binBackground);
    }
  }

  void _ensureSpawned() {
    if (_spawned || size.isZero() || !_levelLoaded) {
      return;
    }
    _spawned = true;
    _spawnItems();
  }

  void _spawnFlyToSlot(ItemComponent item, int targetIndex) {
    if (!showSlotSprite) {
      return;
    }
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

    final insertIndex = slotBar.insertItem(
      SlotItem(
        typeId: _activeItem!.typeId,
        sprite: _sprites[_activeItem!.typeId]!,
        sourceItemId: _activeItem!.renderId,
      ),
    );
    if (insertIndex == -1) {
      _triggerGameOver('槽位已满', win: false);
      _cancelSelection();
      return;
    }

    final item = _activeItem!;
    _cancelSelection();

    _spawnFlyToSlot(item, insertIndex);
    sceneBridge?.addSlotFlight(
      itemId: item.renderId,
      typeId: item.typeId,
      targetIndex: insertIndex,
    );
    _insertSlotItemComponent(insertIndex, item);
    _relayoutSlotItems();
    _pulseSlotItems();
    sceneBridge?.removeItem(item.renderId);
    item.removeFromParent();
    _remainingItems -= 1;

    final matched = slotBar.resolveMatches();
    if (matched.isNotEmpty) {
      _removeMatchedSlotItems(matched);
      _relayoutSlotItems();
      _pulseSlotItems();
      for (final match in matched) {
        final center = slotBar.slotCenterForIndex(match.index);
        final worldCenter = slotBar.position + center - Vector2(slotBar.size.x / 2, 0);
        final pop = MatchPop(
          sprite: match.item.sprite,
          position: worldCenter,
          size: Vector2(56, 56),
        )..priority = 14000;
        add(pop);
        pop.play(() => pop.removeFromParent());
      }
    }

    if (_remainingItems <= 0) {
      _triggerGameOver('通关', win: true);
    } else if (slotBar.isFull && matched.isEmpty) {
      _triggerGameOver('槽位已满', win: false);
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
      final label = showSlotSprite ? entry.key : '';
      final sprite = await _buildPlaceholderSprite(label, entry.value);
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

    if (label.isNotEmpty) {
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
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    return Sprite(image);
  }

  void _triggerGameOver(String message, {required bool win}) {
    _isGameOver = true;
    _resultMessage = message;
    _lastResult = win ? GameResult.win : GameResult.lose;
    _stateText?.text = message;
    _showResultOverlay();
  }

  String _formatTime(double seconds) {
    final int value = seconds.ceil().clamp(0, _levelTimerSeconds.toInt());
    final int minutes = value ~/ 60;
    final int secs = value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  late final List<_LevelItem> _levelItems = [];

  Future<void> _loadLevel() async {
    final raw = await assets.readFile(levelFiles[_levelIndex]);
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

  void _showResultOverlay() {
    if (!overlays.isActive('result')) {
      overlays.add('result');
    }
  }

  void _hideResultOverlay() {
    if (overlays.isActive('result')) {
      overlays.remove('result');
    }
  }

  bool get isWin => _lastResult == GameResult.win;
  String get resultMessage => _resultMessage;
  bool get hasNextLevel => _levelIndex < levelFiles.length - 1;

  Future<void> restartLevel() async {
    _hideResultOverlay();
    await _resetLevel();
  }

  Future<void> nextLevel() async {
    if (!hasNextLevel) {
      await restartLevel();
      return;
    }
    _levelIndex += 1;
    _hideResultOverlay();
    await _resetLevel();
  }

  Future<void> _resetLevel() async {
    _isGameOver = false;
    _lastResult = null;
    _resultMessage = '';
    _selectionCanceled = false;
    _activeItem?.clearHighlight();
    _activeItem = null;
    _lastPanPosition = null;
    _remainingItems = 0;
    _spawned = false;
    _levelLoaded = false;
    _itemSerial = 0;
    _stateText?.text = '';
    _slotBar?.clear();
    _clearSlotItemComponents();
    _binStyleIndex = (_binStyleIndex + 1) % BinStyle.values.length;
    _binStyle = BinStyle.values[_binStyleIndex];

    children.whereType<ItemComponent>().toList().forEach((c) => c.removeFromParent());
    children.whereType<FlyingItem>().toList().forEach((c) => c.removeFromParent());
    children.whereType<MatchPop>().toList().forEach((c) => c.removeFromParent());
    children.whereType<BinBackground>().toList().forEach((c) => c.removeFromParent());
    _binBackground = null;
    sceneBridge?.clear();

    await _loadLevel();
    _ensureSpawned();
  }

  void _cycleBinStyle() {
    if (!showBinBackground) {
      return;
    }
    _binStyleIndex = (_binStyleIndex + 1) % BinStyle.values.length;
    _binStyle = BinStyle.values[_binStyleIndex];
    _binBackground?.removeFromParent();
    final binBackground = BinBackground(
      position: Vector2(_binRect.left, _binRect.top),
      size: Vector2(_binRect.width, _binRect.height),
      style: _binStyle,
    );
    _binBackground = binBackground;
    add(binBackground);
  }

  void _insertSlotItemComponent(int index, ItemComponent item) {
    if (!showSlotSprite) {
      return;
    }
    final slotBar = _slotBar;
    if (slotBar == null) {
      return;
    }
    final center = slotBar.slotCenterForIndex(index);
    final worldCenter = slotBar.position + center - Vector2(slotBar.size.x / 2, 0);
    final comp = SlotItemComponent(
      typeId: item.typeId,
      sprite: item.sprite,
      position: worldCenter,
      size: Vector2(44, 44),
    );
    _slotItemComponents.insert(index, comp);
    add(comp);
  }

  void _relayoutSlotItems() {
    if (!showSlotSprite) {
      return;
    }
    final slotBar = _slotBar;
    if (slotBar == null) {
      return;
    }
    for (int i = 0; i < _slotItemComponents.length; i++) {
      final center = slotBar.slotCenterForIndex(i);
      final worldCenter = slotBar.position + center - Vector2(slotBar.size.x / 2, 0);
      _slotItemComponents[i].moveTo(worldCenter);
    }
  }

  void _pulseSlotItems() {
    if (!showSlotSprite) {
      return;
    }
    for (final comp in _slotItemComponents) {
      comp.pulse();
    }
  }

  void _removeMatchedSlotItems(List<ResolvedMatchItem> matched) {
    final indices = matched.map((m) => m.index).toSet();
    for (int i = _slotItemComponents.length - 1; i >= 0; i--) {
      if (indices.contains(i)) {
        _slotItemComponents[i].removeFromParent();
        _slotItemComponents.removeAt(i);
      }
    }
  }

  void _clearSlotItemComponents() {
    for (final comp in _slotItemComponents) {
      comp.removeFromParent();
    }
    _slotItemComponents.clear();
  }

  void _syncSceneBridge() {
    final bridge = sceneBridge;
    if (bridge == null) {
      return;
    }
    bridge.setBinRect(_binRect);
    final slotBar = _slotBar;
    if (slotBar != null) {
      final centers = List<Offset>.generate(slotCapacity, (index) {
        final localCenter = slotBar.slotCenterForIndex(index);
        final worldCenter = slotBar.position + localCenter - Vector2(slotBar.size.x / 2, 0);
        return Offset(worldCenter.x, worldCenter.y);
      });
      bridge.setSlotCenters(centers);
    } else {
      bridge.setSlotCenters(const []);
    }
    bridge.setSlots(
      slotBar?.items
              .map(
                (item) => SceneSlotSnapshot(
                  itemId: item.sourceItemId,
                  typeId: item.typeId,
                ),
              )
              .toList(growable: false) ??
          const [],
    );
    bridge.setItems(
      children.whereType<ItemComponent>().map(
        (item) => SceneItemSnapshot(
          id: item.renderId,
          typeId: item.typeId,
          x: item.scenePosition.x,
          y: item.scenePosition.y,
          size: item.size.x,
          depth: item.depth,
          highlighted: item.highlighted,
        ),
      ),
    );
  }

  ItemComponent? _pickTopItem(Vector2 point) {
    final hits = children
        .whereType<ItemComponent>()
        .where((item) => item.containsPoint(point))
        .toList(growable: false);
    if (hits.isEmpty) {
      return null;
    }
    hits.sort((a, b) {
      final da = a.hitPosition.distanceToSquared(point);
      final db = b.hitPosition.distanceToSquared(point);
      final delta = (da - db).abs();
      if (delta > 420) {
        return da.compareTo(db);
      }
      final depthCompare = a.cameraDepth.compareTo(b.cameraDepth);
      if (depthCompare != 0) {
        return depthCompare;
      }
      final yCompare = b.hitPosition.y.compareTo(a.hitPosition.y);
      if (yCompare != 0) {
        return yCompare;
      }
      return b.depth.compareTo(a.depth);
    });
    return hits.first;
  }

  void _applyProjectedHitPositions() {
    final bridge = sceneBridge;
    final centers = bridge?.projectedItemCenters;
    final depths = bridge?.projectedItemDepths;
    if (centers == null || centers.isEmpty || depths == null) {
      return;
    }
    for (final item in children.whereType<ItemComponent>()) {
      final projected = centers[item.renderId];
      final cameraDepth = depths[item.renderId];
      if (projected != null) {
        item.setHitPosition(Vector2(projected.dx, projected.dy));
      } else {
        item.setHitPosition(item.scenePosition);
      }
      if (cameraDepth != null) {
        item.setCameraDepth(cameraDepth);
      } else {
        item.setCameraDepth(double.infinity);
      }
    }
  }

  Rect _buildBinRect() {
    final left = 28.0;
    final top = 96.0;
    final width = size.x - 56.0;
    final maxBottom = size.y - 152.0;
    final height = (maxBottom - top).clamp(220.0, size.y * 0.72);
    return Rect.fromLTWH(left, top, width, height);
  }
}

enum GameResult { win, lose }

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
