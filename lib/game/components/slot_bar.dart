import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/cupertino.dart';

class SlotItem {
  SlotItem({required this.typeId, required this.sprite});

  final String typeId;
  final Sprite sprite;
}

class ResolvedMatchItem {
  ResolvedMatchItem({required this.index, required this.item});

  final int index;
  final SlotItem item;
}

class SlotBar extends PositionComponent {
  SlotBar({
    required this.capacity,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, anchor: Anchor.topCenter);

  final int capacity;
  final List<SlotItem> items = [];

  bool get isFull => items.length >= capacity;

  bool addItem(SlotItem item) {
    if (items.length >= capacity) {
      return false;
    }
    items.add(item);
    return true;
  }

  List<ResolvedMatchItem> resolveMatches() {
    final counts = <String, int>{};
    for (final item in items) {
      counts[item.typeId] = (counts[item.typeId] ?? 0) + 1;
    }

    for (final entry in counts.entries) {
      if (entry.value >= 3) {
        final matched = <ResolvedMatchItem>[];
        int removed = 0;
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          if (item.typeId == entry.key && removed < 3) {
            matched.add(ResolvedMatchItem(index: i, item: item));
            removed += 1;
          }
        }
        items.removeWhere((item) => matched.any((m) => identical(m.item, item)));
        return matched;
      }
    }

    return [];
  }

  Vector2 slotCenterForIndex(int index) {
    const outerPadding = 4.0;
    final cellWidth = size.x / capacity;
    final cellLeft = index * cellWidth + outerPadding;
    final cellTop = outerPadding;
    final cellRect = Rect.fromLTWH(
      cellLeft,
      cellTop,
      cellWidth - outerPadding * 2,
      size.y - outerPadding * 2,
    );
    final cellSize = cellRect.height < cellRect.width ? cellRect.height : cellRect.width;
    final itemRect = Rect.fromLTWH(
      cellRect.left + (cellRect.width - cellSize) / 2,
      cellRect.top + (cellRect.height - cellSize) / 2,
      cellSize,
      cellSize,
    );
    return Vector2(itemRect.center.dx, itemRect.center.dy);
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xFFB77D3B);
    final slotPaint = Paint()..color = const Color(0xFFEED7B1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(16)),
      bgPaint,
    );

    const outerPadding = 4.0;
    final cellWidth = size.x / capacity;
    for (int i = 0; i < capacity; i++) {
      final cellRect = Rect.fromLTWH(
        i * cellWidth + outerPadding,
        outerPadding,
        cellWidth - outerPadding * 2,
        size.y - outerPadding * 2,
      );
      final cellSize = cellRect.height < cellRect.width ? cellRect.height : cellRect.width;
      final squareRect = Rect.fromLTWH(
        cellRect.left + (cellRect.width - cellSize) / 2,
        cellRect.top + (cellRect.height - cellSize) / 2,
        cellSize,
        cellSize,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(squareRect, const Radius.circular(10)),
        slotPaint,
      );

      if (i < items.length) {
        final item = items[i];
        const innerPadding = 4.0;
        final itemRect = Rect.fromLTWH(
          squareRect.left + innerPadding,
          squareRect.top + innerPadding,
          squareRect.width - innerPadding * 2,
          squareRect.height - innerPadding * 2,
        );
        item.sprite.renderRect(canvas, itemRect);

        final textPainter = TextPainter(
          text: TextSpan(
            text: item.typeId,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final textOffset = Offset(
          itemRect.left + (itemRect.width - textPainter.width) / 2,
          itemRect.top + (itemRect.height - textPainter.height) / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }
}
