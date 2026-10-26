import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/backup/backup_flows.dart';
import 'package:kantha_studio/data/backup.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/shelf_feed.dart';
import '../support/db.dart';
import '../support/pump.dart';
import '../support/studio_fixture.dart';

/* The flows the Back up sheet runs. The sheet's own tests (test/studio/phone/menu_panel_test.dart) prove them end to
   end; these hold what a caller is told, and what an import leaves behind in the studio. */
void main() {
  final words = lookupL(const Locale('en'));

  test('a backup handed over is kept, and the file is named', () async {
    final s = await studio();
    final d = CaptureDelivery();
    final said = <String>[];
    var busy = 0;
    final out = await exportBackupNow(c: s.c, delivery: d, say: (t, {failed = false}) => said.add(t), words: words, busy: () => busy++);
    final name = backupFileName(DateTime.now());
    expect(out, BackupSaved.kept);
    expect(d.backups.keys, [name]);
    expect(said, ['Saved $name.']);
    expect(busy, 1);
  });

  test('a share sheet she dismissed is notKept, and nothing is said', () async {
    final s = await studio();
    final said = <String>[];
    final out = await exportBackupNow(c: s.c, delivery: CaptureDelivery(kept: false), say: (t, {failed = false}) => said.add(t),
        words: words);
    expect(out, BackupSaved.notKept);
    expect(said, ['']);
  });

  testWidgets('after an import, nothing this session remembered from before shows', (tester) async {
    final files = FixtureFiles.withBackupOf(await tester.runAsync(emptyDeviceBackup));
    final c = await pumpStudio(tester, files: files);
    await tester.runAsync(() => c.save());
    c.loadLayout(LayoutKey.gradient);
    await tester.pumpAndSettle();
    await tester.runAsync(() => c.importFrom(files));
    await tester.pumpAndSettle();
    expect(c.memory, isEmpty);
    expect(c.savedId, isNull);
    expect(c.saved, isEmpty);
  });

  testWidgets('after an import, the squares decoded before are let go of', (tester) async {
    final files = FixtureFiles.withBackupOf(await tester.runAsync(emptyDeviceBackup));
    final c = await pumpStudio(tester, files: files);
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.currentSize + cache.liveImageCount, greaterThan(0), reason: 'the board drew its squares');
    await tester.runAsync(() => c.importFrom(files));
    expect((cache.currentSize, cache.liveImageCount, cache.pendingImageCount), (0, 0, 0));
    await tester.pumpAndSettle();
  });

  testWidgets('a design just saved is not offered to Export once an import has replaced it', (tester) async {
    final files = FixtureFiles.withBackupOf(await tester.runAsync(emptyDeviceBackup));
    final c = await pumpStudio(tester, files: files);
    final id = (await tester.runAsync(() async {
      final id = await c.save();
      await c.importFrom(files); // at once: the shelf's watch has not yet told the studio of the save
      return id;
    }))!;
    expect(c.designFor(id), isNull);
    await tester.pumpAndSettle();
    expect(c.designFor(id), isNull);
  });

  test('afterImport forgets the design just saved, before the shelf has said a word about it', () async {
    final shelf = Shelf(memoryDb());
    await seedFixtureBox(shelf);
    final c = StudioController(shelf: shelf, solver: QuickSolver(), words: lookupL(const Locale('en')), side: testSideDb);
    c.restock(await shelfFeed(shelf).first); // once: no feed tells it of the save
    c.start();
    await settle();
    final id = (await c.save())!;
    expect(c.designFor(id), isNotNull, reason: "the save's own copy stands in");
    await c.importFrom(FixtureFiles.withBackupOf(await emptyDeviceBackup()));
    expect(c.designFor(id), isNull);
  });

  test('a backup made before 7 Oct, with a design on Box 0 cloth, opens whole: the design is listed, '
      'and opening it says its cloth has gone', () async {
    final from = Shelf(memoryDb());
    final box = await from.makeBox();
    await from.addPiecesForTest(box, 40);
    await from.saveDesign(DesignInput(name: 'On the demo box', layout: 'contrast', mount: 'none', box: 0, seed: 1,
        started: null, firstSolve: null, grid: [for (var i = 0; i < 35; i++) GridCell('KF-${i % 5 + 1}', 0)]));
    final file = await exportBackup(from.db, testSideDb);
    final s = await studio(seeded: false);
    await s.c.importFile(file);
    await settle();
    expect((s.c.box, s.c.starting), (box, false), reason: 'the studio opens on her box from the file');
    final old = s.c.saved.singleWhere((d) => d.name == 'On the demo box');
    expect(s.c.usesGoneCloth(old.id), isTrue);
    expect(s.c.openSaved(old), isFalse);
    expect(s.c.note, s.c.words.canvasMissingCloth);
    expect(s.c.box, box, reason: 'and stays there');
  });
}
