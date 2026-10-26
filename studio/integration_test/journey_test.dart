import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/l10n/words.dart';
import 'package:kantha_studio/main.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/studio/phone/phone_studio.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('somebody new: the Sample box arranged, every template tried, her own box of five photos, a design saved, '
      'found, downloaded, and still there after a restart', (t) async {
    final delivery = CaptureDelivery(), photos = FixturePhotos();
    await runKantha(photos: photos, delivery: delivery, database: freshDatabase('journey'));
    await settle(t, 5);
    // A fresh install opens on the Sample box, arranged.
    await startFromSample(t);

    // Every template, from the Sample box, in the Design tab's strip. None is faded: each tile is named by its title
    // alone, not by why the box cannot fill it.
    final words = L.of(t.element(find.byType(PhoneStudio)));
    Finder tile(LayoutKey k) => find.byKey(ValueKey('tile-${k.name}'));
    bool chosen(LayoutKey k) => t.widget<Pressable>(tile(k)).selected ?? false;
    for (final k in layoutKeys) {
      expect(t.widget<Pressable>(tile(k)).label, words.layoutTitle(k), reason: '${words.layoutTitle(k)}: the Sample box fills it');
    }
    final board = find.bySemanticsLabel(RegExp(r'^Row 1, column 1 — '));
    bool arranged() => board.evaluate().isNotEmpty && find.text(words.canvasSolving).evaluate().isEmpty;
    // The board is already there from the template before, so the wait is on what the tap changes: its tile is the
    // chosen one, and the solve is done.
    Future<void> chooseTile(WidgetTester t, LayoutKey k) async {
      await tapIt(t, tile(k));
      await waitUntil(t, () => chosen(k) && arranged(), seconds: 60);
    }
    for (final k in layoutKeys) {
      await chooseTile(t, k);
      await settle(t);
      cellNames(t); // all 35 cells
    }
    // Back to the first, where her own box will be arranged.
    await chooseTile(t, layoutKeys.first);
    await settle(t);

    // Her own box: Add a box, then five photos of 7 pieces each, and the board arranges from them.
    final box = await addOwnBox(t);
    await photographFive(t, box: box);
    expect(board, findsOneWidget);
    await expectSwatches(t, box); // each cloth she added, in the swatch row under the colour it measured as

    await patternsTab(t);
    final first = cellNames(t);
    await chooseTile(t, LayoutKey.boro);
    await settle(t, 6);
    await chooseTile(t, LayoutKey.contrast);
    await settle(t);
    expect(cellNames(t), first, reason: 'returning to a template shows the arrangement she left');

    await saveDesignNamed(t, 'Zinnia');
    await openMyDesigns(t);
    expect(inSheet(find.text('Zinnia')), findsOneWidget);
    await closeSheet(t);

    await exportRow(t, 'Print pattern PDF');
    await waitUntil(t, () => delivery.pdfs.isNotEmpty, seconds: 60); await settle(t);
    await exportRow(t, 'Save photo');
    await waitUntil(t, () => delivery.photos.isNotEmpty, seconds: 60); await settle(t);
    expect(delivery.pdfs, ['zinnia.pdf']);
    expect(delivery.photos, ['zinnia.png']);
    expectTheFiles(delivery, 'zinnia');
    await pictureOfTheStudio(binding, t);

    // A restart: the app goes, its database closed, and comes back through a new connection to the same storage.
    final kept = await whatItHolds(appShelf(t).db);
    expect((kept.boxes.length, kept.cloths.length, kept.designs.length), (2, 15, 1),
        reason: 'the Sample box and Box 1; 10 + 5 cloths; Zinnia, saved once and exported as it was');
    await closeTheApp(t);
    await runKantha(photos: photos, delivery: delivery, database: sameDatabase('journey'));
    await settle(t, 6);
    await waitFor(t, title);
    expectSameHeld(await whatItHolds(appShelf(t).db), kept);
    await waitFor(t, board, seconds: 60);
    await openMyDesigns(t);
    expect(inSheet(find.text('Zinnia')), findsOneWidget);
    await closeSheet(t);
    // The studio opens on her newest box that can fill: Box 1.
    await clothTab(t);
    expect(boxPicker('Box 1\n35 pieces'), findsOneWidget);
  });
}
