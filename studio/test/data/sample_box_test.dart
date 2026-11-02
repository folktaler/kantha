@TestOn('vm')
library;

import 'dart:io';
import 'package:drift/drift.dart' show ApplyInterceptor, Value, QueryExecutor, QueryInterceptor, TransactionExecutor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show FlutterError, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/backup.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/numbers.dart';
import 'package:kantha_studio/data/sample_box.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/data/side_db_io.dart';
import 'package:kantha_studio/l10n/app_localizations.dart' show lookupL;
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/solver/compile.dart' show ObjectiveInput;
import 'package:kantha_studio/solver/fabrics.dart' show poolOf;
import 'package:kantha_studio/solver/geometry.dart' show BoardSize, Mount, cells;
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve_layout.dart' show Base, LayoutSolve;
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/shelf_feed.dart' show shelfNow;
import '../support/db.dart';
import '../support/files_fixture.dart' show testSideDb;
import '../solver/pattern_rules.dart' show sampleBox, samplePiecesHere;
import '../support/studio_fixture.dart';

final _names = [for (final s in sampleCloth) s.name];
final _today = [for (final s in sampleCloth) s.pieces];
const _total = 189;

final _todayByName = {for (final s in sampleCloth) s.name: s.pieces};

Future<List<int>> _pieces(Shelf shelf) async => [for (final c in await shelf.db.select(shelf.db.cloths).get()) c.pieces];
Future<Map<String, int>> _piecesByName(Shelf shelf) async =>
    {for (final c in await shelf.db.select(shelf.db.cloths).get()) c.name: c.pieces};

void main() {
  test('ten cloths: seven plain under the busy line, three prints above it, each a colour name of its own', () {
    final m = [for (final s in sampleCloth) measureBytes(File('assets/sample/${s.file}').readAsBytesSync())];
    expect([for (final x in m) busyOf(x.spread)], [false, false, false, false, false, false, false, true, true, true]);
    expect(m.map((x) => x.name).toSet().length, 10, reason: 'ten colour names');
  });

  test('a fresh install gets the Sample box once, with the 10 cloths, 12 of each but Purple at 34, Turmeric at 31 and White at 40, named as the owner named them', () async {
    final shelf = Shelf(memoryDb());
    await ensureSampleBox(shelf);
    await ensureSampleBox(shelf);
    final boxes = await shelf.db.select(shelf.db.boxes).get();
    expect(boxes.map((b) => b.name), ['sample']);
    final cloth = await shelf.db.select(shelf.db.cloths).get();
    expect(cloth.map((c) => c.name), _names);
    expect(cloth.every((c) => c.fabric == ''), isTrue);
    expect([for (final c in cloth) c.pieces], [12, 12, 34, 31, 12, 12, 40, 12, 12, 12]);
    expect(_today.fold(0, (a, b) => a + b), _total);
    expect(samplePiecesHere, _today, reason: 'pattern_rules.dart copies the counts');
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

  group('a Sample box made with 7 pieces of each cloth', () {
    // As one made before 1 November 2026: 7 of each, and no top-up marker.
    Future<Shelf> old() async {
      final shelf = Shelf(memoryDb());
      await ensureSampleBox(shelf);
      await shelf.db.update(shelf.db.cloths).write(const ClothsCompanion(pieces: Value(7)));
      await (shelf.db.delete(shelf.db.counters)..where((c) => c.name.equals('samplePieces'))).go();
      return shelf;
    }

    test('gets today\'s count of each cloth she has not changed, once; a cloth she changed stays as she left it', () async {
      final shelf = await old();
      final cloth = await shelf.db.select(shelf.db.cloths).get();
      await shelf.editCloth(cloth[0].id, fabric: '', pieces: 5);
      await shelf.editCloth(cloth[1].id, fabric: 'Cotton', pieces: 7);
      await topUpSample(shelf);
      final after = {for (final c in await shelf.db.select(shelf.db.cloths).get()) c.id: c.pieces};
      expect(after[cloth[0].id], 5);
      expect(after[cloth[1].id], 7);
      expect([for (final c in cloth.skip(2)) after[c.id]], _today.skip(2));
      // Once: a cloth set back to 7 later is hers, and is not topped up again.
      await shelf.editCloth(cloth[2].id, fabric: '', pieces: 7);
      await topUpSample(shelf);
      expect((await (shelf.db.select(shelf.db.cloths)..where((c) => c.id.equals(cloth[2].id))).getSingle()).pieces, 7);
    });

    test('in a backup imported later, gets today\'s counts on import', () async {
      final backup = await exportBackup((await old()).db, testSideDb);
      final shelf = Shelf(memoryDb());
      await ensureSampleBox(shelf);
      final solver = _PoolsSeen();
      final (:c, shelf: _) = await studio(on: shelf, seeded: false, solver: solver);
      final from = solver.solved.length;
      await c.importFile(backup);
      await pumpEventQueue();
      expect(await _piecesByName(shelf), _todayByName);
      expect(c.piecesIn(c.box!), _total, reason: 'the studio re-opened on today\'s counts');
      // Topped up before the studio re-opened: no arrangement was asked of the box at 7.
      expect(solver.solved.length, greaterThan(from));
      expect([for (final st in solver.solved.skip(from)) st.where((k) => k > 0).toSet()], everyElement(_today.toSet()));
    });

    test('in a backup from before 22 October, is topped up and swapped, and the board dealt again from the real cloth', () async {
      final drawn = Shelf(memoryDb());
      await _oldSample(drawn);
      await (drawn.db.delete(drawn.db.counters)..where((c) => c.name.equals('samplePieces'))).go();
      final backup = await exportBackup(drawn.db, testSideDb);
      final shelf = Shelf(memoryDb());
      await ensureSampleBox(shelf);
      final solver = _PoolsSeen();
      final (:c, shelf: _) = await studio(on: shelf, seeded: false, solver: solver);
      final from = solver.solved.length;
      await c.importFile(backup);
      await pumpEventQueue();
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.name), _names);
      expect(await _piecesByName(shelf), _todayByName);
      // Once swapped and topped up, the board was dealt again from the real cloth at today's counts.
      expect(solver.solved.length, greaterThan(from));
      expect(solver.solved.last.where((k) => k > 0).toSet(), _today.toSet());
    });

    test('in a backup from before 22 October, is not swapped when the studio could not re-open on it: no picture is '
        'drawn from this device\'s cloth, and the next open swaps it', () async {
      final shelf = Shelf(memoryDb());
      await _oldSample(shelf);
      final swatches = (await shelf.db.select(shelf.db.cloths).get()).toList();
      await _design(shelf, 'Swatches', [for (final x in swatches.take(5)) x.id]);
      final backup = await exportBackup(shelf.db, testSideDb);
      await shelf.db.update(shelf.db.cloths).write(const ClothsCompanion(l: Value(95), a: Value(0), b: Value(0)));
      final solver = _RefusesPool();
      final c = StudioController(shelf: shelf, solver: solver, words: lookupL(const Locale('en')), side: testSideDb);
      c.restock(await shelfNow(shelf));
      c.start();
      var drawn = 0;
      c.drawPicture = (d) async { drawn++; return (png: fixtureJpeg, thumb: fixtureJpeg); };
      final reported = <Object>[];
      final was = FlutterError.onError;
      FlutterError.onError = (d) => reported.add(d.exception);
      addTearDown(() => FlutterError.onError = was);
      solver.refuse = true;
      await c.importFile(backup);
      await pumpEventQueue();
      expect(drawn, 0);
      expect(await shelf.db.select(shelf.db.pictures).get(), isEmpty);
      expect(reported, [isA<StateError>()], reason: 'the re-open failed and was reported');
      expect(await shelf.swatchesToReplace(drawnSwatches), isNotEmpty, reason: 'left for the next open');
    });

    test('in a backup from before 22 October, has its designs pictured in the backup\'s cloth, though this device has '
        'cloth of the same ids', () async {
      // Device A made the backup, then its cloth changed colour: the same ids, now in other colours.
      final shelf = Shelf(memoryDb());
      await _oldSample(shelf);
      final swatches = (await shelf.db.select(shelf.db.cloths).get()).toList();
      await _design(shelf, 'Swatches', [for (final x in swatches.take(5)) x.id]);
      final backup = await exportBackup(shelf.db, testSideDb);
      await shelf.db.update(shelf.db.cloths).write(const ClothsCompanion(l: Value(95), a: Value(0), b: Value(0)));
      // A studio whose feed has not caught up with the import (none here): what it holds is read only when it asks.
      final c = StudioController(shelf: shelf, solver: QuickSolver(), words: lookupL(const Locale('en')), side: testSideDb);
      c.restock(await shelfNow(shelf));
      c.start();
      expect(c.cloth.where((x) => x.id == swatches.first.id).single.lab.l, closeTo(95, 1e-9));
      final seen = <({double l, double a, double b})>[];
      c.drawPicture = (d) async {
        for (final id in d.grid.toSet()) {
          seen.add(c.cloth.where((x) => x.id == id).single.lab);
        }
        return (png: fixtureJpeg, thumb: fixtureJpeg);
      };
      await c.importFile(backup);
      await pumpEventQueue();
      expect(seen, hasLength(5), reason: 'the design was pictured before its swatches went');
      expect(seen.toSet(), {for (final x in swatches.take(5)) (l: x.l, a: x.a, b: x.b)}, reason: "the backup's colours");
      final pictures = await shelf.db.select(shelf.db.pictures).get();
      expect({for (final p in pictures) p.name: p.design}, {'Swatches': null}, reason: 'Picture only');
      expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.name), _names);
    });

    test('emptied or deleted, stays as she left it', () async {
      final shelf = await old();
      final box = (await shelf.db.select(shelf.db.boxes).get()).single;
      final ids = await shelf.clothIn(box.id);
      await shelf.deleteBox(box.id, cloth: ids);
      await topUpSample(shelf);
      expect(await shelf.db.select(shelf.db.cloths).get(), isEmpty);
      expect(await shelf.counterAt('samplePieces'), sampleTopUpDone);
    });

    test('a Sample box made now needs no top-up', () async {
      final shelf = Shelf(memoryDb());
      await ensureSampleBox(shelf);
      expect(await shelf.counterAt('samplePieces'), sampleTopUpDone);
    });
  });

  group('a Sample box made with 12 pieces of each cloth', () {
    // As one made, or topped up, between 1 and 2 November 2026: 12 of each, and the top-up marker at 2.
    Future<Shelf> old() async {
      final shelf = Shelf(memoryDb());
      await ensureSampleBox(shelf);
      await shelf.db.update(shelf.db.cloths).write(const ClothsCompanion(pieces: Value(12)));
      await shelf.db.into(shelf.db.counters).insertOnConflictUpdate(CountersCompanion.insert(name: 'samplePieces', next: 2));
      return shelf;
    }

    test('gets Purple at 34, Turmeric at 31 and White at 40 if she has not changed them, once; the rest, and a cloth she '
        'changed, stay', () async {
      final shelf = await old();
      final cloth = await shelf.db.select(shelf.db.cloths).get();
      await shelf.editCloth(cloth[0].id, fabric: '', pieces: 7);
      await shelf.editCloth(cloth[6].id, fabric: 'Cotton', pieces: 12);
      await topUpSample(shelf);
      expect(await _pieces(shelf), [7, 12, 34, 31, 12, 12, 12, 12, 12, 12], reason: '7 in a box topped up to 12 is hers');
      expect(await shelf.counterAt('samplePieces'), sampleTopUpDone);
      await shelf.editCloth(cloth[2].id, fabric: '', pieces: 12);
      await topUpSample(shelf);
      expect((await (shelf.db.select(shelf.db.cloths)..where((c) => c.id.equals(cloth[2].id))).getSingle()).pieces, 12);
    });

    test('in a backup imported later, gets today\'s counts on import', () async {
      final backup = await exportBackup((await old()).db, testSideDb);
      final shelf = Shelf(memoryDb());
      await ensureSampleBox(shelf);
      final (:c, shelf: _) = await studio(on: shelf, seeded: false);
      await c.importFile(backup);
      await pumpEventQueue();
      expect(await _piecesByName(shelf), _todayByName);
      expect(c.piecesIn(c.box!), _total);
    });

    test('partly emptied, the cloth left gets today\'s counts; deleted, stays deleted', () async {
      final shelf = await old();
      final box = (await shelf.db.select(shelf.db.boxes).get()).single;
      final ids = await shelf.clothIn(box.id);
      for (final id in ids.take(4)) { await shelf.removeCloth(id); }
      await topUpSample(shelf);
      expect(await _pieces(shelf), _today.skip(4));
      final emptied = await old();
      final b = (await emptied.db.select(emptied.db.boxes).get()).single;
      await emptied.deleteBox(b.id, cloth: await emptied.clothIn(b.id));
      await topUpSample(emptied);
      expect(await emptied.db.select(emptied.db.cloths).get(), isEmpty);
      expect(await emptied.counterAt('samplePieces'), sampleTopUpDone);
    });
  });

  test('the top-up knows every count the Sample box held before today\'s', () {
    expect(samplePiecesBefore.length + 1, sampleTopUpDone);
    expect(samplePiecesBefore.last, samplePieces);
  });

  test('every pattern fills from the Sample box at the start size', () async {
    final shelf = Shelf(memoryDb());
    await ensureSampleBox(shelf);
    final c = (await studio(on: shelf, seeded: false)).c;
    expect(c.box, isNotNull);
    expect(c.piecesIn(c.box!), _total);
    for (final k in LayoutKey.values) {
      // Chain's links are one cloth, and Diamond's light rings one family (owner, 1 November 2026).
      expect(c.feasible[k]?.fills, isTrue, reason: '${k.name} from the Sample box');
    }
    expect(c.starting, isFalse);
  });

  test('every pattern fills a board 12 wide and 10 tall from the Sample box (owner, 2 November 2026)', () {
    final p = poolOf(sampleBox().fabrics);
    for (final k in LayoutKey.values) {
      final m = modelFor(k, ObjectiveInput(pool: p.pool, edge: p.edge, members: [for (var i = 0; i < 10; i++) i],
          mount: Mount.none, stock: p.stock, size: (rows: 10, cols: 12)));
      expect(m.fills, isTrue, reason: '${k.name} at 12 × 10: ${m.why}');
    }
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
      expect(cloth.where((x) => x.id != own.id).map((x) => x.pieces).toList(), _today);
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

/* The pool, as stock per cloth, that each arrangement was asked of, at any board size. */
/* A solver that, once `refuse` is set, refuses the pool it is given: the studio cannot re-open. */
class _RefusesPool extends QuickSolver {
  var refuse = false;
  @override
  void setPool(Base base) { if (refuse) throw StateError('the solver refused the pool'); }
}

class _PoolsSeen extends QuickSolver {
  var _stock = const <int>[];
  final solved = <List<int>>[];
  @override
  void setPool(Base base) => _stock = List.of(base.stock);
  @override
  Future<LayoutSolve> solve(BoardSize? size, LayoutKey layout, List<int> members, Mount mount, int seed,
      {void Function(int done, int of)? onStep}) {
    solved.add(_stock);
    return super.solve(size, layout, members, mount, seed, onStep: onStep);
  }
}
