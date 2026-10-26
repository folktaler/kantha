import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/controller.dart';
import '../support/pump.dart';
import '../support/studio_fixture.dart';

/* Box 2 with one cloth of hers of 3 pieces, on the board, and that cloth's Fix this cloth sheet open. */
Future<(StudioController, String)> openFix(WidgetTester tester, {String fabric = 'Cotton'}) async {
  final c = await pumpStudio(tester, photos: FixturePhotos());
  final id = (await tester.runAsync(() => c.shelf.addClothForTest(boxPieces: 3, fabric: fabric)))!;
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tab-cloth')));
  await tester.pumpAndSettle();
  await tapSwatch(tester, id);
  return (c, id);
}

/* Its swatch, scrolled into view first; the sheet opens once the cloth is read. */
Future<void> tapSwatch(WidgetTester tester, String id) async {
  await tapShown(tester, find.byKey(ValueKey('swatch-$id')));
  await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
}

void main() {
  testWidgets('a cloth of hers opens to be fixed; a new count is saved and the design is untouched', (tester) async {
    final (c, id) = await openFix(tester);
    final before = c.grid == null ? null : List.of(c.grid!);
    expect(inSheet(find.text('Save changes')), findsOneWidget);
    await tapShown(tester, inSheet(find.bySemanticsLabel('One more piece')));
    // A frame between the two taps, as there always is on a screen: Save is drawn enabled once the count has changed.
    await tester.pump();
    await tapShown(tester, inSheet(find.text('Save changes')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(c.cloth.firstWhere((x) => x.id == id).stock, 4);
    expect(c.grid, before);
  });

  // Fabric is not asked (2026-10-07 sample-box spec, decision 9): what was stored stays as it was.
  for (final stored in ['', 'Cotton']) {
    testWidgets('a cloth stored with fabric "$stored" saves a count change, and its fabric is kept', (tester) async {
      final (c, id) = await openFix(tester, fabric: stored);
      expect(find.text('Fabric type'), findsNothing);
      await tapShown(tester, inSheet(find.bySemanticsLabel('One more piece')));
      await tester.pump();
      await tapShown(tester, inSheet(find.text('Save changes')));
      await letWork(tester, done: () => c.cloth.firstWhere((x) => x.id == id).stock == 4);
      final now = c.cloth.firstWhere((x) => x.id == id);
      expect((now.stock, now.fabric), (4, stored));
      expect(sheet, findsNothing, reason: 'the sheet closes');
    });
  }

  testWidgets('Remove asks first, then takes the cloth out of the box', (tester) async {
    final (c, id) = await openFix(tester);
    await tapShown(tester, inSheet(find.text('Remove this piece')));
    await tester.pumpAndSettle();
    expect(find.text('Remove it? It comes out of the box, and a pattern already made from it will say so.'), findsOneWidget);
    // Beyond the brief: the "then takes it out" half.
    await tester.tap(find.text('Remove this piece').last);
    await letWork(tester, done: () => c.cloth.firstWhere((x) => x.id == id).box == null);
    expect(c.cloth.firstWhere((x) => x.id == id).box, isNull);
    expect(sheet, findsNothing, reason: 'the sheet closes');
  });

  // Beyond the brief.
  testWidgets('Cancel leaves the cloth where it was', (tester) async {
    final (c, id) = await openFix(tester);
    await tapShown(tester, inSheet(find.text('Remove this piece')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await letWork(tester, turns: 5);
    expect(c.cloth.firstWhere((x) => x.id == id).box, 2);
    expect(inSheet(find.text('Save changes')), findsOneWidget, reason: 'the sheet stays');
  });

  testWidgets('a new count alone does not measure the cloth again; Escape closes the sheet', (tester) async {
    final (c, id) = await openFix(tester);
    final version = c.cloth.firstWhere((x) => x.id == id).version;
    await letWork(tester, turns: 10); // the cropper is ready, so a crop could be asked for
    await tapShown(tester, inSheet(find.bySemanticsLabel('One fewer piece')));
    await tester.pump();
    await tapShown(tester, inSheet(find.text('Save changes')));
    await letWork(tester, turns: 20);
    final now = c.cloth.firstWhere((x) => x.id == id);
    expect((now.stock, now.version), (2, version));

    await tapSwatch(tester, id);
    expect(sheet, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('Save changes waits until something changed; a moved crop is measured again and stored', (tester) async {
    final (c, id) = await openFix(tester);
    final version = c.cloth.firstWhere((x) => x.id == id).version;
    expect(inSheet(find.text('Save changes')), findsOneWidget);
    await tapShown(tester, inSheet(find.text('Save changes')));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget, reason: 'nothing changed, so Save does nothing');
    await letWork(tester, turns: 10); // the cropper reads the stored photo
    await tester.ensureVisible(find.byKey(const ValueKey('crop-stage')));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('crop-stage')), const Offset(-10, -10));
    await tester.pumpAndSettle();
    await tapShown(tester, inSheet(find.text('Save changes')));
    await letWork(tester, done: () => c.cloth.firstWhere((x) => x.id == id).version > version);
    expect(c.cloth.firstWhere((x) => x.id == id).version, version + 1);
    expect(sheet, findsNothing, reason: 'the sheet closes');
  });
}
