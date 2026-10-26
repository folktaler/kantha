@TestOn('vm')
library;

import 'dart:io';
import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor, TransactionExecutor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/backup.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/numbers.dart';
import 'package:kantha_studio/data/sample_box.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/data/side_db_io.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/solver/geometry.dart' show cells;
import 'package:kantha_studio/solver/layouts.dart';
import '../support/db.dart';
import '../support/files_fixture.dart' show testSideDb;
import '../support/studio_fixture.dart';

final _names = [for (final s in sampleCloth) s.name];

void main() {
  test('ten cloths: seven plain under the busy line, three prints above it, each a colour name of its own', () {
    final m = [for (final s in sampleCloth) measureBytes(File('assets/sample/${s.file}').readAsBytesSync())];
    expect([for (final x in m) busyOf(x.spread)], [false, false, false, false, false, false, false, true, true, true]);
    expect(m.map((x) => x.name).toSet().length, 10, reason: 'ten colour names');
  });

  test('a fresh install gets the Sample box once, with the 10 cloths of 7, named as the owner named them', () async {
    final shelf = Shelf(memoryDb());
    await ensureSampleBox(shelf);
    await ensureSampleBox(shelf);
    final boxes = await shelf.db.select(shelf.db.boxes).get();
    expect(boxes.map((b) => b.name), ['sample']);
    final cloth = await shelf.db.select(shelf.db.cloths).get();
    expect(cloth.map((c) => c.name), _names);
    expect(cloth.every((c) => c.pieces == 7 && c.fabric == ''), isTrue);
    expect(await shelf.swatchesToReplace(drawnSwatches), isNull, reason: 'a Sample box made now needs no swap');
  });

  test('a database with any box gets no Sample box; a deleted Sample box does not come back', () async {
    final shelf = Shelf(memoryDb());
    await shelf.makeBox();
    await ensureSampleBox(shelf);
    expect((await shelf.db.select(shelf.db.boxes).get()).length, 1);
    final fresh = Shelf(memoryDb());
    await ensureSampleBox(fresh);
    final sample = (await fresh.db.select(fresh.db.boxes).get()).single.id;
    for (final c in await fresh.db.select(fresh.db.cloths).get()) {
      await fresh.removeCloth(c.id);
    }
    await fresh.deleteBox(sample, cloth: const {});
    await fresh.makeBox();
    await ensureSampleBox(fresh);
    expect((await fresh.db.select(fresh.db.boxes).get()).map((b) => b.name), [null]);
  });

  test('a Sample box deleted as her only box does not come back on the next launch; a fresh database gets one', () async {
    final shelf = Shelf(memoryDb());
    await ensureSampleBox(shelf);
    expect((await shelf.db.select(shelf.db.boxes).get()).length, 1, reason: 'a fresh database gets the Sample box');
    final sample = (await shelf.db.select(shelf.db.boxes).get()).single.id;
    for (final c in await shelf.db.select(shelf.db.cloths).get()) {
      await shelf.removeCloth(c.id);
    }
    await shelf.deleteBox(sample, cloth: const {});
    await ensureSampleBox(shelf);
    expect(await shelf.db.select(shelf.db.boxes).get(), isEmpty);
    expect(await shelf.db.select(shelf.db.cloths).get(), isEmpty);
  });

  test('the Sample box is made in exactly one transaction, none nested inside it', () async {
    final watch = _Writes();
    await makeSampleBox(Shelf(_watched(watch)));
    expect(watch.transactions, 1);
    expect(watch.clothInserts, 10);
  });

  test('a first launch that fails on the fifth cloth leaves no box and no cloth, and the next launch makes it whole', () async {
    final watch = _Writes()..failOnCloth = 5;
    final shelf = Shelf(_watched(watch));
    await expectLater(ensureSampleBox(shelf), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'storage')));
    expect(await shelf.db.select(shelf.db.boxes).get(), isEmpty);
    expect(await shelf.db.select(shelf.db.cloths).get(), isEmpty);
    watch.failOnCloth = null;
    await ensureSampleBox(shelf);
    expect((await shelf.db.select(shelf.db.boxes).get()).map((b) => b.name), ['sample']);
    expect((await shelf.db.select(shelf.db.cloths).get()).length, 10);
  });

  test('a backup that held boxes, imported into a fresh database, gets no Sample box', () async {
    final shelf = Shelf(memoryDb());
    await importBackup(File('test/fixtures/backup/kantha-backup-v1.kantha').readAsBytesSync(), shelf,
        IoSideDb(Directory.systemTemp));
    final before = {for (final b in await shelf.db.select(shelf.db.boxes).get()) b.id: b.name};
    expect(before, {1: null, 2: null});
    await ensureSampleBox(shelf);
    expect({for (final b in await shelf.db.select(shelf.db.boxes).get()) b.id: b.name}, before);
  });

  test('every pattern fills from the Sample box', () async {
    final shelf = Shelf(memoryDb());
    await ensureSampleBox(shelf);
    final c = (await studio(on: shelf, seeded: false)).c;
    expect(c.box, isNotNull);
    expect(c.piecesIn(c.box!), 10 * 7);
    for (final k in LayoutKey.values) {
      expect(c.feasible[k]?.fills, isTrue, reason: '${k.name} fills from the Sample box');
    }
    expect(c.starting, isFalse);
  });

  group('a Sample box made before 22 Oct', () {
    test('is swapped: the swatches and their designs go, her own cloth and the box stay, the designs stay as pictures '
        'made first', () async {
      final shelf = Shelf(memoryDb());
      final box = await _oldSample(shelf);
      final swatches = await _ids(shelf);
      final own = await shelf.addCloth(box: box, photo: fixtureJpeg, measured: measuredFor(), fabric: '', pieces: 3);
      final fromSwatches = await _design(shelf, 'Swatches', swatches.take(5).toList());
      final mixed = await _design(shelf, 'Mixed', [own.id, swatches.first]);
      final hers = await _design(shelf, 'Hers', [own.id]);
      final (:c, shelf: _) = await studio(on: shelf, seeded: false);
      final drawn = <String>[];
      c.drawPicture = (d) async {
        drawn.add(d.id);
        expect(await shelf.clothById(swatches.first), isNotNull, reason: 'each picture is made while its cloth is there');
        return (png: fixtureJpeg, thumb: fixtureJpeg);
      };

      await c.replaceDrawnSample();

      expect(drawn.toSet(), {fromSwatches, mixed});
      expect((await shelf.db.select(shelf.db.boxes).get()).map((b) => (b.id, b.name)), [(box, 'sample')]);
      final cloth = await shelf.db.select(shelf.db.cloths).get();
      expect(cloth.map((x) => x.name), [own.name, ..._names]);
      expect(cloth.every((x) => x.box == box), isTrue);
      expect(cloth.where((x) => x.id != own.id).every((x) => x.pieces == 7), isTrue);
      expect((await shelf.db.select(shelf.db.designs).get()).map((d) => d.id), [hers]);
      final pictures = await shelf.db.select(shelf.db.pictures).get();
      expect({for (final p in pictures) p.name: p.design}, {'Swatches': null, 'Mixed': null}, reason: 'Picture only');
      expect(await shelf.swatchesToReplace(drawnSwatches), isNull);
    });

    test('is not swapped while a design made from it has no picture of its latest save: nothing changes', () async {
      final shelf = Shelf(memoryDb());
      await _oldSample(shelf);
      final before = await _ids(shelf);
      await _design(shelf, 'Unpictured', before.take(3).toList());
      await expectLater(replaceDrawnSample(shelf), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'noPicture')));
      expect(await _ids(shelf), before);
      expect((await shelf.db.select(shelf.db.designs).get()).length, 1);
      expect(await shelf.swatchesToReplace(drawnSwatches), isNotNull, reason: 'tried again on the next open');
    });

    test('partly emptied, is swapped in full: the swatches left go and all 10 cloths go in', () async {
      final shelf = Shelf(memoryDb());
      final box = await _oldSample(shelf);
      for (final id in (await _ids(shelf)).take(5)) {
        await shelf.removeCloth(id);
      }
      await replaceDrawnSample(shelf);
      final cloth = await shelf.db.select(shelf.db.cloths).get();
      expect(cloth.map((x) => x.name), _names);
      expect(cloth.every((x) => x.box == box), isTrue);
    });

    test('a swatch she re-cropped is swapped like the others', () async {
      final shelf = Shelf(memoryDb());
      await _oldSample(shelf);
      final madder = (await shelf.db.select(shelf.db.cloths).get()).firstWhere((x) => x.name == 'Madder');
      final recropped = await shelf.recrop(madder.id, fixtureJpeg, measuredFor(l: 40));
      expect((recropped.name, recropped.version), ('Madder', 2));
      await replaceDrawnSample(shelf);
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.name), _names);
    });

    test('emptied, stays empty; her own cloth in it stays and nothing goes in', () async {
      final shelf = Shelf(memoryDb());
      final box = await _oldSample(shelf);
      for (final id in await _ids(shelf)) {
        await shelf.removeCloth(id);
      }
      await replaceDrawnSample(shelf);
      expect(await shelf.db.select(shelf.db.cloths).get(), isEmpty);
      final own = await shelf.addCloth(box: box, photo: fixtureJpeg, measured: measuredFor(), fabric: '', pieces: 3);
      await replaceDrawnSample(shelf);
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.id), [own.id]);
      expect(await shelf.swatchesToReplace(drawnSwatches), isNull);
    });

    test('emptied and then filled with her own cloth, stays as it is', () async {
      final shelf = Shelf(memoryDb());
      final box = await _oldSample(shelf);
      for (final id in await _ids(shelf)) {
        await shelf.removeCloth(id);
      }
      final own = await shelf.addCloth(box: box, photo: fixtureJpeg, measured: measuredFor(), fabric: '', pieces: 3);
      await replaceDrawnSample(shelf);
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.id), [own.id]);
    });

    test('deleted, stays deleted', () async {
      final shelf = Shelf(memoryDb());
      final box = await _oldSample(shelf);
      final mine = await shelf.makeBox();
      await shelf.deleteBox(box, cloth: await shelf.clothIn(box));
      await replaceDrawnSample(shelf);
      expect((await shelf.db.select(shelf.db.boxes).get()).map((b) => b.id), [mine]);
      expect(await shelf.db.select(shelf.db.cloths).get(), isEmpty);
      expect(await shelf.swatchesToReplace(drawnSwatches), isNull);
    });

    test('is swapped once only: again, and after a backup made since is imported, nothing changes', () async {
      final shelf = Shelf(memoryDb());
      await _oldSample(shelf);
      await replaceDrawnSample(shelf);
      final after = await _ids(shelf);
      await replaceDrawnSample(shelf);
      expect(await _ids(shelf), after);
      await importBackup(await exportBackup(shelf.db, testSideDb), shelf, testSideDb);
      await replaceDrawnSample(shelf);
      expect(await _ids(shelf), after);
    });

    test('in an old backup imported later, is swapped on import, once', () async {
      final old = Shelf(memoryDb());
      await _oldSample(old);
      final backup = await exportBackup(old.db, testSideDb);
      final shelf = Shelf(memoryDb());
      await ensureSampleBox(shelf);
      final (:c, shelf: _) = await studio(on: shelf, seeded: false);
      await c.importFile(backup);
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.name), _names);
      final after = await _ids(shelf);
      await c.replaceDrawnSample();
      expect(await _ids(shelf), after);
    });

    test('another tab imports an old backup after this one read no swatches: its swap changes nothing, and the next '
        'open swaps the backup\'s Sample box', () async {
      final old = Shelf(memoryDb());
      await _oldSample(old);
      final backup = await exportBackup(old.db, testSideDb);
      final shelf = Shelf(memoryDb());
      await shelf.makeBox();
      expect(await shelf.swatchesToReplace(drawnSwatches), isEmpty, reason: 'this tab reads no swatch, so no cloth is fetched');
      await importBackup(backup, shelf, testSideDb); // the other tab
      final imported = await _ids(shelf);
      await shelf.replaceSample(drawnSwatches, const []); // this tab's swap, with the cloth its read called for
      expect(await _ids(shelf), imported, reason: 'the backup\'s swatches stay');
      expect(await shelf.swatchesToReplace(drawnSwatches), imported, reason: 'no marker: the next open swaps them');
      await replaceDrawnSample(shelf);
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.name), _names);
    });

    test('a swap cut off on the fourth new cloth leaves the old box whole, and the next open swaps it', () async {
      final watch = _Writes();
      final shelf = Shelf(_watched(watch));
      await _oldSample(shelf);
      final before = await _ids(shelf);
      watch
        ..clothInserts = 0
        ..failOnCloth = 4;
      await expectLater(replaceDrawnSample(shelf), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'storage')));
      expect(await _ids(shelf), before);
      expect(await shelf.swatchesToReplace(drawnSwatches), before);
      watch.failOnCloth = null;
      await replaceDrawnSample(shelf);
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.name), _names);
    });
  });
}

/* A Sample box as one made before 22 Oct holds it: the eight drawn swatches by name, 7 pieces each, and no swap
   marker. Returns the box. */
Future<int> _oldSample(Shelf shelf) async {
  final photo = File('assets/sample/white.jpg').readAsBytesSync();
  final box = await shelf.addBoxWithCloth(sample: true, cloth: [
    for (final (i, name) in drawnSwatches.indexed)
      (name: name, photo: photo, measured: measuredFor(l: 20.0 + 9 * i, a: 30, b: 10.0 * i), pieces: 7),
  ]);
  await (shelf.db.delete(shelf.db.counters)..where((c) => c.name.equals('sample'))).go();
  return box;
}

Future<Set<String>> _ids(Shelf shelf) async => {for (final c in await shelf.db.select(shelf.db.cloths).get()) c.id};

/* A saved design whose 35 squares use `cloth` in turn. */
Future<String> _design(Shelf shelf, String name, List<String> cloth) async => (await shelf.saveDesign(DesignInput(
    name: name, layout: 'contrast', mount: 'none', box: null, seed: 1, started: null, firstSolve: null,
    grid: [for (var i = 0; i < cells; i++) GridCell(cloth[i % cloth.length], 0)]))).design.id;

/* A database in memory whose writes are watched: how many transactions open (a nested one included, as drift's
   interceptor sees it), how many cloth rows go in, and, when `failOnCloth` is set, that cloth's insert refused,
   as a device turns a write down halfway through. */
KanthaDatabase _watched(_Writes watch) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = KanthaDatabase(NativeDatabase.memory().interceptWith(watch));
  addTearDown(db.close);
  return db;
}

class _Writes extends QueryInterceptor {
  var transactions = 0, clothInserts = 0;
  int? failOnCloth;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    transactions++;
    return super.beginTransaction(parent);
  }

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) {
    if (statement.contains('INTO "cloths"') && ++clothInserts == failOnCloth) {
      return Future.error(Exception('the device refused cloth $clothInserts'));
    }
    return super.runInsert(executor, statement, args);
  }
}
