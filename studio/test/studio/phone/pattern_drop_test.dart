import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart' show cells;
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/studio/controller.dart';
import '../../support/pump.dart';

/* The drop (owner, 21 Oct): a tap on another pattern's tile drops the new pattern's squares into place, row by row
   from the bottom, in about a second; nothing else drops, and with reduced motion nothing moves. */
Finder tile(LayoutKey k) => key('tile-${k.name}');

double opacityOf(WidgetTester tester, int i) =>
    tester.widget<FadeTransition>(find.descendant(of: key('cell-$i'), matching: find.byType(FadeTransition))).opacity.value;

double liftOf(WidgetTester tester, int i) =>
    tester.widget<Transform>(find.descendant(of: key('cell-$i'), matching: find.byType(Transform)).first)
        .transform.getTranslation().y;

/* Every square solid and in its place. */
void expectLanded(WidgetTester tester, {String reason = ''}) {
  for (var i = 0; i < cells; i++) {
    expect(opacityOf(tester, i), 1.0, reason: 'square $i $reason');
    expect(liftOf(tester, i), 0.0, reason: 'square $i $reason');
  }
}

bool dropping(WidgetTester tester) => [for (var i = 0; i < cells; i++) opacityOf(tester, i)].any((o) => o < 1);

/* Frames of 16 ms until the board holds `layout`'s squares (the solve has landed), at most 30. */
Future<void> untilArranged(WidgetTester tester, StudioController c, List<int>? before) async {
  for (var n = 0; n < 30 && (c.solving || identical(c.grid, before)); n++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('a tap on another pattern drops its squares, bottom row first, and in about a second every square is in place',
      (tester) async {
    final c = await pumpStudio(tester, size: phone);
    expectLanded(tester, reason: 'on opening the studio nothing drops');
    final rest = [for (var i = 0; i < cells; i++) tester.getRect(key('cell-$i'))];

    final before = c.grid;
    await tester.tap(tile(LayoutKey.gradient));
    await tester.pump();
    await untilArranged(tester, c, before);
    expect(c.layout, LayoutKey.gradient);
    await tester.pump(const Duration(milliseconds: 100));
    expect(dropping(tester), isTrue, reason: 'running');
    // 100 ms in: the bottom row's first square has landed or is falling; the top row has not begun.
    expect(opacityOf(tester, 30), 1.0, reason: 'bottom left, solid');
    expect(opacityOf(tester, 0), 0.0, reason: 'top left, not yet');
    expect(liftOf(tester, 0), lessThan(0), reason: 'top left, over the sheet');

    await tester.pump(const Duration(milliseconds: 950));
    expectLanded(tester, reason: 'after 1.05 s');
    for (var i = 0; i < cells; i++) {
      expect(tester.getRect(key('cell-$i')), rest[i], reason: 'square $i where it was');
    }
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing still moving');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second tap while one runs starts the new pattern at once, and it ends with every square in place',
      (tester) async {
    final c = await pumpStudio(tester, size: phone);
    var before = c.grid;
    await tester.tap(tile(LayoutKey.gradient));
    await tester.pump();
    await untilArranged(tester, c, before);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacityOf(tester, 30), 1.0);

    before = c.grid;
    await tester.tap(tile(LayoutKey.wave));
    await tester.pump();
    await untilArranged(tester, c, before);
    expect(c.layout, LayoutKey.wave);
    expect(opacityOf(tester, 34), 0.0, reason: 'the new drop starts from nothing: bottom right not yet down');
    await tester.pumpAndSettle();
    expectLanded(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same tile again and the stitches switch drop nothing', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    final drops = c.drops;
    var before = c.grid;
    await tester.tap(tile(c.layout));
    await tester.pump();
    await untilArranged(tester, c, before);
    await tester.pump(const Duration(milliseconds: 100));
    expectLanded(tester, reason: 'same pattern arranged again');
    await tester.tap(key('stitch-switch'));
    await tester.pump(const Duration(milliseconds: 100));
    expectLanded(tester, reason: 'stitches on');
    expect(c.drops, drops);
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion a tap on another pattern puts its squares straight in place', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await pumpStudio(tester, size: phone);
    final before = c.grid;
    await tester.tap(tile(LayoutKey.gradient));
    await tester.pump();
    await untilArranged(tester, c, before);
    expect(c.layout, LayoutKey.gradient);
    expectLanded(tester, reason: 'the frame the new board shows');
    await tester.pump(const Duration(milliseconds: 100));
    expectLanded(tester, reason: '100 ms on');
    expect(tester.takeException(), isNull);
  });
}
