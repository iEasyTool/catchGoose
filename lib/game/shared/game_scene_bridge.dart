import 'dart:ui';

class SceneItemSnapshot {
  const SceneItemSnapshot({
    required this.id,
    required this.typeId,
    required this.x,
    required this.y,
    required this.size,
    required this.depth,
    required this.highlighted,
  });

  final String id;
  final String typeId;
  final double x;
  final double y;
  final double size;
  final int depth;
  final bool highlighted;
}

class SlotFlightSnapshot {
  const SlotFlightSnapshot({
    required this.itemId,
    required this.typeId,
    required this.targetIndex,
  });

  final String itemId;
  final String typeId;
  final int targetIndex;
}

class SceneSlotSnapshot {
  const SceneSlotSnapshot({
    required this.itemId,
    required this.typeId,
  });

  final String itemId;
  final String typeId;
}

class GameSceneBridge {
  Rect binRect = Rect.zero;
  final Map<String, SceneItemSnapshot> _items = {};
  List<SceneSlotSnapshot> slots = const [];
  List<Offset> slotCenters = const [];
  Map<String, Offset> projectedItemCenters = const {};
  Map<String, double> projectedItemDepths = const {};
  final List<SlotFlightSnapshot> _slotFlights = [];
  int renderedPileCount = 0;
  int renderedSlotCount = 0;

  Iterable<SceneItemSnapshot> get items => _items.values;

  void setBinRect(Rect rect) {
    binRect = rect;
  }

  void setItems(Iterable<SceneItemSnapshot> snapshots) {
    _items
      ..clear()
      ..addEntries(snapshots.map((item) => MapEntry(item.id, item)));
  }

  void removeItem(String id) {
    _items.remove(id);
  }

  void setSlots(List<SceneSlotSnapshot> values) {
    slots = List.unmodifiable(values);
  }

  void setSlotCenters(List<Offset> centers) {
    slotCenters = List.unmodifiable(centers);
  }

  void setProjectedItemCenters(Map<String, Offset> centers) {
    projectedItemCenters = Map.unmodifiable(centers);
  }

  void setProjectedItemDepths(Map<String, double> depths) {
    projectedItemDepths = Map.unmodifiable(depths);
  }

  void addSlotFlight({
    required String itemId,
    required String typeId,
    required int targetIndex,
  }) {
    _slotFlights.add(
      SlotFlightSnapshot(
        itemId: itemId,
        typeId: typeId,
        targetIndex: targetIndex,
      ),
    );
  }

  List<SlotFlightSnapshot> consumeSlotFlights() {
    if (_slotFlights.isEmpty) {
      return const [];
    }
    final result = List<SlotFlightSnapshot>.from(_slotFlights);
    _slotFlights.clear();
    return result;
  }

  void setRenderStats({
    required int pileCount,
    required int slotCount,
  }) {
    renderedPileCount = pileCount;
    renderedSlotCount = slotCount;
  }

  void clear() {
    _items.clear();
    binRect = Rect.zero;
    slots = const [];
    slotCenters = const [];
    projectedItemCenters = const {};
    projectedItemDepths = const {};
    _slotFlights.clear();
    renderedPileCount = 0;
    renderedSlotCount = 0;
  }
}
