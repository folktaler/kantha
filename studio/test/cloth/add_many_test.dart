/* Add a piece where there is a finder (the web): many pieces in one photo, the check, her cloths, and every close
   adding what is waiting. The finder here is a stand-in that answers at once; the real one runs in a web worker
   (web/finder_worker.dart) and is checked in a browser. */
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/cloth/add_cloth.dart';
import 'package:kantha_studio/cloth/many_pieces.dart' show CheckPieces, smallestSide;
import 'package:kantha_studio/cloth/piece_finder.dart';
import 'package:kantha_studio/cloth/prepare.dart' show PickedPhoto, readPhoto;
import 'package:kantha_studio/finder/group_squares.dart' show PrintLook;
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/studio/phone/phone_sheet.dart' show PhoneButton;
import 'package:kantha_studio/data/database.dart' show ClothRow;
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/measure/measure.dart' show Measured;
import 'package:kantha_studio/studio/controller.dart';
import '../support/db.dart';
import '../support/pump.dart';

/* FixturePhotos' picture is 800 × 800. Three pieces in a row, the first two one cloth; a fourth far off. */
Float32List sq(double x, double y, [double side = 100]) =>
    Float32List.fromList([x, y, x + side, y, x + side, y + side, x, y + side]);

class FakeFinder implements PieceFinder {
  FakeFinder(this.answer, {this.snapped, this.fails = false});
  FinderAnswer answer;
  Float32List? snapped;
  /* While set, find or snap waits for it. */
  Completer<FinderAnswer>? findHeld;
  Completer<void>? snapHeld;
  bool fails;
  final snaps = <Offset>[];
  final cuts = <int>[];
  var forgot = 0, finds = 0;

  @override
  Future<FinderAnswer> find(PickedPhoto photo) async {
    finds++;
    if (fails) throw StateError('the worker did not load');
    return findHeld?.future ?? answer;
  }

  @override
  Future<Float32List?> snap(Offset at) async {
    snaps.add(at);
    await snapHeld?.future;
    return snapped;
  }

  /* Each piece a plain 40 px square, its colour from where it is, so cloths differ. */
  @override
  Future<List<Uint8List>> cut(List<Float32List> squares) async {
    cuts.add(squares.length);
    return [
      for (final q in squares)
        Uint8List.fromList([for (var i = 0; i < 40 * 40; i++) ...[(q[0] ~/ 4) % 256, (q[1] ~/ 4) % 256, 90, 255]]),
    ];
  }

  @override
  void forget() => forgot++;
}

/* A square of `side` with its top left at x, y, turned by `turn` radians about that corner. */
Float32List _turned(double x, double y, double side, double turn) {
  final c = math.cos(turn) * side, s = math.sin(turn) * side;
  return Float32List.fromList([x, y, x + c, y + s, x + c - s, y + s + c, x - s, y + c]);
}

/* Made new each time: a corner she moves moves the answer's own numbers. */
FinderAnswer get three =>
    FinderAnswer(squares: [sq(100, 100), sq(250, 100), sq(400, 100), sq(600, 600)], groups: [0, 0, 1, 2], tiny: 0);

/* A cloth printed in squares, as the finder sees it: a cells × cells grid of `side` px squares every `step` px from
   `from`, turned by `turn` about the photo's centre, less the cells in `skip`; its groups the first `groups` numbers
   in turn. On the 800 × 800 picture the default grid reaches every edge. */
FinderAnswer printed({double side = 70, double step = 115, double from = 5, int cells = 7, double turn = 0,
    Set<(int, int)> skip = const {}, int groups = 1}) {
  final squares = <Float32List>[];
  final c = math.cos(turn), s = math.sin(turn);
  for (var i = 0; i < cells; i++) {
    for (var j = 0; j < cells; j++) {
      if (skip.contains((i, j))) continue;
      final q = sq(from + i * step, from + j * step, side);
      squares.add(Float32List.fromList([
        for (var k = 0; k < 8; k += 2) ...[
          400 + (q[k] - 400) * c - (q[k + 1] - 400) * s,
          400 + (q[k] - 400) * s + (q[k + 1] - 400) * c,
        ],
      ]));
    }
  }
  return FinderAnswer(squares: squares, groups: [for (var i = 0; i < squares.length; i++) i % groups], tiny: 0);
}

class FailingAdd extends Shelf {
  FailingAdd(super.db, {this.after = 0});
  /* Adds that go through before the rest fail. */
  int after;
  bool fail = true;
  @override
  Future<ClothRow> addCloth({required int box, required Uint8List photo, required Measured measured,
      required String fabric, required int pieces, String? name}) {
    if (fail && after-- <= 0) return Future.error(const ShelfError('boxFull', {'limit': 200}));
    return super.addCloth(box: box, photo: photo, measured: measured, fabric: fabric, pieces: pieces, name: name);
  }

  @override
  Future<List<ClothRow>> addCloths({required int box,
      required List<({Uint8List photo, Measured measured, int pieces})> cloth}) {
    if (fail && after-- <= 0) return Future.error(const ShelfError('boxFull', {'limit': 200}));
    return super.addCloths(box: box, cloth: cloth);
  }
}

final closes = <String, Future<void> Function(WidgetTester)>{
  'Done': (tester) async {
    final done = inSheet(find.text('Done'));
    await tester.ensureVisible(done);
    await tester.pump();
    await tester.tap(done);
  },
  'the ×': (tester) => tester.tap(inSheet(find.bySemanticsLabel('Close')).last),
  'a tap on the scrim': (tester) => tester.tapAt(const Offset(5, 5)),
  'back': (tester) => tester.binding.handlePopRoute(),
  'Escape': (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape),
};

Future<StudioController> openAdd(WidgetTester tester, {Shelf? on, Size size = desk}) async {
  final c = await pumpStudio(tester, size: size, photos: FixturePhotos(), on: on);
  await tester.runAsync(() => c.shelf.makeBox());
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  c.openBox(2);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tab-cloth')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-pieces')));
  await tester.pumpAndSettle();
  return c;
}

/* The photo picked and looked at. */
Future<void> pick(WidgetTester tester) async {
  await tester.tap(find.text('Photo of the pieces'));
  await letWork(tester, done: () => find.text('Are these your pieces?').evaluate().isNotEmpty
      || inSheet(find.text('Add to box')).evaluate().isNotEmpty
      || find.textContaining('too small').evaluate().isNotEmpty);
}

/* Where a point of the 800 × 800 picture is drawn on the screen. */
Offset onPhoto(WidgetTester tester, Offset at) {
  final shown = tester.getRect(find.descendant(of: find.byKey(const ValueKey('pieces-photo')), matching: find.byType(Image)));
  return shown.topLeft + at * (shown.width / 800);
}

Future<void> next(WidgetTester tester) async {
  await tapShown(tester, inSheet(find.text('Next')));
  await letWork(tester, done: () => find.text('Your cloths').evaluate().isNotEmpty);
}

/* The counts of the cloths in Box 2. */
List<int> inBox2(StudioController c) => [for (final x in c.cloth) if (x.box == 2) x.stock];

void main() {
  late FakeFinder finder;
  setUp(() {
    finder = FakeFinder(three);
    pieceFinderWith = () => finder;
  });
  tearDown(() => pieceFinderWith = () => null);

  testWidgets('the sheet asks for a photo of the pieces, and Find the pieces waits for one', (tester) async {
    await openAdd(tester);
    expect(find.text('Add pieces'), findsWidgets);
    expect(inSheet(find.text('Photo of the pieces')), findsOneWidget);
    expect(inSheet(find.text('One piece or many: lay them out and take one photo.')), findsOneWidget);
    expect(inSheet(find.text('How many of this piece')), findsNothing, reason: 'the count is asked per cloth');
    await tapAndSettle(tester, inSheet(find.text('How to get it right')));
    expect(inSheet(find.text('Lay them flat, apart or sewn together, and fill the photo with them.')), findsOneWidget);
    await tester.tap(inSheet(find.text('Find the pieces')));
    await tester.pumpAndSettle();
    expect(find.text('Are these your pieces?'), findsNothing);
  });

  testWidgets('pieces found: she removes one, brings it back, adds one, then her cloths go into the box with their '
      'counts, and the sheet stays open for the next photo, saying what went in', (tester) async {
    final c = await openAdd(tester);
    await pick(tester);
    expect(find.text('Are these your pieces?'), findsOneWidget, reason: 'the title follows the step');
    expect(inSheet(find.text('4 pieces')), findsOneWidget);
    expect(inSheet(find.text('Tap a box to remove it. Tap a piece we missed to add it. Zoom in to move a box\'s corners.')),
        findsOneWidget);

    await tester.tapAt(onPhoto(tester, const Offset(650, 650)));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('3 pieces, 1 removed')), findsOneWidget);
    await tester.tapAt(onPhoto(tester, const Offset(650, 650)));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('4 pieces')), findsOneWidget, reason: 'a tap again brings it back');
    await tester.tapAt(onPhoto(tester, const Offset(650, 650)));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, inSheet(find.text('Undo')));
    expect(inSheet(find.text('4 pieces')), findsOneWidget, reason: 'Undo brings it back too');

    // Nothing snaps where she taps: a square the size of the nearest piece is added there.
    await tester.tapAt(onPhoto(tester, const Offset(150, 400)));
    await letWork(tester, turns: 3);
    expect(finder.snaps.single.dx, closeTo(150, 2));
    expect(inSheet(find.text('5 pieces')), findsOneWidget);

    await next(tester);
    expect(inSheet(find.text('Pieces of the same cloth are counted together. Change a count if it is wrong.')), findsOneWidget);
    expect(inSheet(find.text('Found 2 times')), findsOneWidget);
    expect(inSheet(find.text('Found once')), findsNWidgets(3));
    // The most pieces first; a stack, or any piece, counts 1.
    final first = find.byKey(const ValueKey('cloth-row-0'));
    expect(find.descendant(of: first, matching: find.text('2 pieces')), findsOneWidget);
    await tapShown(tester, find.descendant(of: first, matching: find.bySemanticsLabel('One more piece')));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('Add 6 pieces to box')), findsOneWidget);

    await tapShown(tester, inSheet(find.text('Add 6 pieces to box')));
    await letWork(tester, done: () => inBox2(c).length == 4);
    expect([...inBox2(c)]..sort(), [1, 1, 1, 3]);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget, reason: 'the sheet stays open, as for one piece');
    expect(inSheet(find.text('4 cloths, 6 pieces, added to Box 2. Photograph the next one.')), findsOneWidget);
    expect(inSheet(find.text('Photo of the pieces')), findsOneWidget, reason: 'ready for the next photo');
    expect(find.text('Add pieces'), findsWidgets);
    expect(find.text('4 cloths, 6 pieces, added to Box 2.'), findsNothing, reason: 'no toast while the sheet is open');

    // The next photo goes in too, and Done with nothing waiting closes the sheet.
    finder.answer = three;
    await pick(tester);
    await next(tester);
    await tapShown(tester, inSheet(find.text('Add 4 pieces to box')));
    await letWork(tester, done: () => inBox2(c).length == 7);
    await tester.pumpAndSettle();
    expect(inSheet(find.text('3 cloths, 4 pieces, added to Box 2. Photograph the next one.')), findsOneWidget);
    await tapShown(tester, inSheet(find.text('Done')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(inBox2(c), hasLength(7));
  });

  testWidgets('on a phone both steps fit the column: the tools wrap under the count, a counter under its cloth',
      (tester) async {
    await openAdd(tester, size: phone);
    await pick(tester);
    final count = tester.getRect(inSheet(find.text('4 pieces'))), undo = tester.getRect(inSheet(find.text('Undo')));
    expect(undo.top, greaterThan(count.bottom), reason: 'under the count');
    await next(tester);
    final row = find.byKey(const ValueKey('cloth-row-0'));
    final found = tester.getRect(find.descendant(of: row, matching: find.text('Found 2 times')));
    final more = tester.getRect(find.descendant(of: row, matching: find.bySemanticsLabel('One more piece')));
    expect(more.top, greaterThan(found.bottom));
    expect(more.right, lessThanOrEqualTo(phone.width));
  });

  testWidgets('zoomed in, a box shows its corners and one moves where she drags it, not the photo', (tester) async {
    await openAdd(tester);
    await pick(tester);
    await tapAndSettle(tester, inSheet(find.bySemanticsLabel('Zoom in')));
    expect(inSheet(find.text('150 %')), findsOneWidget);
    final from = onPhoto(tester, const Offset(200, 200)), to = onPhoto(tester, const Offset(240, 260));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 5; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 5)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(onPhoto(tester, const Offset(200, 200)), from, reason: 'the photo did not move');
    // Inside the box as it is now, outside it as it was: the tap finds the moved box.
    await tester.tapAt(onPhoto(tester, const Offset(225, 225)));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('3 pieces, 1 removed')), findsOneWidget);
    await tapAndSettle(tester, inSheet(find.text('Undo')));
    await tapAndSettle(tester, inSheet(find.text('Undo')));
    await tester.tapAt(onPhoto(tester, const Offset(225, 225)));
    await letWork(tester, turns: 3);
    expect(inSheet(find.text('5 pieces')), findsOneWidget, reason: 'the corner is back: that tap adds a piece');
  });

  testWidgets('a tap that snaps adds the piece the finder saw there', (tester) async {
    finder.snapped = sq(120, 380, 90);
    await openAdd(tester);
    await pick(tester);
    await tester.tapAt(onPhoto(tester, const Offset(150, 400)));
    await letWork(tester, turns: 3);
    expect(inSheet(find.text('5 pieces')), findsOneWidget);
    // The snapped square is the new piece: a tap inside it, not inside the default one, removes it.
    await tester.tapAt(onPhoto(tester, const Offset(200, 460)));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('4 pieces, 1 removed')), findsOneWidget);
  });

  testWidgets('back to the pieces keeps a count she set while that cloth stays as it was', (tester) async {
    await openAdd(tester);
    await pick(tester);
    await next(tester);
    final first = find.byKey(const ValueKey('cloth-row-0'));
    await tapShown(tester, find.descendant(of: first, matching: find.bySemanticsLabel('One more piece')));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, inSheet(find.text('Back to the pieces')));
    expect(find.text('Are these your pieces?'), findsOneWidget);
    await next(tester);
    expect(find.descendant(of: first, matching: find.text('3 pieces')), findsOneWidget);
    expect(finder.cuts, [3], reason: 'nothing changed, nothing is cut again');
  });

  // Every close adds what is waiting (owner, 22 October 2026): on the check, the pieces as matched.
  for (final MapEntry(key: how, value: close) in closes.entries) {
    testWidgets('$how on Are these your pieces? adds the pieces left, as matched, then closes', (tester) async {
      final c = await openAdd(tester);
      await pick(tester);
      await tester.tapAt(onPhoto(tester, const Offset(650, 650)));
      await tester.pumpAndSettle();
      await close(tester);
      await letWork(tester, done: () => inBox2(c).length == 2 && sheet.evaluate().isEmpty);
      expect(sheet, findsNothing);
      expect([...inBox2(c)]..sort(), [1, 2], reason: 'the removed piece is not added');
    });

    testWidgets('$how on Your cloths adds them at the counts shown, then closes', (tester) async {
      final c = await openAdd(tester);
      await pick(tester);
      await next(tester);
      final last = find.byKey(const ValueKey('cloth-row-2'));
      await tapShown(tester, find.descendant(of: last, matching: find.bySemanticsLabel('One more piece')));
      await tester.pumpAndSettle();
      await close(tester);
      await letWork(tester, done: () => inBox2(c).length == 3 && sheet.evaluate().isEmpty);
      expect(sheet, findsNothing);
      expect([...inBox2(c)]..sort(), [1, 2, 2]);
    });

    testWidgets('$how when the pieces are too small adds nothing and closes', (tester) async {
      finder.answer = FinderAnswer(squares: [sq(10, 10, 20)], groups: [0], tiny: 137);
      final c = await openAdd(tester);
      await pick(tester);
      await close(tester);
      await letWork(tester, turns: 5);
      expect(sheet, findsNothing);
      expect(inBox2(c), isEmpty);
    });
  }

  testWidgets('pieces too small to find: she is asked for a closer photo', (tester) async {
    finder.answer = FinderAnswer(squares: [sq(10, 10, 20)], groups: [0], tiny: tooSmallTiny);
    await openAdd(tester);
    await pick(tester);
    expect(inSheet(find.text('The pieces are too small in this photo to find. Come closer, so the pieces fill the photo, '
        'and take it again.')), findsOneWidget);
    await tapAndSettle(tester, inSheet(find.text('Choose a different picture')));
    expect(inSheet(find.text('Photo of the pieces')), findsOneWidget);
  });

  testWidgets('a few tiny outlines and one piece: the crop, its square on that piece', (tester) async {
    finder.answer = FinderAnswer(squares: [sq(100, 100, 200)], groups: [0], tiny: tooSmallTiny - 1);
    final c = await openAdd(tester);
    await pick(tester);
    expect(inSheet(find.text('fill the square with the piece')), findsOneWidget);
    expect(find.text('Add pieces'), findsWidgets);
    await tapShown(tester, inSheet(find.text('Add to box')));
    await letWork(tester, done: () => inBox2(c).isNotEmpty);
    expect(inBox2(c).single, 1);
    expect(inSheet(find.byKey(const ValueKey('cloth-added'))), findsOneWidget, reason: 'one piece goes in as today');
  });

  testWidgets('one printed cloth, its squares a grid to the edges of the photo: the crop, not the pieces', (tester) async {
    finder.answer = printed();
    final c = await openAdd(tester);
    await pick(tester);
    expect(inSheet(find.text('fill the square with the piece')), findsOneWidget);
    expect(find.byKey(const ValueKey('pieces-photo')), findsNothing);
    await tapShown(tester, inSheet(find.text('Add to box')));
    await letWork(tester, done: () => inBox2(c).isNotEmpty);
    expect(inBox2(c).single, 1, reason: 'one cloth, as today');
  });

  group('a print or pieces', () {
    const photo = Size(800, 800);
    test('a grid of one cloth to every edge, at most 1 cell in 10 empty, is a print', () {
      expect(routeOf(printed(), photo), FoundRoute.crop);
      expect(routeOf(printed(skip: {(3, 3)}), photo), FoundRoute.crop, reason: '1 of 49 empty');
      final turned = printed(turn: 0.3);
      expect(isPrint(turned, photo), isTrue, reason: 'the photo taken at a slant');
    });
    test('pieces stay pieces', () {
      expect(routeOf(printed(groups: 2), photo), FoundRoute.check, reason: 'two cloths');
      expect(routeOf(printed(side: 60, step: 80, from: 200, cells: 3), photo), FoundRoute.check,
          reason: 'one cloth in a neat grid on a table, short of the edges');
      expect(routeOf(printed(skip: {for (var i = 0; i < 6; i++) (i, 0)}), photo), FoundRoute.check, reason: 'a row gone');
      expect(routeOf(FinderAnswer(squares: [sq(20, 20), sq(330, 60), sq(680, 200), sq(100, 690), sq(500, 680)],
          groups: [0, 0, 0, 0, 0], tiny: 0), photo), FoundRoute.check, reason: 'one cloth lying apart');
      expect(routeOf(FinderAnswer(squares: [sq(0, 0, 400), sq(400, 0, 400), sq(0, 400, 400)], groups: [0, 0, 0], tiny: 0),
          photo), FoundRoute.check, reason: 'fewer than 4');
    });
  });
  for (final fails in [false, true]) {
    testWidgets(fails ? 'a finder that did not load: the crop, as before, and the failure reported'
        : 'no piece found: the crop, as before', (tester) async {
      finder
        ..answer = const FinderAnswer(squares: [], groups: [], tiny: 0)
        ..fails = fails;
      await openAdd(tester);
      await pick(tester);
      if (fails) expect(tester.takeException(), isA<StateError>());
      expect(inSheet(find.text('fill the square with the piece')), findsOneWidget);
    });
  }

  testWidgets('an add that fails keeps the sheet open with the error and nothing in; again adds them all', (tester) async {
    final shelf = FailingAdd(memoryDb());
    final c = await openAdd(tester, on: shelf);
    await pick(tester);
    await next(tester);
    await tapShown(tester, inSheet(find.text('Add 4 pieces to box')));
    const full = 'This box holds 200 cloths already. Take some out before adding more.';
    await letWork(tester, done: () => find.text(full).evaluate().isNotEmpty);
    expect(sheet, findsOneWidget);
    expect(inBox2(c), isEmpty, reason: 'all go in, or none');
    expect(inSheet(find.text('Add 4 pieces to box')), findsOneWidget, reason: 'all still wait');

    shelf.fail = false;
    await tapShown(tester, inSheet(find.text('Add 4 pieces to box')));
    await letWork(tester, done: () => inBox2(c).length == 3);
    expect([...inBox2(c)]..sort(), [1, 1, 2]);
    await tester.pumpAndSettle();
    expect(inSheet(find.text('3 cloths, 4 pieces, added to Box 2. Photograph the next one.')), findsOneWidget);
  });

  test('many cloths go in as addCloth stores each, in one write', () async {
    final measured = Measured(lab: (l: 50, a: 10, b: -5), name: 'brown', spread: 3, width: 40, height: 40);
    final photo = Uint8List.fromList([1, 2, 3]);
    final one = Shelf(memoryDb()), many = Shelf(memoryDb());
    final b1 = (await one.makeNumberedBox()).id, b2 = (await many.makeNumberedBox()).id;
    final a = [
      for (final n in [2, 1, 3]) await one.addCloth(box: b1, photo: photo, measured: measured, fabric: '', pieces: n),
    ];
    final b = await many.addCloths(box: b2, cloth: [for (final n in [2, 1, 3]) (photo: photo, measured: measured, pieces: n)]);
    String row(ClothRow r) => [r.id, r.box, r.name, r.fabric, r.pieces, r.l, r.a, r.b, r.spread, r.colour, r.photo,
        r.photoNumber].join('|');
    expect([for (final r in b) row(r)], [for (final r in a) row(r)]);
  });

  // The review of 31 October 2026.
  /* Until the finder is looking (the photo read): its spinner never lets the sheet settle. */
  Future<void> untilFinding(WidgetTester tester) async {
    for (var i = 0; i < 60 && finder.finds == 0; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(find.text('Finding the pieces…'), findsOneWidget);
  }

  group('while the finder looks', () {
    for (final MapEntry(key: how, value: close) in closes.entries) {
      if (how == 'Done') continue;
      testWidgets('$how closes the sheet at once, nothing added', (tester) async {
        finder.findHeld = Completer();
        final c = await openAdd(tester);
        await tester.tap(find.text('Photo of the pieces'));
        await untilFinding(tester);
        await close(tester);
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        finder.findHeld!.complete(three);
        await tester.pumpAndSettle();
        expect(inBox2(c), isEmpty);
      });
    }

    testWidgets('a finder that never answers: after finderWait, the crop, and Done adds the photo as one piece',
        (tester) async {
      finder.findHeld = Completer();
      final c = await openAdd(tester);
      await tester.tap(find.text('Photo of the pieces'));
      await untilFinding(tester);
      await tester.pump(finderWait);
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(tester.takeException(), isA<TimeoutException>(), reason: 'reported');
      expect(inSheet(find.text('fill the square with the piece')), findsOneWidget);
      await tapShown(tester, inSheet(find.text('Add to box')));
      await letWork(tester, done: () => inBox2(c).isNotEmpty);
      expect(inBox2(c).single, 1);
    });
  });

  testWidgets('one large piece among many tiny outlines (a gingham): the crop, not a closer photo', (tester) async {
    finder.answer = FinderAnswer(squares: [sq(250, 250, 300)], groups: [0], tiny: 1000);
    await openAdd(tester);
    await pick(tester);
    expect(inSheet(find.text('fill the square with the piece')), findsOneWidget);
    expect(find.textContaining('too small'), findsNothing);
  });

  group('one printed cloth on a table, by how its squares sit', () {
    const photo = Size(800, 800);
    // As measured on the test photos, 31 October 2026 (the commit says which).
    FinderAnswer looking(PrintLook look, {int groups = 3}) =>
        FinderAnswer(squares: printed(from: 200, step: 60, side: 30, cells: 5).squares,
            groups: [for (var i = 0; i < 25; i++) i % groups], tiny: 0, look: look);
    test('a check on a table, its squares in several groups and short of the edges: the crop', () {
      expect(routeOf(looking((boxSpread: 1.7, ringSpread: 1.6, ringVsBox: 73.5, ringVsOutside: 39.5)), photo),
          FoundRoute.crop);
    });
    test('a tidy grid of pieces of one cloth on a table: the pieces', () {
      expect(routeOf(looking((boxSpread: 1.1, ringSpread: 1.5, ringVsBox: 61.2, ringVsOutside: 1.3), groups: 1), photo),
          FoundRoute.check, reason: 'between them is the table, as beyond them');
    });
    test('pieces of many colours sewn together: the pieces', () {
      expect(routeOf(looking((boxSpread: 28.6, ringSpread: 17.2, ringVsBox: 12.8, ringVsOutside: 20.8)), photo),
          FoundRoute.check);
    });
    // 5 pieces of one cloth dropped on a cutting mat on a wooden floor (mat-scatter-bigmat-green-red), and 9 laid in a
    // tidy 3 x 3 grid on it (mat-grid-green-red), as measured 31 October 2026.
    const onMat = (boxSpread: 1.3, ringSpread: 1.5, ringVsBox: 88.4, ringVsOutside: 49.0);
    test('pieces of one cloth scattered on a mat: the pieces, as they sit on no grid', () {
      final scattered = FinderAnswer(squares: [
        for (final (x, y, turn) in const [(120.0, 140.0, 0.1), (420.0, 110.0, 0.5), (260.0, 330.0, 0.3), (540.0, 400.0, 0.7), (180.0, 560.0, 0.2)])
          _turned(x, y, 90, turn),
      ], groups: const [0, 0, 0, 0, 0], tiny: 0, look: onMat);
      expect(routeOf(scattered, photo), FoundRoute.check);
    });
    test('pieces of one cloth in a tidy grid on a mat: the crop, as for a print', () {
      expect(routeOf(looking(onMat, groups: 1), photo), FoundRoute.crop);
    });
    test('squares filling the photo, nothing beyond them to compare: by the grid only', () {
      expect(looksPrinted(looking((boxSpread: 0, ringSpread: 0, ringVsBox: 70, ringVsOutside: null))), isFalse);
    });
  });

  testWidgets('every box removed, then closed: nothing added and nothing said', (tester) async {
    final c = await openAdd(tester);
    await pick(tester);
    for (final at in const [Offset(150, 150), Offset(300, 150), Offset(450, 150), Offset(650, 650)]) {
      await tester.tapAt(onPhoto(tester, at));
      await tester.pumpAndSettle();
    }
    expect(inSheet(find.text('0 pieces, 4 removed')), findsOneWidget);
    await tapShown(tester, inSheet(find.text('Done')));
    await letWork(tester, done: () => sheet.evaluate().isEmpty);
    expect(inBox2(c), isEmpty);
    expect(find.textContaining('0 cloths'), findsNothing);
  });

  testWidgets('Done while the photo is read says to wait; once the finder has looked, that is gone', (tester) async {
    final shelf = Shelf(memoryDb());
    final box = (await tester.runAsync(shelf.makeBox))!;
    final bytes = (await tester.runAsync(() => FixturePhotos().pick(camera: false)))!;
    final photo = (await tester.runAsync(() => readPhoto(bytes)))!;
    final read = Completer<PickedPhoto>();
    await tester.pumpWidget(MaterialApp(localizationsDelegates: const [L.delegate], supportedLocales: L.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: AddCloth(box: box, shelf: shelf, photos: FixturePhotos(),
            words: lookupL(const Locale('en')), onClose: () {}, read: (_) => read.future)))));
    await tester.tap(find.text('Photo of the pieces'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pump();
    const wait = 'The cropper is still loading. Give it a moment and press again.';
    expect(find.text(wait), findsOneWidget);
    read.complete(photo);
    await letWork(tester, done: () => find.text('Your cloths').evaluate().isNotEmpty ||
        find.byKey(const ValueKey('pieces-photo')).evaluate().isNotEmpty);
    expect(find.byKey(const ValueKey('pieces-photo')), findsOneWidget);
    expect(find.text(wait), findsNothing);
  });

  testWidgets('a tap still snapping when she presses Next adds nothing she did not see', (tester) async {
    finder
      ..snapped = sq(120, 380, 90)
      ..snapHeld = Completer();
    final c = await openAdd(tester);
    await pick(tester);
    await tester.tapAt(onPhoto(tester, const Offset(150, 400)));
    await tester.pump();
    await tapShown(tester, inSheet(find.text('Next')));
    finder.snapHeld!.complete();
    await letWork(tester, done: () => find.text('Your cloths').evaluate().isNotEmpty);
    expect(inSheet(find.text('Add 4 pieces to box')), findsOneWidget);
    await tapShown(tester, inSheet(find.text('Add 4 pieces to box')));
    await letWork(tester, done: () => inBox2(c).isNotEmpty);
    expect([...inBox2(c)]..sort(), [1, 1, 2], reason: 'the 3 cloths she saw');
  });

  testWidgets('a press on a corner that does not move it changes nothing; a corner cannot shrink its box to nothing',
      (tester) async {
    await openAdd(tester);
    await pick(tester);
    await tapAndSettle(tester, inSheet(find.bySemanticsLabel('Zoom in')));
    final corner = onPhoto(tester, const Offset(200, 200));
    expect(tester.widget<CheckPieces>(find.byType(CheckPieces)).canUndo, isFalse);
    final press = await tester.startGesture(corner);
    await tester.pump();
    await press.up();
    await tester.pumpAndSettle();
    expect(tester.widget<CheckPieces>(find.byType(CheckPieces)).canUndo, isFalse, reason: 'no step to undo');

    // Corner 2 (bottom right, 200, 200) dragged onto corner 0 (top left, 100, 100).
    final to = onPhoto(tester, const Offset(100, 100));
    final drag = await tester.startGesture(corner);
    for (var i = 1; i <= 8; i++) {
      await drag.moveTo(Offset.lerp(corner, to, i / 8)!);
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();
    final p = tester.widget<CheckPieces>(find.byType(CheckPieces)).pieces.first;
    for (var j = 0; j < 2; j++) {
      expect((p.corner(2) - p.corner(j)).distance, greaterThanOrEqualTo(smallestSide));
    }
    expect(tester.widget<CheckPieces>(find.byType(CheckPieces)).canUndo, isTrue);
  });

  for (final (how, at) in [('inside it (a dent)', const Offset(140, 140)), ('across a side (a bow-tie)', const Offset(150, 50))]) {
    testWidgets('a corner moved $how does not move: the box stays convex', (tester) async {
      await openAdd(tester);
      await pick(tester);
      await tapAndSettle(tester, inSheet(find.bySemanticsLabel('Zoom in')));
      // Corner 2 (bottom right, 200, 200) of the box from 100, 100, in one move.
      final drag = await tester.startGesture(onPhoto(tester, const Offset(200, 200)));
      await tester.pump();
      await drag.moveTo(onPhoto(tester, at));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      final pieces = tester.widget<CheckPieces>(find.byType(CheckPieces));
      expect(pieces.pieces.first.corner(2), const Offset(200, 200));
      expect(pieces.canUndo, isFalse, reason: 'nothing changed');
    });
  }

  testWidgets('many pieces in say so in a toast; a warning the board shows stays its note', (tester) async {
    final c = await openAdd(tester);
    c
      ..note = 'This board needs more pieces.'
      ..warn = true
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      ..notifyListeners();
    await tester.pump();
    await pick(tester);
    await closes['Done']!(tester);
    await letWork(tester, done: () => inBox2(c).length == 3 && sheet.evaluate().isEmpty);
    expect(find.text('3 cloths, 4 pieces, added to Box 2.'), findsOneWidget);
    expect(c.note, 'This board needs more pieces.');
    expect(c.warn, isTrue);
  });

  // It's one piece (owner, 31 October 2026): the finder was wrong about the photo; it goes to the crop.
  for (final (from, answer) in [
    ('Are these your pieces?', () => three),
    ('the pieces too small to find', () => FinderAnswer(squares: const [], groups: const [], tiny: 2255)),
  ]) {
    testWidgets("It's one piece on $from: the crop for that photo, and Add stores 1 cloth of 1 piece", (tester) async {
      finder.answer = answer();
      final c = await openAdd(tester);
      await pick(tester);
      final button = inSheet(find.text("It's one piece"));
      expect(button, findsOneWidget);
      final target = tester.getSize(find.ancestor(of: button, matching: find.byType(PhoneButton)).first);
      expect(target.height, greaterThanOrEqualTo(44));
      final forgot = finder.forgot;
      await tapShown(tester, button);
      expect(finder.forgot, forgot + 1, reason: "the pieces and the worker's copy of the photo let go");
      await letWork(tester, done: () => inSheet(find.text('Add to box')).evaluate().isNotEmpty);
      expect(inSheet(find.text('fill the square with the piece')), findsOneWidget);
      expect(find.byKey(const ValueKey('pieces-photo')), findsNothing);
      expect(find.textContaining('too small'), findsNothing);
      expect(inSheet(find.text('1 piece')), findsOneWidget, reason: 'the count starts at 1');
      await tapShown(tester, inSheet(find.text('Add to box')));
      await letWork(tester, done: () => inBox2(c).isNotEmpty);
      expect(inBox2(c), [1]);
      expect(inSheet(find.byKey(const ValueKey('cloth-added'))), findsOneWidget);
    });
  }
}
