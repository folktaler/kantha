import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/phone/phone_sheet.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/db.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';
import '../../support/targets.dart';

/* My designs on a phone (redesign handover, Bottom sheets; decision 5): a sheet of rows, each opened by its Open,
   each with a ⋯ for rename, duplicate and delete; New design last. */
const noSaved = 'Nothing saved yet. Press Save and your design waits here.';
/* Words in a sheet's row, not the studio under it. */
Finder inRow(String words) => find.descendant(of: find.byType(SheetRow), matching: find.text(words));

/* Areca, then a new design saved as Banyan: Banyan is the last saved, so first. */
Future<StudioController> twoSaved(WidgetTester tester) async {
  final c = await pumpStudio(tester, size: phone);
  await saveAs(tester, c, 'Areca');
  c.newDesign();
  await letWork(tester, done: () => !c.solving && c.grid != null);
  await saveAs(tester, c, 'Banyan');
  expect(c.saved, hasLength(2));
  return c;
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(key('phone-title'));
  await tester.pumpAndSettle();
}

/* The ⋯ on the row of the `i`th design, top to bottom. */
Future<void> more(WidgetTester tester, int i) async {
  await tester.tap(find.bySemanticsLabel('More').at(i));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a phone the title opens My designs: a row for each design, its box under its name, each with Open',
      (tester) async {
    await twoSaved(tester);
    await openSheet(tester);
    expect(find.text('My designs'), findsOneWidget);
    expect(inRow('Banyan'), findsOneWidget);
    expect(inRow('Areca'), findsOneWidget);
    expect(inRow('Box 1'), findsNWidgets(2));
    expect(inRow('Open'), findsNWidgets(2));
    expect(tester.getTopLeft(inRow('Areca')).dy, greaterThan(tester.getTopLeft(inRow('Banyan')).dy), reason: 'the last saved first');
    expect(inRow('New design'), findsOneWidget);
    expect(inRow('Add'), findsOneWidget);
    expect(tester.getTopLeft(inRow('New design')).dy, greaterThan(tester.getTopLeft(inRow('Areca')).dy),
        reason: 'New design last');
    expect(find.text(noSaved), findsNothing);
  });

  testWidgets('on a phone Open on the second row puts that design on the board and closes My designs', (tester) async {
    final c = await twoSaved(tester);
    await openSheet(tester);
    await tester.tap(inRow('Open').at(1));
    await tester.pumpAndSettle();
    expect(c.name, 'Areca');
    expect(find.text('My designs'), findsNothing);
  });

  testWidgets('on a phone Open on a design whose cloth has gone closes My designs, and the studio says why where it can be '
      'read', (tester) async {
    final first = await pumpStudio(tester, size: phone);
    await saveAs(tester, first, 'Areca');
    await tester.runAsync(() => first.shelf.removeClothLeavingDesigns(first.saved.single.grid.first));
    // A later visit: the cloth she removed is not in this session at all.
    final c = await pumpStudio(tester, size: phone, sameDatabase: true);
    await openSheet(tester);
    await tester.tap(inRow('Open'));
    await tester.pumpAndSettle();
    expect(find.text('My designs'), findsNothing);
    expect(find.descendant(of: key('phone-toast'), matching: find.text(c.words.canvasMissingCloth)).hitTestable(), findsOneWidget);
    expect(c.savedId, isNot(c.saved.single.id));
    await tester.pump(const Duration(milliseconds: 2800));
  });

  // Storage failing: My designs closes, so the toast saying so is on the studio, not under the sheet's scrim.
  for (final row in ['Rename', 'Duplicate', 'Delete']) {
    testWidgets('on a phone a $row that storage fails closes My designs; the studio says so where it can be read', (tester) async {
      final shelf = FlakyShelf(memoryDb());
      final c = await pumpStudio(tester, size: phone, on: shelf);
      await saveAs(tester, c, 'Areca');
      shelf.failDesign = const ShelfError('storage');
      await openSheet(tester);
      await more(tester, 0);
      await tester.tap(inRow(row));
      await tester.pumpAndSettle();
      if (row == 'Rename') {
        await tester.enterText(find.byType(TextField), 'Zinnia');
        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Rename')));
      } else if (row == 'Delete') {
        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      }
      await letWork(tester, done: () => c.warn);
      final said = row == 'Delete'
          ? c.words.canvasDeleteFailed(c.words.deviceStorageFailed)
          : c.words.canvasSaveFailed(c.words.deviceStorageFailed);
      expect(find.text('My designs'), findsNothing);
      expect(find.descendant(of: key('phone-toast'), matching: find.text(said)).hitTestable(), findsOneWidget);
      expect(c.saved.map((d) => d.name), ['Areca'], reason: 'nothing changed');
      await tester.pump(const Duration(milliseconds: 2800));
    });
  }

  testWidgets('on a phone a tap on ⋯ opens its own sheet, named for the design, and does not open the design', (tester) async {
    final c = await twoSaved(tester);
    await openSheet(tester);
    await more(tester, 1);
    expect(c.name, 'Banyan', reason: 'Areca was not opened');
    expect(inRow('Rename'), findsOneWidget);
    expect(inRow('Duplicate'), findsOneWidget);
    expect(inRow('Delete'), findsOneWidget);
    // Its title: Areca, over My designs, which waits under it.
    expect(find.text('Areca'), findsNWidgets(2));
    expect(find.byType(tabler.Dots), findsNWidgets(2));
  });

  testWidgets('on a phone Rename asks for the name in a dialog; OK keeps it', (tester) async {
    final c = await twoSaved(tester);
    await openSheet(tester);
    await more(tester, 0);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(inRow('Duplicate'), findsNothing, reason: 'the ⋯ sheet closed');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Banyan');
    expect(field.maxLength, 80);
    await tester.enterText(find.byType(TextField), 'Zinnia');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Rename')));
    await letWork(tester, done: () => c.saved.any((d) => d.name == 'Zinnia'));
    expect(c.saved.map((d) => d.name), containsAll(['Zinnia', 'Areca']));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('My designs'), findsOneWidget, reason: 'My designs stays open');
    expect(inRow('Zinnia'), findsOneWidget);
  });

  testWidgets('on a phone Rename then Cancel leaves the name', (tester) async {
    final c = await twoSaved(tester);
    await openSheet(tester);
    await more(tester, 0);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Not this');
    await tester.tap(find.text('Cancel'));
    await letWork(tester, turns: 3);
    expect(c.saved.map((d) => d.name), unorderedEquals(['Banyan', 'Areca']));
  });

  testWidgets('on a phone Duplicate makes a third design', (tester) async {
    final c = await twoSaved(tester);
    await openSheet(tester);
    await more(tester, 0);
    await tester.tap(find.text('Duplicate'));
    await letWork(tester, done: () => c.saved.length == 3);
    expect(c.saved, hasLength(3));
    expect(find.text('Banyan copy'), findsOneWidget);
    expect(inRow('Open'), findsNWidgets(3));
  });

  testWidgets('on a phone Delete asks first; Delete leaves two of three, Cancel keeps it', (tester) async {
    final c = await twoSaved(tester);
    await openSheet(tester);
    await more(tester, 0);
    await tester.tap(find.text('Duplicate'));
    await letWork(tester, done: () => c.saved.length == 3);
    await more(tester, 0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Banyan copy”? This cannot be undone.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await letWork(tester, turns: 3);
    expect(c.saved, hasLength(3));
    await more(tester, 0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await letWork(tester, done: () => c.saved.length == 2);
    expect(c.saved, hasLength(2));
    expect(find.text('Banyan copy'), findsNothing);
    expect(find.text('My designs'), findsOneWidget, reason: 'My designs stays open');
  });

  // Deleted elsewhere (another tab) while its ⋯ sheet is up: Rename and Delete do nothing, and nothing throws.
  for (final row in ['Rename', 'Delete']) {
    testWidgets('on a phone $row on a design deleted while its ⋯ sheet is open does nothing', (tester) async {
      final c = await twoSaved(tester);
      await openSheet(tester);
      await more(tester, 0);
      final gone = c.saved.firstWhere((d) => d.name == 'Banyan');
      await tester.runAsync(() => c.shelf.deleteDesign(gone.id));
      await letWork(tester, done: () => c.saved.length == 1);
      await tester.tap(inRow(row));
      await letWork(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(c.saved.map((d) => d.name), ['Areca']);
      expect(find.text('My designs'), findsOneWidget);
    });
  }

  testWidgets('on a phone New design deals a fresh, unsaved design and closes the sheet', (tester) async {
    final c = await twoSaved(tester);
    await openSheet(tester);
    await tester.tap(inRow('New design'));
    await tester.pumpAndSettle();
    expect(c.savedId, isNull);
    expect(find.text('My designs'), findsNothing);
  });

  testWidgets('on a phone with nothing saved My designs says so, over New design', (tester) async {
    await pumpStudio(tester, size: phone);
    await openSheet(tester);
    expect(find.text(noSaved), findsOneWidget);
    expect(inRow('Open'), findsNothing);
    expect(inRow('New design'), findsOneWidget);
  });

  testWidgets('on a phone a design from the Sample box says Sample; one whose box is not hers says its pattern', (tester) async {
    final c = await pumpOnSample(tester, size: phone);
    await saveAs(tester, c, 'Areca');
    final p = c.saved.single;
    await tester.runAsync(() => c.shelf.saveDesign(DesignInput(name: 'Loose', layout: p.layout.name, mount: p.mount.name,
        box: null, seed: p.seed, started: null, firstSolve: null,
        grid: [for (var i = 0; i < p.grid.length; i++) GridCell(p.grid[i], p.rot[i])])));
    await letWork(tester, done: () => c.saved.length == 2);
    await openSheet(tester);
    expect(inRow('Sample'), findsOneWidget);
    expect(inRow('Chess'), findsOneWidget);
  });

  testWidgets('on a phone every target in My designs and its ⋯ sheet is at least 44 px, every row at least 56', (tester) async {
    await twoSaved(tester);
    await openSheet(tester);
    checkTargets(tester, 44);
    for (final e in find.byType(SheetRow).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, greaterThanOrEqualTo(56));
    }
    final dots = tester.getSize(find.bySemanticsLabel('More').first);
    expect(dots.width, 48);
    expect(dots.height, greaterThanOrEqualTo(48));
    await more(tester, 0);
    checkTargets(tester, 44);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    checkTargets(tester, 44);
    for (final b in find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)).evaluate()) {
      expect(tester.getSize(find.byWidget(b.widget)).height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });
}
