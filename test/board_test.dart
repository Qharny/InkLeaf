import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/canvas/domain/board.dart';
import 'package:my_note/features/canvas/presentation/board_painters.dart';

BoardCard _card(String id, double x, double y) =>
    BoardCard(id: id, kind: BoardCardKind.sticky, x: x, y: y);

void main() {
  final t = DateTime(2026, 1, 1);
  final board = Board(
    id: 'b',
    createdAt: t,
    updatedAt: t,
  ).addCard(_card('a', 0, 0)).addCard(_card('c', 400, 0));

  test('links skip self, duplicates and missing cards', () {
    final linked = board.addLink('a', 'c');
    expect(linked.links, hasLength(1));
    expect(linked.addLink('c', 'a').links, hasLength(1));
    expect(linked.addLink('a', 'a').links, hasLength(1));
    expect(linked.addLink('a', 'nope').links, hasLength(1));
  });

  test('removing a card removes its arrows', () {
    final linked = board.addLink('a', 'c').removeCard('c');
    expect(linked.cards.map((c) => c.id), ['a']);
    expect(linked.links, isEmpty);
  });

  test('bringToFront moves a card to the end of paint order', () {
    expect(board.bringToFront('a').cards.map((c) => c.id), ['c', 'a']);
  });

  test('content bounds cover cards and strokes', () {
    final drawn = board.addStroke(
      const BoardStroke(
        id: 's',
        points: [Offset(100, 500), Offset(120, 520)],
        color: 0xFF000000,
        width: 4,
      ),
    );
    expect(drawn.contentBounds, const Rect.fromLTRB(0, 0, 580, 522));
    expect(Board(id: 'e', createdAt: t, updatedAt: t).contentBounds, isNull);
  });

  test('JSON round trip keeps everything', () {
    final full = board
        .addLink('a', 'c')
        .addStroke(
          const BoardStroke(
            id: 's',
            points: [Offset(1.26, 2), Offset(3, 4)],
            color: 0xFF112233,
            width: 3,
          ),
        )
        .copyWith(title: 'Plans');
    final back = Board.fromJson(
      (jsonDecode(jsonEncode(full.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.title, 'Plans');
    expect(back.cards.map((c) => c.rect), full.cards.map((c) => c.rect));
    expect(back.links.single.from, 'a');
    expect(back.strokes.single.points, const [Offset(1.3, 2), Offset(3, 4)]);
    expect(back.strokes.single.color, 0xFF112233);
  });

  test('arrows run edge to edge; strokes hit-test along their line', () {
    final linked = board.addLink('a', 'c');
    final (from, to) = linkSegment(linked, linked.links.single)!;
    expect(from.dx, closeTo(186, 0.01)); // right edge of a, plus margin
    expect(to.dx, closeTo(394, 0.01)); // left edge of c, minus margin

    const stroke = BoardStroke(
      id: 's',
      points: [Offset(0, 0), Offset(100, 0)],
      color: 0,
      width: 4,
    );
    expect(strokeHitsPoint(stroke, const Offset(50, 10), 10), isTrue);
    expect(strokeHitsPoint(stroke, const Offset(50, 30), 10), isFalse);
  });
}
