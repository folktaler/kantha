import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart' show Mount, cells;
import 'package:kantha_studio/solver/layouts.dart' show LayoutKey;
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import '../../support/fonts.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';

/* The empty board and the shortfall banner on a phone (redesign handover, Canvas: "Empty cell" and "Shortfall banner";
   decisions 14 and 15). */
final banner = key('shortfall-banner');
const startHere = 'Start here: photograph your cloth to fill this box.';
final anyEmptyCell = find.bySemanticsLabel(RegExp(r'— tap to add cloth$'));
/* Add a piece, opened as a sheet on a phone (cloth_sheet_test.dart). */
final addSheet = find.descendant(of: find.byType(BottomSheet), matching: find.bySemanticsLabel('Add a piece'));

/* A solver that arranges nothing, full box or not: the box cannot be arranged. */
class NoGridSolver extends QuickSolver {
  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) async => const LayoutSolve(false, null, null);
}

void main() {
  testWidgets('on a phone an empty box of hers: the 35 squares dashed, each a button with its row and column; '
      'no banner, the tooltip instead', (tester) async {
    final c = await pumpPhone(tester);
    await boxWith(tester, c, 0);
    expect(c.grid, isNull);
    expectDashed(tester);
    expect(banner, findsNothing);
    await tester.tap(key('tab-cloth'));
    await tester.pumpAndSettle();
    expect(find.text(startHere), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone a box of 10 pieces: the banner says 25 more, Add pieces at its right, 16 in from each side and '
      '16 above the dock; the squares dashed', (tester) async {
    // Geist as the browser draws it: the board's fit measures the pattern's description over it.
    await tester.runAsync(loadFonts);
    final c = await pumpPhone(tester);
    await boxWith(tester, c, 10);
    expect(c.grid, isNull);
    expectDashed(tester);
    expect(banner, findsOneWidget);
    const words = 'Add 25 more pieces to complete the grid.';
    expect(find.descendant(of: banner, matching: find.text(words)), findsOneWidget);
    expect(find.descendant(of: banner, matching: find.text('Add pieces')), findsOneWidget);
    expect(find.bySemanticsLabel(words), findsOneWidget, reason: 'one button, named by its sentence');

    final b = tester.getRect(banner), dock = tester.getRect(key('dock-panel')), canvas = tester.getRect(key('phone-canvas'));
    expect((b.left, phone.width - b.right), (16.0, 16.0));
    expect(dock.top - b.bottom, 16.0);
    expect(b.top, greaterThan(canvas.top));
    expect(b.height, greaterThanOrEqualTo(48));
    final sentence = tester.widget<Text>(find.text(words)), add = tester.widget<Text>(find.text('Add pieces'));
    expect((sentence.style!.fontSize, sentence.style!.fontWeight, sentence.style!.color), (14.83, FontWeight.w400, PhonePalette.text));
    expect((add.style!.fontSize, add.style!.color, add.softWrap), (14.83, PhonePalette.blue, false));
    expect(tester.getRect(find.text('Add pieces')).right, closeTo(b.right - 12, 0.5));
    expect(tester.getRect(find.text(words)).left, closeTo(b.left + 3 + 14, 0.5), reason: 'the 3 px edge, then 14');

    final box = tester.widget<Container>(find.descendant(of: banner, matching: find.byKey(const ValueKey('shortfall-box'))));
    final deco = box.decoration! as BoxDecoration;
    expect(deco.color, PhonePalette.redTint);
    expect((deco.border! as Border).left, const BorderSide(color: PhonePalette.red, width: 3));
    expect(deco.boxShadow, const [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 2), blurRadius: 6)]);
    expect(deco.borderRadius, isNull, reason: 'square corners');
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone a box of 34 pieces: Add 1 more piece', (tester) async {
    // Geist as the browser draws it: the board's fit measures the pattern's description over it.
    await tester.runAsync(loadFonts);
    final c = await pumpPhone(tester);
    await boxWith(tester, c, 34);
    expect(find.descendant(of: banner, matching: find.text('Add 1 more piece to complete the grid.')), findsOneWidget);
    expectDashed(tester);
  });

  testWidgets('on a phone a square or the banner opens Add a piece for the box', (tester) async {
    final c = await pumpPhone(tester);
    final box = await boxWith(tester, c, 10);
    await tester.tap(find.bySemanticsLabel(cellLabel(3, 2)));
    await tester.pumpAndSettle();
    expect(addSheet, findsOneWidget, reason: 'Add a piece, as a sheet');
    await tapShown(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Done')));
    await tester.pumpAndSettle();
    expect(addSheet, findsNothing);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(addSheet, findsOneWidget);
    expect(c.box, box, reason: 'the box on the board, which the sheet adds to');
  });

  testWidgets('on a phone with no box at all: the squares dashed, no banner, and a tap adds to a new box', (tester) async {
    final c = await pumpPhone(tester, seeded: false);
    final sample = c.sampleBox;
    if (sample != null) {
      await tester.runAsync(() async => c.shelf.deleteBox(sample, cloth: await c.shelf.clothIn(sample)));
      await letWork(tester, done: () => c.sampleBox == null);
    }
    expect(c.box, isNull);
    expect(c.ownBoxes, isEmpty);
    expectDashed(tester);
    expect(banner, findsNothing);
    await tester.tap(find.bySemanticsLabel(cellLabel(1, 1)));
    await tester.pumpAndSettle();
    expect(addSheet, findsOneWidget, reason: 'Add a piece, as a sheet');
  });

  testWidgets('on a phone a full box: no square is a button, no banner', (tester) async {
    final c = await pumpPhone(tester);
    expect(c.grid, isNotNull);
    expect(anyEmptyCell, findsNothing);
    expect(banner, findsNothing);
  });

  testWidgets('on a phone a full box the solver cannot arrange: the empty sheet under its note, no square a button, no banner',
      (tester) async {
    final c = await pumpPhone(tester, solver: NoGridSolver());
    expect(c.piecesIn(c.box!), greaterThanOrEqualTo(cells));
    expect((c.grid, c.solving, c.note), (null, false, c.words.canvasCantSolve));
    expect(find.byKey(const ValueKey('empty-cell-0')), findsNothing);
    expect(anyEmptyCell, findsNothing);
    expect(banner, findsNothing);
  });

  testWidgets('on a phone, turning from a full box to one of 10 pieces: the dashed squares and the banner, not the full '
      'box\'s cloth', (tester) async {
    // Geist as the browser draws it: the board's fit measures the pattern's description over it.
    await tester.runAsync(loadFonts);
    final c = await pumpPhone(tester);
    expect(c.grid, isNotNull);
    final box = (await tester.runAsync(() async {
      final b = await c.shelf.makeBox();
      await c.shelf.addCloth(box: b, photo: fixtureJpeg, measured: measuredFor(l: 40), fabric: '', pieces: 5);
      await c.shelf.addCloth(box: b, photo: fixtureJpeg, measured: measuredFor(l: 60), fabric: '', pieces: 5);
      return b;
    }))!;
    await letWork(tester, done: () => c.piecesIn(box) == 10);
    expect(c.grid, isNotNull, reason: 'still on the full box');
    c.openBox(box);
    await letWork(tester, done: () => !c.solving);
    expect(c.grid, isNull);
    expectDashed(tester);
    expect(find.descendant(of: banner, matching: find.text('Add 25 more pieces to complete the grid.')), findsOneWidget);
  });

  testWidgets('on a phone a box of 10 pieces toasts nothing: the banner already says what to do', (tester) async {
    final c = await pumpPhone(tester);
    final short = await boxWith(tester, c, 10);
    expect(banner, findsOneWidget);
    expect(key('phone-toast'), findsNothing);
    // Turned to from the full box: the solver arranges nothing, and says so.
    c.openBox(c.ownBoxes.first);
    await letWork(tester, done: () => !c.solving);
    await tester.pump(const Duration(milliseconds: 2800));
    c.openBox(short);
    await letWork(tester, done: () => !c.solving);
    expect(c.note, c.words.canvasCantSolve, reason: 'the controller keeps its note, for the desk');
    expect(banner, findsOneWidget);
    expect(key('phone-toast'), findsNothing);
  });

  testWidgets('on a phone a piece added to a box of 10 through the sheet toasts nothing; the sheet says what it added',
      (tester) async {
    final c = await pumpStudio(tester, size: phone, photos: FixturePhotos(), solver: StockSolver());
    final box = await boxWith(tester, c, 10);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(addSheet, findsOneWidget);
    final inSheet = find.descendant(of: find.byType(BottomSheet), matching: find.text('Photo of the piece'));
    await tester.tap(inSheet);
    await letWork(tester, turns: 10);
    final add = find.descendant(of: find.byType(BottomSheet), matching: find.textContaining(RegExp(r'^Add (\d+ )?to box$')));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await letWork(tester, done: () => c.piecesIn(box) > 10 && !c.solving);
    expect(c.piecesIn(box), lessThan(cells));
    expect(find.descendant(of: find.byType(BottomSheet), matching: key('cloth-added')), findsOneWidget);
    expect(key('phone-toast'), findsNothing);
  });

  testWidgets('on a phone a box of 10 pieces: the last row of squares stands clear of the banner', (tester) async {
    final c = await pumpPhone(tester);
    await boxWith(tester, c, 10);
    final over = tester.getRect(banner).top;    final bottom = [for (var i = 0; i < cells; i++) tester.getRect(key('empty-cell-$i')).bottom].reduce((a, b) => a > b ? a : b);
    expect(bottom, lessThanOrEqualTo(over), reason: 'the last row ends at $bottom, the banner starts at $over');
    expect(c.percent, 100);
  });

  // One screen at every width (2026-10-11 one-screen spec, decision 1).
  testWidgets('at a desk a newcomer has the same empty board: the squares dashed, a tap adds to a box',
      (tester) async {
    final c = await pumpStudio(tester, size: desk, seeded: false, solver: StockSolver());
    expect(c.grid, isNull);
    expectDashed(tester);
    expect(banner, findsNothing);
    await tester.tap(find.bySemanticsLabel(cellLabel(1, 1)));
    await tester.pumpAndSettle();
    expect(addSheet, findsOneWidget, reason: 'Add a piece, as a sheet');
  });
}
