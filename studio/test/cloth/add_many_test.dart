/* Add a piece where there is a finder (the web): many pieces in one photo, the check, her cloths, and every close
   adding what is waiting. The finder here is a stand-in that answers at once; the real one runs in a web worker
   (web/finder_worker.dart) and is checked in a browser. */
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/cloth/piece_finder.dart';
import 'package:kantha_studio/cloth/prepare.dart' show PickedPhoto;
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
  bool fails;
  final snaps = <Offset>[];
  final cuts = <int>[];
  var forgot = 0;

  @override
  Future<FinderAnswer> find(PickedPhoto photo) async {
    if (fails) throw StateError('the worker did not load');
    return answer;
  }

  @override
  Future<Float32List?> snap(Offset at) async {
    snaps.add(at);
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

final three = FinderAnswer(squares: [sq(100, 100), sq(250, 100), sq(400, 100), sq(600, 600)], groups: [0, 0, 1, 2], tiny: 0);

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
      'counts and the sheet closes with a toast', (tester) async {
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
    await letWork(tester, done: () => inBox2(c).length == 4 && sheet.evaluate().isEmpty);
    expect(sheet, findsNothing, reason: 'the sheet closes once they are in');
    expect([...inBox2(c)]..sort(), [1, 1, 1, 3]);
    expect(find.text('4 cloths, 6 pieces, added to Box 2.'), findsOneWidget);
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

  testWidgets('an add that fails part way keeps the sheet open with the error; again adds only the rest', (tester) async {
    final shelf = FailingAdd(memoryDb(), after: 1);
    final c = await openAdd(tester, on: shelf);
    await pick(tester);
    await next(tester);
    await tapShown(tester, inSheet(find.text('Add 4 pieces to box')));
    const full = 'This box holds 200 cloths already. Take some out before adding more.';
    await letWork(tester, done: () => find.text(full).evaluate().isNotEmpty);
    expect(sheet, findsOneWidget);
    expect(inBox2(c), hasLength(1), reason: 'the first went in');
    expect(inSheet(find.text('Add 2 pieces to box')), findsOneWidget, reason: 'the rest still wait');

    shelf.fail = false;
    await tapShown(tester, inSheet(find.text('Add 2 pieces to box')));
    await letWork(tester, done: () => inBox2(c).length == 3 && sheet.evaluate().isEmpty);
    expect([...inBox2(c)]..sort(), [1, 1, 2]);
    expect(find.text('3 cloths, 4 pieces, added to Box 2.'), findsOneWidget, reason: 'all that went in from this photo');
  });
}
