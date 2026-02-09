import 'dart:math';

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/model.dart';
import 'package:flame_3d/parser.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutter/material.dart' hide Matrix4;

import 'materials/mobile_spatial_material.dart';
import 'shared/game_scene_bridge.dart';

class CatchGoose3DGame extends FlameGame3D<World3D, CameraComponent3D> {
  CatchGoose3DGame({
    required this.sceneBridge,
  })
      : super(
          world: World3D(clearColor: const Color(0xFF87C7E9)),
          camera: CameraComponent3D(),
        );

  final GameSceneBridge sceneBridge;
  final Map<String, Model> _modelsByTypedAsset = {};
  final Map<String, double> _normalizationByTypedAsset = {};
  final Map<String, ModelComponent> _componentsById = {};
  final Map<int, ModelComponent> _slotComponentsByIndex = {};
  final Map<int, String> _slotItemIdByIndex = {};
  final Map<int, Vector3> _slotBaseByIndex = {};
  final Map<int, double> _slotPhaseByIndex = {};
  final Map<String, _SlotFlightState> _flightsByItemId = {};
  final Map<String, double> _yawById = {};
  double _time = 0;

  static const _binWorldWidth = 3.2;
  static const _binWorldDepth = 2.7;
  static const _baseHeight = 0.05;
  static const _slotPlaneY = -1.35;
  static const _slotWorldY = -1.35;
  static const _slotWorldZ = 2.4;
  static const _slotSpacing = 0.56;
  static const _slotCount = 7;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera
      ..position = Vector3(0, 4.9, 6.2)
      ..target = Vector3(0, 1.1, 0);

    for (final entry in _assetsByType.entries) {
      final typeId = entry.key;
      final tint = _typeTint[typeId] ?? const Color(0xFFFFFFFF);
      for (final asset in entry.value) {
        final key = _typedKey(typeId, asset);
        if (_modelsByTypedAsset.containsKey(key)) {
          continue;
        }
        final model = await ModelParser.parse(asset);
        _replaceSurfaceMaterials(model, tint);
        _modelsByTypedAsset[key] = model;
        _normalizationByTypedAsset[key] = _computeModelNormalization(model);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _syncComponentsFromBridge();
    _advanceSlotFlights(dt);
    _animateSlotIdle();
    _publishProjectedItemCenters();
    sceneBridge.setRenderStats(
      pileCount: _componentsById.length,
      slotCount: _slotComponentsByIndex.length,
    );
  }

  void _replaceSurfaceMaterials(Model model, Color tint) {
    for (final node in model.nodes.values) {
      final mesh = node.mesh;
      if (mesh == null) {
        continue;
      }
      for (final surface in mesh.surfaces) {
        final sourceMaterial = surface.material;
        if (sourceMaterial is! SpatialMaterial) {
          continue;
        }
        surface.material = MobileSpatialMaterial(
          albedoColor: tint,
          albedoTexture: sourceMaterial.albedoTexture,
          metallic: 0.0,
          roughness: 1.0,
          ambientIntensity: 64,
        );
      }
    }
  }

  void _syncComponentsFromBridge() {
    if (_modelsByTypedAsset.isEmpty) {
      return;
    }

    final flightEvents = sceneBridge.consumeSlotFlights();
    for (final event in flightEvents) {
      _startSlotFlight(event);
    }

    final snapshots = sceneBridge.items.toList(growable: false);
    final liveIds = snapshots.map((item) => item.id).toSet();

    for (final entry in _componentsById.entries.toList()) {
      if (!liveIds.contains(entry.key)) {
        if (_flightsByItemId.containsKey(entry.key)) {
          continue;
        }
        entry.value.removeFromParent();
        _componentsById.remove(entry.key);
        _yawById.remove(entry.key);
      }
    }

    final rect = sceneBridge.binRect;
    if (rect.width <= 1 || rect.height <= 1) {
      return;
    }

    for (final item in snapshots) {
      if (_flightsByItemId.containsKey(item.id)) {
        continue;
      }
      final modelAsset = _assetForItem(item);
      if (modelAsset == null) {
        continue;
      }
      final modelKey = _typedKey(item.typeId, modelAsset);
      final model = _modelsByTypedAsset[modelKey];
      if (model == null) {
        continue;
      }

      final target = _mapToWorld(item);
      final scaleValue = _computeScale(item, rect, modelKey);
      final yaw = _yawById.putIfAbsent(item.id, () => _seededYaw(item.id));
      final idleYawSway = sin(_time * 1.05 + yaw * 3.0) * 0.055;

      final component = _componentsById[item.id];
      if (component == null) {
        final created = ModelComponent(
          model: model,
          position: target,
          scale: Vector3.all(scaleValue),
          rotation: Quaternion.axisAngle(Vector3(0, 1, 0), yaw + idleYawSway),
        );
        _componentsById[item.id] = created;
        world.add(created);
      } else {
        component.position.setFrom(target);
        final highlightScale = item.highlighted ? scaleValue * 1.33 : scaleValue;
        component.scale.setValues(highlightScale, highlightScale, highlightScale);
        component.rotation.setAxisAngle(
          Vector3(0, 1, 0),
          yaw + idleYawSway + (item.highlighted ? sin(_time * 10.2) * 0.36 : 0),
        );
      }
    }

    _syncSlotModels(sceneBridge.slots);
  }

  void _startSlotFlight(SlotFlightSnapshot event) {
    final component = _componentsById[event.itemId];
    if (component == null) {
      return;
    }
    final start = component.position.clone();
    final startScale = component.scale.x;
    final target = _slotPosition(event.targetIndex);
    final targetScale = _slotScaleForItem(event.typeId, event.itemId);
    _flightsByItemId[event.itemId] = _SlotFlightState(
      itemId: event.itemId,
      targetIndex: event.targetIndex,
      start: start,
      target: target,
      startScale: startScale,
      targetScale: targetScale,
    );
  }

  void _advanceSlotFlights(double dt) {
    if (_flightsByItemId.isEmpty) {
      return;
    }
    for (final entry in _flightsByItemId.entries.toList()) {
      final state = entry.value;
      final component = _componentsById[state.itemId];
      if (component == null) {
        _flightsByItemId.remove(state.itemId);
        continue;
      }

      state.progress += dt / 0.24;
      final clamped = state.progress.clamp(0.0, 1.0);
      final t = Curves.easeInOut.transform(clamped);
      component.position.setFrom(_lerp(state.start, state.target, t));
      component.position.y += sin(pi * t) * 0.42;

      final scale = state.startScale + (state.targetScale - state.startScale) * t;
      component.scale.setValues(scale, scale, scale);
      component.rotation.setAxisAngle(Vector3(0, 1, 0), _seededYaw(state.itemId) + t * pi * 1.4);

      if (state.progress >= 1.0) {
        component.removeFromParent();
        _componentsById.remove(state.itemId);
        _yawById.remove(state.itemId);
        _flightsByItemId.remove(state.itemId);
      }
    }
  }

  void _syncSlotModels(List<SceneSlotSnapshot> slots) {
    final blockedIndices = _flightsByItemId.values.map((f) => f.targetIndex).toSet();

    for (final entry in _slotComponentsByIndex.entries.toList()) {
      if (entry.key >= slots.length) {
        entry.value.removeFromParent();
        _slotComponentsByIndex.remove(entry.key);
        _slotItemIdByIndex.remove(entry.key);
        _slotBaseByIndex.remove(entry.key);
        _slotPhaseByIndex.remove(entry.key);
      }
    }

    for (int i = 0; i < _slotCount; i++) {
      if (blockedIndices.contains(i)) {
        final blocked = _slotComponentsByIndex.remove(i);
        blocked?.removeFromParent();
        _slotItemIdByIndex.remove(i);
        _slotBaseByIndex.remove(i);
        _slotPhaseByIndex.remove(i);
        continue;
      }
      final slot = i < slots.length ? slots[i] : null;
      if (slot == null) {
        final existing = _slotComponentsByIndex.remove(i);
        existing?.removeFromParent();
        _slotItemIdByIndex.remove(i);
        _slotBaseByIndex.remove(i);
        _slotPhaseByIndex.remove(i);
        continue;
      }
      final asset = _assetForSlot(slot.itemId, slot.typeId);
      final modelKey = asset == null ? null : _typedKey(slot.typeId, asset);
      final model = modelKey == null ? null : _modelsByTypedAsset[modelKey];
      if (model == null) {
        continue;
      }
      final position = _slotPosition(i);
      final scaleValue = _slotScaleForItem(slot.typeId, slot.itemId);

      final existingItemId = _slotItemIdByIndex[i];
      final existing = _slotComponentsByIndex[i];
      if (existing != null && existingItemId != null && existingItemId != slot.itemId) {
        existing.removeFromParent();
        _slotComponentsByIndex.remove(i);
      }

      final current = _slotComponentsByIndex[i];
      if (current == null) {
        final component = ModelComponent(
          model: model,
          position: position,
          scale: Vector3.all(scaleValue),
          rotation: Quaternion.axisAngle(Vector3(0, 1, 0), (i - 3) * 0.1),
        );
        _slotComponentsByIndex[i] = component;
        _slotItemIdByIndex[i] = slot.itemId;
        _slotBaseByIndex[i] = position;
        _slotPhaseByIndex.putIfAbsent(i, () => i * 0.7 + 0.31);
        world.add(component);
      } else {
        current.position.setFrom(position);
        current.scale.setValues(scaleValue, scaleValue, scaleValue);
        current.rotation.setAxisAngle(Vector3(0, 1, 0), (i - 3) * 0.1);
        _slotItemIdByIndex[i] = slot.itemId;
        _slotBaseByIndex[i] = position;
      }
    }
  }

  Vector3 _slotPosition(int index) {
    final centers = sceneBridge.slotCenters;
    if (index >= 0 && index < centers.length) {
      return _screenToWorldOnPlane(
        Vector2(centers[index].dx, centers[index].dy),
        _slotPlaneY,
      );
    }
    final startX = -((_slotCount - 1) * _slotSpacing) / 2;
    return Vector3(startX + index * _slotSpacing, _slotWorldY, _slotWorldZ);
  }

  double _slotScaleForItem(String typeId, String itemId) {
    final asset = _assetForSlot(itemId, typeId);
    if (asset == null) {
      return 0.26;
    }
    final key = _typedKey(typeId, asset);
    final norm = _normalizationByTypedAsset[key] ?? 1.0;
    return (0.62 * norm).clamp(0.22, 0.48);
  }

  Vector3 _screenToWorldOnPlane(Vector2 screenPoint, double planeY) {
    if (size.x <= 0 || size.y <= 0) {
      return Vector3(0, planeY, _slotWorldZ);
    }

    final xNdc = (screenPoint.x / size.x) * 2.0 - 1.0;
    final yNdc = 1.0 - (screenPoint.y / size.y) * 2.0;
    final inverseViewProjection = Matrix4.inverted(camera.viewProjectionMatrix);

    final nearClip = inverseViewProjection.transform(Vector4(xNdc, yNdc, -1.0, 1.0));
    final farClip = inverseViewProjection.transform(Vector4(xNdc, yNdc, 1.0, 1.0));
    if (nearClip.w.abs() < 1e-6 || farClip.w.abs() < 1e-6) {
      return Vector3(0, planeY, _slotWorldZ);
    }

    final nearPoint = Vector3(
      nearClip.x / nearClip.w,
      nearClip.y / nearClip.w,
      nearClip.z / nearClip.w,
    );
    final farPoint = Vector3(
      farClip.x / farClip.w,
      farClip.y / farClip.w,
      farClip.z / farClip.w,
    );

    final direction = (farPoint - nearPoint)..normalize();
    if (direction.y.abs() < 1e-6) {
      return Vector3(nearPoint.x, planeY, nearPoint.z);
    }
    final t = (planeY - nearPoint.y) / direction.y;
    return nearPoint + direction * t;
  }

  Vector3 _lerp(Vector3 a, Vector3 b, double t) {
    return Vector3(
      a.x + (b.x - a.x) * t,
      a.y + (b.y - a.y) * t,
      a.z + (b.z - a.z) * t,
    );
  }

  String? _assetForItem(SceneItemSnapshot item) {
    final variantSeed = item.id.codeUnits.fold<int>(17, (prev, unit) => prev * 31 + unit);
    return _assetForType(item.typeId, variantSeed);
  }

  String? _assetForType(String typeId, int seed) {
    final options = _assetsByType[typeId];
    if (options == null || options.isEmpty) {
      final all = _assetsByType.values.expand((list) => list).toList(growable: false);
      if (all.isEmpty) {
        return null;
      }
      return all.first;
    }
    return options[seed.abs() % options.length];
  }

  String? _assetForSlot(String itemId, String typeId) {
    final seed = itemId.codeUnits.fold<int>(17, (prev, unit) => prev * 31 + unit);
    return _assetForType(typeId, seed);
  }

  Vector3 _mapToWorld(SceneItemSnapshot item) {
    final seed = item.id.codeUnits.fold<int>(23, (p, e) => p * 37 + e).abs();
    final rowCount = 4;
    final colCount = 8;
    final gridRow = (item.depth ~/ colCount) % rowCount;
    final gridCol = item.depth % colCount;
    final gridNx = (gridCol + 0.5) / colCount;
    final gridNy = (gridRow + 0.5) / rowCount;

    // Mix the original level coordinates as a secondary influence so each
    // level still has its own feel.
    final rect = sceneBridge.binRect;
    final levelNx = ((item.x - rect.left) / rect.width).clamp(0.0, 1.0);
    final levelNy = ((item.y - rect.top) / rect.height).clamp(0.0, 1.0);

    final mixNx = gridNx * 0.72 + levelNx * 0.28;
    final mixNy = gridNy * 0.72 + levelNy * 0.28;
    final randomNx = ((seed % 100) / 100 - 0.5) * 0.12;
    final randomNy = (((seed >> 8) % 100) / 100 - 0.5) * 0.1;
    final nx = (mixNx + randomNx).clamp(0.04, 0.96);
    final ny = (mixNy + randomNy).clamp(0.04, 0.96);
    final centeredX = (nx - 0.5) * 2.0;
    final centeredY = (ny - 0.5) * 2.0;

    final layer = item.depth % 6;
    final band = item.depth ~/ 6;
    final centerPull = (0.98 - layer * 0.035 - band * 0.02).clamp(0.72, 0.98);
    final jitterAngle = (seed % 360) * pi / 180;
    final jitterRadius = 0.022 + ((seed >> 10) % 100) * 0.00045;
    final xSpread = _binWorldWidth * 0.52;
    final zSpread = _binWorldDepth * 0.42;
    final pileLift = layer * 0.11 + band * 0.018;
    final highlightLift = item.highlighted ? 0.32 : 0.0;
    final breathing = sin(_time * 1.2 + seed * 0.003) * 0.012;
    return Vector3(
      centeredX * xSpread * centerPull + cos(jitterAngle) * jitterRadius,
      _baseHeight + pileLift + highlightLift + breathing,
      centeredY * zSpread * centerPull + sin(jitterAngle) * jitterRadius * 0.9,
    );
  }

  double _computeScale(SceneItemSnapshot item, Rect rect, String modelKey) {
    final norm = _normalizationByTypedAsset[modelKey] ?? 1.0;
    final sizeRatio = (item.size / rect.width).clamp(0.05, 0.22);
    var scale = sizeRatio * _binWorldWidth * 0.9 * norm;
    if (item.highlighted) {
      scale *= 1.28;
    }
    return scale.clamp(0.15, 0.45);
  }

  void _animateSlotIdle() {
    for (final entry in _slotComponentsByIndex.entries) {
      final index = entry.key;
      final component = entry.value;
      final base = _slotBaseByIndex[index];
      if (base == null) {
        continue;
      }
      final phase = _slotPhaseByIndex[index] ?? 0.0;
      final bob = sin(_time * 1.95 + phase) * 0.028;
      final swayX = cos(_time * 1.35 + phase * 1.3) * 0.018;
      final swayZ = sin(_time * 1.65 + phase * 0.9) * 0.02;
      component.position.setValues(base.x + swayX, base.y + bob, base.z + swayZ);
      component.rotation.setAxisAngle(
        Vector3(0, 1, 0),
        (index - 3) * 0.1 + sin(_time * 1.5 + phase) * 0.075,
      );
    }
  }

  void _publishProjectedItemCenters() {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    final items = sceneBridge.items.toList(growable: false);
    if (items.isEmpty) {
      sceneBridge.setProjectedItemCenters(const {});
      sceneBridge.setProjectedItemDepths(const {});
      return;
    }
    final centers = <String, Offset>{};
    final depths = <String, double>{};
    for (final item in items) {
      final component = _componentsById[item.id];
      if (component == null) {
        continue;
      }
      final projected = _worldToScreen(component.position);
      centers[item.id] = Offset(projected.x, projected.y);
      depths[item.id] = camera.position.distanceTo(component.position);
    }
    sceneBridge.setProjectedItemCenters(centers);
    sceneBridge.setProjectedItemDepths(depths);
  }

  Vector2 _worldToScreen(Vector3 worldPosition) {
    final clip = camera.viewProjectionMatrix.transform(
      Vector4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0),
    );
    if (clip.w.abs() < 1e-6) {
      return Vector2(size.x * 0.5, size.y * 0.5);
    }
    final ndcX = clip.x / clip.w;
    final ndcY = clip.y / clip.w;
    final screenX = (ndcX + 1.0) * 0.5 * size.x;
    final screenY = (1.0 - ndcY) * 0.5 * size.y;
    return Vector2(screenX, screenY);
  }

  String _typedKey(String typeId, String asset) => '$typeId|$asset';

  double _computeModelNormalization(Model model) {
    final bounds = model.aabb;
    final sx = (bounds.max.x - bounds.min.x).abs();
    final sy = (bounds.max.y - bounds.min.y).abs();
    final sz = (bounds.max.z - bounds.min.z).abs();
    final maxDimension = [sx, sy, sz].reduce(max);
    if (maxDimension < 0.0001) {
      return 1.0;
    }
    return 1.0 / maxDimension;
  }

  double _seededYaw(String id) {
    final hash = id.codeUnits.fold<int>(17, (p, e) => p * 31 + e);
    return (hash % 360) * pi / 180;
  }

  static const Map<String, List<String>> _assetsByType = {
    'A': [
      '3d/cheese.glb',
      '3d/coockie-man.glb',
    ],
    'B': [
      '3d/hotdog.glb',
      '3d/toast.glb',
    ],
    'C': [
      '3d/sandwich.glb',
      '3d/sandwich-toast.glb',
    ],
    'D': [
      '3d/ice-cream.glb',
      '3d/coockie-man.glb',
    ],
    'E': [
      '3d/pancake-big.glb',
      '3d/toast.glb',
    ],
  };

  static const Map<String, Color> _typeTint = {
    'A': Color(0xFFFFC48F),
    'B': Color(0xFF98D9FF),
    'C': Color(0xFF9EE9A3),
    'D': Color(0xFFFFB1D9),
    'E': Color(0xFFFFE07C),
  };
}

class _SlotFlightState {
  _SlotFlightState({
    required this.itemId,
    required this.targetIndex,
    required this.start,
    required this.target,
    required this.startScale,
    required this.targetScale,
  });

  final String itemId;
  final int targetIndex;
  final Vector3 start;
  final Vector3 target;
  final double startScale;
  final double targetScale;
  double progress = 0;
}
