import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kantha_studio/main.dart';
import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export → a cleared device → import: photos, designs and box numbers all come back; the Sample box, '
      'emptied, is deleted', (t) async {
    final delivery = CaptureDelivery(), files = CaptureFiles(), photos = FixturePhotos();
    await runKantha(photos: photos, delivery: delivery, files: files, database: freshDatabase('backup-a'));
    await settle(t, 5);
    await startFromSample(t); // the same taps as the journey
    final box = await addOwnBox(t);
    await photographFive(t, box: box);
    await saveDesignNamed(t, 'Moved');
    final before = await whatItHolds(appShelf(t).db);
    expect((before.boxes.length, before.cloths.length, before.designs.length), (2, 15, 1),
        reason: 'the Sample box and Box 1; 10 + 5 cloths; Moved');
    // ≡ → Back up: the sheet closes as the file is made.
    await backupRow(t, 'Save a backup file');
    await waitUntil(t, () => delivery.backups.isNotEmpty, seconds: 60); await settle(t);
    expect(delivery.backups.single.name, matches(RegExp(r'^kantha-backup-\d{4}-\d{2}-\d{2}\.kantha$')));
    files.next = delivery.backups.single;

    // Another device, or this one cleared: a fresh database, which makes a Sample box again and holds nothing of hers.
    await closeTheApp(t);
    await runKantha(photos: photos, delivery: delivery, files: files, database: freshDatabase('backup-b'));
    await settle(t, 5);
    await startFromSample(t);
    expect(find.textContaining('Box 1'), findsNothing, reason: 'the cleared device has none of her boxes');
    final cleared = await whatItHolds(appShelf(t).db);
    expect((cleared.boxes.length, cleared.cloths.length, cleared.designs.length), (1, 10, 0),
        reason: 'only a fresh Sample box: nothing of hers yet');
    await backupRow(t, 'Open a backup file'); await settle(t);
    await tapIt(t, find.text('Replace with the file'));
    // Said as a toast over the studio.
    await waitFor(t, find.textContaining('This device now holds what was in'), seconds: 60);

    // Every row came back as it was: the Sample box (id 1) and Box 1 (id 2) in place of the fresh Sample box,
    // photos byte for byte, each design's cells and turns, the box numbers, the counters; only the photo numbers are new.
    final after = await whatItHolds(appShelf(t).db);
    expectSameHeld(after, before, photosRenumbered: true);
    expectCountersPastEveryId(after);
    // Each photo that came in has a new number, past every one either device had given, so the studio never shows
    // one photo for another; the photo counter is past them all.
    final given = [...before.cloths, ...cleared.cloths].map((c) => c.photoNumber).reduce(math.max);
    final renumbered = [for (final c in after.cloths) c.photoNumber];
    expect(renumbered.toSet(), hasLength(renumbered.length), reason: 'each photo its own number');
    expect(renumbered.every((n) => n > given), isTrue, reason: 'past every photo number either device gave: $renumbered');
    expect(after.counters['photo'], greaterThan(renumbered.reduce(math.max)), reason: 'the next photo number');

    await openMyDesigns(t);
    expect(inSheet(find.text('Moved')), findsOneWidget);
    // The design, opened on this device, is made into its files from the photos that came back.
    await tapIt(t, inSheet(find.text('Moved'))); await settle(t, 4); // its row opens it
    expect(find.byType(BottomSheet), findsNothing, reason: 'My designs closes on the design');
    await waitUntil(t, () => titleOf(t) == 'Moved');
    await clothTab(t);
    await waitFor(t, boxPicker('Box 1\n35 pieces'));
    await expectSwatches(t, box);
    final firstPhoto = find.descendant(of: find.byKey(const ValueKey('swatch-C-11')), matching: find.byType(Image));
    expect(firstPhoto, findsOneWidget, reason: 'her first photo came back');
    await exportRow(t, 'Print pattern PDF');
    await waitUntil(t, () => delivery.pdfs.isNotEmpty, seconds: 60); await settle(t);
    await exportRow(t, 'Save photo');
    await waitUntil(t, () => delivery.photos.isNotEmpty, seconds: 60); await settle(t);
    expect(delivery.pdfs, ['moved.pdf']);
    expect(delivery.photos, ['moved.png']);
    expectTheFiles(delivery, 'moved');

    // The Sample box goes: opened from Your boxes, each of its 10 cloths removed, then Delete box.
    await clothTab(t);
    await tapIt(t, find.byKey(const ValueKey('box-picker'))); await settle(t, 1);
    await tapIt(t, inSheet(find.text('Sample'))); await settle(t);
    await waitFor(t, boxPicker('Sample\n70 pieces · sample cloth'));
    final shelf = appShelf(t);
    final sample = after.cloths.where((c) => c.box == 1).map((c) => c.id).toList();
    expect(sample, unorderedEquals([for (var n = 1; n <= 10; n++) 'C-$n']), reason: 'the Sample box holds C-1 to C-10');
    for (final id in sample) {
      await tapIt(t, find.byKey(ValueKey('swatch-$id'))); await settle(t);
      await tapIt(t, inSheet(find.text('Remove this piece'))); await settle(t);
      await tapIt(t, find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove this piece')));
      // Removed is gone from the database: the row is deleted, and its id is not dealt again.
      Future<bool> held() async => (await shelf.db.select(shelf.db.cloths).get()).any((c) => c.id == id);
      var still = await held();
      for (var i = 0; i < 300 && still; i++) {
        await t.pump(const Duration(milliseconds: 100));
        still = await held();
      }
      expect(still, isFalse, reason: '$id is out of the Sample box');
      await settle(t);
      expect(find.byType(BottomSheet), findsNothing, reason: 'Fix this cloth closes once it is removed');
    }
    await tapIt(t, find.descendant(of: find.byKey(const ValueKey('dock-cloth')), matching: find.text('Delete box')));
    await settle(t);
    expect(find.text('Delete the Sample box? It holds no cloth.'), findsOneWidget);
    await tapIt(t, find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete'))); await settle(t);
    await waitFor(t, boxPicker('Box 1\n35 pieces'));
    final gone = await whatItHolds(shelf.db);
    expect([for (final b in gone.boxes) b.id], [box], reason: 'only Box 1 is left');

    // The next ones made carry on past what came back: Box 2 (id 3), C-16, P-2. The Sample box's id is not dealt again.
    final made = await shelf.makeBox();
    expect(made, 3, reason: 'the next box');
    final next = await whatItHolds(shelf.db);
    expect(next.boxes.firstWhere((b) => b.id == made).number, 2, reason: 'numbered 2');
    expect((next.counters['box'], next.counters['boxNumber'], next.counters['cloth'], next.counters['design']), (4, 3, 16, 2),
        reason: 'the Sample box is id 1 with C-1…C-10, Box 1 is id 2 with C-11…C-15, Moved is P-1; the box made here is id 3, number 2');
  });
}
