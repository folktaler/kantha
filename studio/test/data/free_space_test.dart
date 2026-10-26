@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/prepare.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

const measured = Measured(lab: (l: 37.8, a: -6.3, b: -4.6), name: 'darkslategray', spread: 3.1, width: 100, height: 100);

/* A photo the size the studio stores: a noisy square, storedLongSide across, at storedJpegQuality. */
Uint8List storedPhoto(int seed) {
  final r = Random(seed);
  final im = img.Image(width: storedLongSide, height: storedLongSide);
  for (final p in im) {
    p..r = r.nextInt(256)..g = r.nextInt(256)..b = r.nextInt(256);
  }
  return img.encodeJpg(im, quality: storedJpegQuality);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late File file;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kantha_free_');
    file = File('${dir.path}/kantha.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<int> autoVacuum(KanthaDatabase db) async =>
      (await db.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>('auto_vacuum');

  Future<List<String>> addTwenty(Shelf shelf) async {
    final box = await shelf.makeBox();
    return [
      for (var i = 0; i < 20; i++)
        (await shelf.addCloth(box: box, photo: storedPhoto(i), measured: measured, fabric: 'Cotton', pieces: 1)).id,
    ];
  }

  test('a new database on a phone gives back the space of 20 removed cloths', () async {
    final db = KanthaDatabase(NativeDatabase(file), freesSpace: () => true);
    final shelf = Shelf(db);
    final ids = await addTwenty(shelf);
    expect(await autoVacuum(db), 1, reason: 'FULL');
    final full = file.lengthSync();
    for (final id in ids) {
      await shelf.removeCloth(id);
    }
    final after = file.lengthSync();
    await db.close();
    expect(full, greaterThan(20 * 50000));
    expect(after, lessThan(full ~/ 10));
  });

  test('a database made without it (before 20 Oct, IndexedDB, a backup) stays as it is: opened again with it, nothing '
      'is rewritten, her cloth is kept, and a removal leaves the file as large as it was', () async {
    final old = KanthaDatabase(NativeDatabase(file));
    final ids = await addTwenty(Shelf(old));
    expect(await autoVacuum(old), 0, reason: 'NONE, the default');
    await old.close();

    final db = KanthaDatabase(NativeDatabase(file), freesSpace: () => true);
    final shelf = Shelf(db);
    expect((await db.select(db.cloths).get()).map((c) => c.id), ids);
    expect(await autoVacuum(db), 0, reason: 'asked only when the file is first made');
    final full = file.lengthSync();
    for (final id in ids) {
      await shelf.removeCloth(id);
    }
    expect(file.lengthSync(), full);
    await db.close();
  });

  /* Every row of every table, photos and pictures byte for byte. */
  Future<Map<String, List<Map<String, Object?>>>> everything(KanthaDatabase db) async => {
        for (final t in ['boxes', 'cloths', 'designs', 'pictures', 'counters', 'settings'])
          t: [for (final r in await db.customSelect('SELECT * FROM $t ORDER BY rowid').get()) r.data],
      };
  Future<String> integrity(KanthaDatabase db) async =>
      (await db.customSelect('PRAGMA integrity_check').getSingle()).read<String>('integrity_check');

  /* A database as one made before 20 Oct holds it (auto_vacuum NONE): `photos` cloths in Box 1, a design on the first
     two with its picture, a setting; then every cloth but the first `keep` removed, leaving their pages empty. */
  Future<void> oldDatabase({int photos = 40, int keep = 4, Uint8List Function(int) photo = storedPhoto}) async {
    final db = KanthaDatabase(NativeDatabase(file));
    final shelf = Shelf(db);
    final box = await shelf.makeBox();
    final ids = [
      for (var i = 0; i < photos; i++)
        (await shelf.addCloth(box: box, photo: photo(i), measured: measured, fabric: 'Cotton', pieces: 1)).id,
    ];
    final saved = DateTime.utc(2026, 10, 19);
    await db.into(db.designs).insert(DesignsCompanion.insert(id: 'P-1', name: 'Chess', layout: 'contrast', mount: 'none',
        grid: '[{"id":"${ids[0]}","rot":0},{"id":"${ids[1]}","rot":0}]', saved: saved));
    await db.into(db.pictures).insert(PicturesCompanion.insert(id: const Value(1), design: const Value('P-1'), name: 'Chess',
        made: saved, saved: saved, png: storedPhoto(900), thumb: Uint8List.fromList([1, 2, 3])));
    await shelf.setSetting('safariBannerSeen', '2026-10-19');
    for (final id in ids.skip(keep)) {
      await shelf.removeCloth(id);
    }
    expect(await autoVacuum(db), 0);
    await db.close();
  }

  test('an old database on a phone or OPFS, most of its photos removed: Free up space is offered, and afterwards the file '
      'is smaller, auto_vacuum is FULL, integrity_check is ok, every box, cloth, design and picture is still there, it '
      'is not offered again, and a delete from then on shrinks the file', () async {
    await oldDatabase();
    final db = KanthaDatabase(NativeDatabase(file), freesSpace: () => true);
    final before = await db.space(), rows = await everything(db), size = file.lengthSync();
    expect(before.bytes, size, reason: 'page_count × page_size is the file');
    expect(before.mayFree, isTrue);
    expect(before.empty, greaterThan(size * 3 ~/ 4));

    final r = await db.freeSpace();
    expect(r.before, size);
    expect(r.after, file.lengthSync());
    expect(r.after, lessThan(size ~/ 4));
    expect(await autoVacuum(db), 1, reason: 'FULL');
    expect(await integrity(db), 'ok');
    expect(await everything(db), rows);
    final after = await db.space();
    expect((after.empty, after.mayFree), (0, false));

    await Shelf(db).removeCloth('C-4');
    expect(file.lengthSync(), lessThan(r.after - 50000), reason: 'the removed photo\'s room goes back at once');
    await db.close();

    final again = KanthaDatabase(NativeDatabase(file), freesSpace: () => true);
    expect(await autoVacuum(again), 1);
    expect((await again.select(again.cloths).get()).map((c) => c.id), ['C-1', 'C-2', 'C-3']);
    expect(await integrity(again), 'ok');
    await again.close();
  });

  test('on IndexedDB, memory or a backup (freesSpace false) the same database is never offered Free up space, and '
      'freeSpace refuses without touching the file', () async {
    await oldDatabase();
    final bytes = file.readAsBytesSync();
    final db = KanthaDatabase(NativeDatabase(file));
    final space = await db.space();
    expect(space.empty, greaterThan(space.bytes ~/ 2));
    expect(space.mayFree, isFalse);
    await expectLater(db.freeSpace(), throwsStateError);
    expect(await autoVacuum(db), 0);
    await db.close();
    expect(file.readAsBytesSync(), bytes);
  });

  test('Free up space is offered only when the empty room is at least a quarter of the file and at least 1 MB', () async {
    // 40 photos, 8 removed: well over 1 MB empty, but under a quarter of the file.
    await oldDatabase(keep: 32);
    var db = KanthaDatabase(NativeDatabase(file), freesSpace: () => true);
    var space = await db.space();
    expect(space.empty, greaterThan(1000000));
    expect(space.empty * 4, lessThan(space.bytes));
    expect(space.mayFree, isFalse);
    // Three more: over a quarter.
    for (final id in ['C-30', 'C-31', 'C-32']) {
      await Shelf(db).removeCloth(id);
    }
    space = await db.space();
    expect(space.empty * 4, greaterThanOrEqualTo(space.bytes));
    expect(space.mayFree, isTrue);
    await db.close();
    file.deleteSync();

    // Under 1 MB empty, though most of the file: 20 small photos, all removed.
    await oldDatabase(photos: 20, keep: 0, photo: (i) => img.encodeJpg(img.Image(width: 100, height: 100)
      ..clear(img.ColorRgb8(i * 10, 90, 60)), quality: storedJpegQuality));
    db = KanthaDatabase(NativeDatabase(file), freesSpace: () => true);
    space = await db.space();
    expect(space.empty, lessThan(1000000));
    expect(space.empty * 4, greaterThan(space.bytes));
    expect(space.mayFree, isFalse);
    await db.close();
  });

  test('a VACUUM that fails part-way (another connection reading, so it cannot write) leaves the file byte for byte as '
      'it was, auto_vacuum NONE, every row there and integrity_check ok; once that ends, it runs', () async {
    await oldDatabase();
    final bytes = file.readAsBytesSync();
    final db = KanthaDatabase(NativeDatabase(file), freesSpace: () => true);
    final rows = await everything(db);
    final reader = sqlite3.open(file.path);
    reader.execute('BEGIN');
    expect(reader.select('SELECT count(*) AS n FROM cloths').single['n'], 4);

    await expectLater(db.freeSpace(), throwsA(anything));
    expect(file.readAsBytesSync(), bytes);
    expect(await autoVacuum(db), 0);
    expect(await integrity(db), 'ok');
    expect(await everything(db), rows);
    expect((await db.space()).mayFree, isTrue, reason: 'still offered');

    reader.execute('COMMIT');
    reader.close();
    await db.freeSpace();
    expect(await autoVacuum(db), 1);
    expect(await everything(db), rows);
    await db.close();
  });
}
