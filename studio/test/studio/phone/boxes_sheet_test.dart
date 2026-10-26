import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/database.dart' show BoxRow;
import 'package:kantha_studio/data/sample_box.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/phone/phone_sheet.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/db.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';

/* Your boxes on a phone (redesign handover, Bottom sheets), opened from the Cloth box tab's picker. */
final picker = key('box-picker');
Finder row(String name) => find.ancestor(of: inSheet(find.text(name)), matching: find.byType(SheetRow));
bool checked(String name) => find.descendant(of: row(name), matching: find.byType(tabler.Check)).evaluate().isNotEmpty;

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(key('tab-cloth'));
  await tester.pumpAndSettle();
  await tester.tap(picker);
  await tester.pumpAndSettle();
}

/* A shelf whose list of boxes reaches the studio only once the test lets it: the time, 40 to 360 ms in a browser, between
   a box being made and the feed listing it. A list read once (a watch's first answer) is not held. */
class HeldShelf extends Shelf {
  HeldShelf(super.db);
  Completer<void>? hold;
  /* Every box any list has let through. */
  final seen = <int>{};
  @override
  Stream<List<BoxRow>> watchBoxes() {
    var first = true;
    return super.watchBoxes().asyncMap((b) async {
      if (!first) await hold?.future;
      first = false;
      seen.addAll([for (final r in b) r.id]);
      return b;
    });
  }
}

/* Add a box, and the box opened before the feed lists it. Returns the new box. */
Future<int> madeBeforeTheFeed(WidgetTester tester, StudioController c, HeldShelf shelf) async {
  final was = c.box;
  await openSheet(tester);
  shelf.hold = Completer<void>();
  await tester.tap(row('Add a box'));
  await letWork(tester, done: () => c.box != was && sheet.evaluate().isEmpty);
  final made = c.box!;
  expect(made, isNot(was));
  expect(shelf.seen, isNot(contains(made)), reason: 'the feed has not listed the new box yet');
  return made;
}

/* A photo, Add to box, then Done; then the feed lists what it holds. */
Future<void> addOnePhoto(WidgetTester tester, StudioController c, HeldShelf shelf) async {
  expect(sheet, findsOneWidget, reason: 'Add a piece is open');
  await tester.tap(inSheet(find.text('Photo of the piece')));
  await letWork(tester, turns: 10);
  await tapShown(tester, inSheet(find.text('Add to box')));
  await letWork(tester, done: () => c.cloth.any((x) => x.id == 'C-34'));
  await tapShown(tester, inSheet(find.text('Done')));
  await tester.pumpAndSettle();
  shelf.hold!.complete();
  shelf.hold = null;
  await letWork(tester, turns: 10);
}

void main() {
  testWidgets('on a phone the picker opens Your boxes: the Sample box first, then hers newest first, the check on the one on '
      'the board, then Add a box', (tester) async {
    final (:c, :box2) = await pumpThree(tester, size: phone);
    expect(c.isSample(c.box!), isTrue);
    await openSheet(tester);
    expect(inSheet(find.text('Your boxes')), findsOneWidget);
    final names = ['Sample', 'Box 2', 'Box 1', 'Add a box'];
    for (final n in names) {
      expect(row(n), findsOneWidget, reason: n);
    }
    for (var i = 1; i < names.length; i++) {
      expect(tester.getRect(row(names[i - 1])).top, lessThan(tester.getRect(row(names[i])).top), reason: names[i]);
    }
    expect(inSheet(find.text('70 pieces · sample cloth')), findsOneWidget);
    expect(inSheet(find.text('0 pieces')), findsOneWidget);
    expect(inSheet(find.text('105 pieces')), findsOneWidget);
    expect(inSheet(find.text('Makes the next number and opens it')), findsOneWidget);
    expect(find.descendant(of: row('Add a box'), matching: find.text('Add')), findsOneWidget);
    expect(inSheet(find.text('Add sample cloth')), findsNothing, reason: 'there is a Sample box');
    expect([for (final n in names) if (checked(n)) n], ['Sample']);
    expect(tester.widget<SheetRow>(row('Sample')).selected, isTrue);

    // A row turns the studio to that box, and the sheet goes.
    await tester.tap(row('Box 2'));
    await tester.pumpAndSettle();
    expect(c.box, box2);
    expect(sheet, findsNothing);
    expect(find.descendant(of: picker, matching: find.text('Box 2')), findsOneWidget);
  });

  testWidgets('on a phone Add a box makes Box 2 and opens it; the sheet goes, and the Cloth box tab shows it', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    final was = c.box;
    await openSheet(tester);
    expect(checked('Box 1'), isTrue);
    expect(row('Add sample cloth'), findsOneWidget, reason: 'no Sample box');
    await tester.tap(row('Add a box'));
    await letWork(tester, done: () => c.ownBoxes.length == 2 && sheet.evaluate().isEmpty);
    expect(c.ownBoxes.length, 2);
    final made = c.ownBoxes.firstWhere((b) => b != was);
    expect(c.box, made);
    expect(sheet, findsNothing);
    expect(tester.widget<Pressable>(key('tab-cloth')).selected, isTrue, reason: 'the Cloth box tab is still selected');
    expect(find.descendant(of: picker, matching: find.text('Box 2')), findsOneWidget);
    expect(find.descendant(of: picker, matching: find.text('0 pieces')), findsOneWidget);
  });

  testWidgets('on a phone Add sample cloth makes the Sample box and opens it', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await openSheet(tester);
    await tester.tap(row('Add sample cloth'));
    await letWork(tester, done: () => c.sampleBox != null && c.box == c.sampleBox && sheet.evaluate().isEmpty);
    expect(c.sampleBox, isNotNull);
    expect(c.box, c.sampleBox);
    expect(sheet, findsNothing);
    expect(find.descendant(of: picker, matching: find.text('Sample')), findsOneWidget);
  });

  testWidgets('on a phone a box that could not be made is toasted on the studio, the sheet gone, and nothing changes', (tester) async {
    final shelf = FlakyShelf(memoryDb());
    final c = await pumpStudio(tester, size: phone, on: shelf);
    final before = c.box;
    shelf.failMake = const ShelfError('storage');
    await openSheet(tester);
    await tester.tap(row('Add a box'));
    const said = 'That did not work. Try again in a moment.';
    await letWork(tester, done: () => find.descendant(of: key('phone-toast'), matching: find.text(said)).evaluate().isNotEmpty);
    expect(tester.takeException(), isA<ShelfError>(), reason: 'a storage failure is logged');
    expect(find.descendant(of: key('phone-toast'), matching: find.text(said)), findsOneWidget);
    expect((c.box, c.ownBoxes.length), (before, 1));
    expect(sheet, findsNothing, reason: 'the toast is read on the studio, not under the sheet');
    await tester.pump(const Duration(milliseconds: 2800));
  });

  group('on a phone a box just made is hers before the feed lists it', () {
    Future<(StudioController, HeldShelf)> pump(WidgetTester tester) async {
      final shelf = HeldShelf(memoryDb());
      final c = await pumpStudio(tester, size: phone, on: shelf, photos: FixturePhotos());
      return (c, shelf);
    }

    Future<void> holdsOne(WidgetTester tester, StudioController c, HeldShelf shelf, int made) async {
      final boxes = (await tester.runAsync(() => shelf.db.select(shelf.db.boxes).get()))!;
      expect(boxes, hasLength(2), reason: 'Box 1 and the box just made, and no other');
      expect(c.box, made, reason: 'the studio stays on the box just made');
      expect(c.cloth.where((x) => x.box == made).map((x) => x.id), ['C-34'], reason: 'the photo went into the box just made');
      expect(find.descendant(of: picker, matching: find.text('Box 2')), findsOneWidget);
      expect(find.descendant(of: picker, matching: find.text('1 piece')), findsOneWidget);
    }

    testWidgets('Add pieces adds to it, and makes no second box', (tester) async {
      final (c, shelf) = await pump(tester);
      final made = await madeBeforeTheFeed(tester, c, shelf);
      await tester.tap(key('add-pieces'));
      await tester.pumpAndSettle();
      await addOnePhoto(tester, c, shelf);
      await holdsOne(tester, c, shelf, made);
    });

    testWidgets('an empty square adds to it, and makes no second box', (tester) async {
      final (c, shelf) = await pump(tester);
      final made = await madeBeforeTheFeed(tester, c, shelf);
      await tester.tap(key('empty-cell-0'));
      await tester.pumpAndSettle();
      await addOnePhoto(tester, c, shelf);
      await holdsOne(tester, c, shelf, made);
    });

    /* A fresh device's Sample box, and nothing of hers: Add a box makes Box 1. */
    Future<(StudioController, HeldShelf)> onSample(WidgetTester tester) async {
      final shelf = HeldShelf(memoryDb());
      await tester.runAsync(() => makeSampleBox(shelf));
      final c = await pumpStudio(tester, size: phone, on: shelf);
      return (c, shelf);
    }

    Future<void> letTheFeedThrough(WidgetTester tester, HeldShelf shelf) async {
      shelf.hold!.complete();
      shelf.hold = null;
      await letWork(tester, turns: 10);
    }

    testWidgets('the picker reads Box 1 at once, and Delete box asks about Box 1', (tester) async {
      final (c, shelf) = await onSample(tester);
      await madeBeforeTheFeed(tester, c, shelf);
      expect(find.descendant(of: picker, matching: find.text('Box 1')), findsOneWidget);
      expect(find.descendant(of: picker, matching: find.text('0 pieces')), findsOneWidget);
      await tester.tap(find.text('Delete box'));
      await tester.pumpAndSettle();
      expect(find.text(c.words.boxesDeleteAsk('1')), findsOneWidget);
      await tester.tap(find.text(c.words.deviceDeleteCancel));
      await tester.pumpAndSettle();
      await letTheFeedThrough(tester, shelf);
      expect(find.descendant(of: picker, matching: find.text('Box 1')), findsOneWidget, reason: 'and still once the feed lists it');
    });

    testWidgets('deleted by another tab before the feed lists it, Delete box drops it from Your boxes', (tester) async {
      final (c, shelf) = await onSample(tester);
      final made = await madeBeforeTheFeed(tester, c, shelf);
      await tester.runAsync(() => shelf.deleteBox(made, cloth: const {})); // the other tab
      await tester.tap(find.text('Delete box'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await letWork(tester, done: () => !c.ownBoxes.contains(made));
      expect(c.ownBoxes, isNot(contains(made)));
      expect(c.box, isNot(made), reason: 'the studio turns off the gone box');
      expect(shelf.seen, isNot(contains(made)), reason: 'the feed never listed it');
      await openSheet(tester);
      expect(row('Box 1'), findsNothing);
      expect(row('Sample'), findsOneWidget);
      await letTheFeedThrough(tester, shelf);
    });
  });
}
