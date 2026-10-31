@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show OrderingTerm, OpeningDetails, QueryExecutor, QueryExecutorUser, QueryInterceptor, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/backup.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/data/side_db.dart';
import 'package:kantha_studio/data/side_db_io.dart';
import 'package:kantha_studio/platform/deferred.dart';
import 'package:kantha_studio/studio/shelf_feed.dart' show ClothPhoto, shelfNow;
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import '../support/db.dart';
import 'shelf_test.dart' show design, measured;

Uint8List photo(int seed) => Uint8List.fromList(List.generate(4096, (i) => (i * seed) & 255));

void main() {
  final side = IoSideDb(Directory.systemTemp);

  test('ten cloth added in one millisecond come back C-1 … C-10 after an import', () async {
    final a = Shelf(memoryDb());
    final box = await a.makeBox();
    for (var i = 0; i < 10; i++) { await a.addCloth(box: box, photo: photo(i + 1), measured: measured, fabric: '', pieces: 1); }
    await a.db.customStatement("UPDATE cloths SET added = '2026-10-26T07:16:40.123Z'");
    final b = Shelf(memoryDb());
    await importBackup(await exportBackup(a.db, side), b, side);
    expect((await b.watchCloth().first).map((c) => c.id), [for (var i = 1; i <= 10; i++) 'C-$i']);
  });

  test('export, then import into an empty device: every box, photo, design and number comes back', () async {
    final a = Shelf(memoryDb());
    final box1 = await a.makeBox(), box2 = await a.makeBox();
    final c1 = await a.addCloth(box: box1, photo: photo(3), measured: measured, fabric: 'Cotton', pieces: 4);
    await a.addCloth(box: box2, photo: photo(5), measured: measured, fabric: 'Linen', pieces: 2);
    await a.removeCloth((await a.addCloth(box: box2, photo: photo(7), measured: measured, fabric: 'Other', pieces: 1)).id);
    await a.saveDesign(design(c1.id));
    await a.saveDesign(design('KF-4', name: 'On the demo cloth'));

    final file = await exportBackup(a.db, side, now: DateTime(2026, 10, 6));
    final b = Shelf(memoryDb());
    await importBackup(file, b, side);

    expect((await b.watchBoxes().first).map((x) => x.id), [1, 2]);
    final cloth = await clothRows(b);
    expect(cloth.map((x) => (x.id, x.pieces, x.fabric)), [('C-1', 4, 'Cotton'), ('C-2', 2, 'Linen')]);
    expect(cloth.first.photo, photo(3));
    expect((await b.watchDesigns().first).map((x) => x.name).toSet(), {'Zinnia', 'On the demo cloth'});
    // Every row, every column — photos byte for byte, and each design's grid, seed, times — as it left, but for the
    // photos' numbers: each is dealt anew, past every one either device has dealt (3 there).
    expect([for (final x in cloth) x.copyWith(photoNumber: 0)], [for (final x in await clothRows(a)) x.copyWith(photoNumber: 0)]);
    expect(cloth.map((x) => x.photoNumber), [4, 5]);
    expect(cloth.map((x) => x.photo), [photo(3), photo(5)]);
    expect(await b.db.select(b.db.designs).get(), await a.db.select(a.db.designs).get());
    expect(await b.db.select(b.db.boxes).get(), await a.db.select(a.db.boxes).get());
    expect({for (final r in await b.db.select(b.db.counters).get()) r.name: r.next},
        {for (final r in await a.db.select(a.db.counters).get()) r.name: r.next, 'photo': 6});
    expect((await b.addCloth(box: 1, photo: photo(9), measured: measured, fabric: 'Cotton', pieces: 1)).id, 'C-4',
        reason: 'the id of the removed C-3 is never dealt again');
    expect(backupFileName(DateTime(2026, 10, 6)), 'kantha-backup-2026-10-06.kantha');

    final kept = File('test/fixtures/backup/kantha-backup-v1.kantha');
    if (!kept.existsSync()) { kept.createSync(recursive: true); kept.writeAsBytesSync(file); }
  });

  test("when the backup's own code will not load, even asked again, the file is not called a non-backup, and nothing "
      'changes', () async {
    final a = Shelf(memoryDb());
    await a.makeBox();
    final file = await exportBackup(a.db, side);
    final b = Shelf(memoryDb());
    final box = await b.makeBox();
    var asked = 0;
    final errors = <FlutterErrorDetails>[];
    final was = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = was);
    await expectLater(importBackup(file, b, side, load: () => loadTwice(() async {
      asked++;
      throw Exception('offline');
    })), throwsA(isA<BackupError>().having((e) => e.key, 'key', 'notLoaded')));
    expect(asked, 2, reason: 'asked once more before giving up');
    expect(errors, hasLength(1), reason: 'reported');
    expect((await b.watchBoxes().first).map((x) => x.id), [box]);
  });

  test("when the backup's own code will not load, a backup is not made: notLoaded, and nothing is copied first", () async {
    final a = Shelf(memoryDb());
    await a.makeBox();
    var made = 0;
    final errors = <FlutterErrorDetails>[];
    final was = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = was);
    await expectLater(exportBackup(a.db, _Counting(side, () => made++), load: () => loadTwice(() async {
      throw Exception('offline');
    })), throwsA(isA<BackupError>().having((e) => e.key, 'key', 'notLoaded')));
    expect(made, 0, reason: 'no side database made before the code loaded');
    expect(errors, hasLength(1), reason: 'reported');
  });

  test("opening a backup made before 20 Oct (auto_vacuum NONE) rewrites nothing in the backup's own database", () async {
    final a = Shelf(memoryDb());
    await a.addCloth(box: await a.makeBox(), photo: photo(3), measured: measured, fabric: 'Cotton', pieces: 1);
    final made = ZipDecoder().decodeBytes(await exportBackup(a.db, side));
    final dir = Directory.systemTemp.createTempSync('kantha_old_backup_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final old = File('${dir.path}/old.sqlite')..writeAsBytesSync(made.findFile('kantha.sqlite')!.readBytes()!);
    sqlite3.open(old.path)
      ..execute('PRAGMA auto_vacuum = NONE')
      ..execute('VACUUM')
      ..close();
    final zip = ZipEncoder().encodeBytes(Archive()
      ..addFile(made.findFile('manifest.json')!)
      ..addFile(ArchiveFile.bytes('kantha.sqlite', old.readAsBytesSync())));
    final watched = _Watched(side);
    final b = Shelf(memoryDb());
    await importBackup(zip, b, watched);
    expect((await clothRows(b)).single.photo, photo(3));
    expect(watched.statements.where((s) => s.contains('VACUUM') || s.contains('auto_vacuum')), isEmpty);
  });

  test("a backup's own database is made without auto_vacuum, even from a device whose database has it", () async {
    final a = Shelf(KanthaDatabase(NativeDatabase.memory(), freesSpace: () => true));
    await a.addCloth(box: await a.makeBox(), photo: photo(3), measured: measured, fabric: 'Cotton', pieces: 1);
    expect((await a.db.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>('auto_vacuum'), 1);
    final made = ZipDecoder().decodeBytes(await exportBackup(a.db, side));
    final dir = Directory.systemTemp.createTempSync('kantha_backup_vacuum_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/b.sqlite')..writeAsBytesSync(made.findFile('kantha.sqlite')!.readBytes()!);
    final opened = sqlite3.open(f.path);
    expect(opened.select('PRAGMA auto_vacuum').single.values.single, 0);
    opened.close();
  });

  test('a deferred load that fails once is asked for again, and succeeds', () async {
    var asked = 0;
    await loadTwice(() async {
      if (++asked == 1) throw Exception('a moment offline');
    });
    expect(asked, 2);
  });

  test('a backup is one zip: its manifest and the database', () async {
    final a = Shelf(memoryDb());
    await a.makeBox();
    final zip = ZipDecoder().decodeBytes(await exportBackup(a.db, side));
    expect(zip.files.map((f) => f.name).toSet(), {'manifest.json', 'kantha.sqlite'});
    final manifest = jsonDecode(utf8.decode(zip.findFile('manifest.json')!.readBytes()!));
    expect((manifest['app'], manifest['kind'], manifest['format'], manifest['schema']), ('kantha', 'backup', 1, 5));
  });

  test('importing replaces, and leaves what is not in the file gone', () async {
    final a = Shelf(memoryDb());
    await a.makeBox();
    final file = await exportBackup(a.db, side);
    final b = Shelf(memoryDb());
    await b.makeBox(); await b.makeBox(); await b.makeBox();
    await importBackup(file, b, side);
    expect((await b.watchBoxes().first).map((x) => x.id), [1]);
  });

  Future<void> refused(Uint8List file, String key) async {
    final b = Shelf(memoryDb());
    await b.makeBox();
    await expectLater(importBackup(file, b, side), throwsA(isA<BackupError>().having((e) => e.key, 'key', key)));
    expect((await b.watchBoxes().first).map((x) => x.id), [1], reason: 'nothing was changed');
  }

  Uint8List zipOf(Map<String, List<int>> files) {
    final a = Archive();
    files.forEach((name, bytes) => a.addFile(ArchiveFile.bytes(name, bytes)));
    return ZipEncoder().encodeBytes(a);
  }

  test('a file that is not a backup is refused, and nothing changes', () async {
    await refused(Uint8List.fromList(utf8.encode('hello')), 'notBackup');
    await refused(zipOf({'notes.txt': utf8.encode('x')}), 'notBackup');
    await refused(zipOf({'manifest.json': utf8.encode('{"app":"other","kind":"backup","format":1,"schema":1}'), 'kantha.sqlite': [1, 2]}), 'notBackup');
    await refused(zipOf({'manifest.json': utf8.encode('{"app":"kantha","kind":"backup","format":1,"schema":1}'), 'kantha.sqlite': utf8.encode('not sqlite')}), 'notBackup');
  });

  test('a backup from a newer app is refused, and nothing changes', () async {
    await refused(zipOf({'manifest.json': utf8.encode('{"app":"kantha","kind":"backup","format":2,"schema":1}'), 'kantha.sqlite': [0]}), 'tooNew');
    await refused(zipOf({'manifest.json': utf8.encode('{"app":"kantha","kind":"backup","format":1,"schema":99}'), 'kantha.sqlite': [0]}), 'tooNew');
  });

  test('the kept schema-1 backup still opens, with both its designs', () async {
    final b = Shelf(memoryDb());
    await importBackup(File('test/fixtures/backup/kantha-backup-v1.kantha').readAsBytesSync(), b, side);
    expect(await b.watchBoxes().first, isNotEmpty);
    expect((await b.watchDesigns().first).map((x) => x.name).toSet(), {'Zinnia', 'On the demo cloth'});
  });

  test('the kept schema-1 backup comes up to schema 2: its boxes numbered 1 and 2, the next made is 3', () async {
    final shelf = Shelf(memoryDb());
    await importBackup(File('test/fixtures/backup/kantha-backup-v1.kantha').readAsBytesSync(), shelf, side);
    final rows = {for (final r in await shelf.db.select(shelf.db.boxes).get()) r.id: r.number};
    expect(rows, {1: 1, 2: 2});
    expect((await shelf.db.select(shelf.db.boxes).get()).every((r) => r.name == null), isTrue);
    final next = await shelf.makeBox();
    expect(rows.containsKey(next), isFalse);
    final made = await (shelf.db.select(shelf.db.boxes)..where((b) => b.id.equals(next))).getSingle();
    expect(made.number, 3);
  });

  test('an upgrade to schema 2 cut off part-way leaves the schema-1 database whole, and the next open finishes it', () async {
    final zip = ZipDecoder().decodeBytes(File('test/fixtures/backup/kantha-backup-v1.kantha').readAsBytesSync());
    final dir = Directory.systemTemp.createTempSync('kantha-upgrade-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite')..writeAsBytesSync(zip.findFile('kantha.sqlite')!.readBytes()!);
    // The upgrade fails at its last step, the counter, after both columns are added and the boxes numbered.
    sqlite3.open(file.path)
      ..execute("CREATE TRIGGER cut BEFORE INSERT ON counters WHEN NEW.name = 'boxNumber' BEGIN SELECT RAISE(ABORT, 'cut'); END")
      ..close();
    final cut = KanthaDatabase(NativeDatabase(file));
    await expectLater(cut.select(cut.boxes).get(), throwsA(anything));
    await cut.close();
    final raw = sqlite3.open(file.path);
    expect(raw.select('PRAGMA user_version').single.values.single, 1);
    expect(raw.select('PRAGMA table_info(boxes)').map((r) => r['name']), ['id', 'made'], reason: 'the added columns were undone');
    raw..execute('DROP TRIGGER cut')..close();
    final again = KanthaDatabase(NativeDatabase(file));
    addTearDown(again.close);
    expect({for (final r in await again.select(again.boxes).get()) r.id: r.number}, {1: 1, 2: 2});
  });

  /* kantha-backup-v2.kantha was made by the studio at cbe4a13 (schema 2): one box, C-1, and C-2 re-cropped once. */
  test("a schema-2 database on this device comes up to schema 5 without its rows written again, and every cloth's "
      'photo still shows', () async {
    final zip = ZipDecoder().decodeBytes(File('test/fixtures/backup/kantha-backup-v2.kantha').readAsBytesSync());
    final dir = Directory.systemTemp.createTempSync('kantha-upgrade-3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite')..writeAsBytesSync(zip.findFile('kantha.sqlite')!.readBytes()!);
    final before = sqlite3.open(file.path);
    expect(before.select('PRAGMA user_version').single.values.single, 2);
    final photos = {for (final r in before.select('SELECT id, photo FROM cloths')) r['id'] as String: r['photo'] as Uint8List};
    final pages = before.select('PRAGMA page_count').single.values.single;
    before.close();

    final shelf = Shelf(KanthaDatabase(NativeDatabase(file)));
    addTearDown(shelf.db.close);
    final cloth = (await shelfNow(shelf)).cloth;
    expect(cloth.map((c) => (c.id, c.version)), [('C-1', 1), ('C-2', 2)]);
    for (final c in cloth) {
      final picture = c.image! as ClothPhoto;
      expect(picture.photo, 0, reason: 'a photo stored before schema 3 has number 0');
      expect(await picture.bytes(), photos[c.id], reason: '${c.id} shows its own photo');
    }
    await shelf.db.close();
    final after = sqlite3.open(file.path);
    expect(after.select('PRAGMA user_version').single.values.single, 5);
    expect(after.select('PRAGMA page_count').single.values.single, (pages as int) + 1,
        reason: 'one column added and one empty table made (its one page), no row written again');
    after.close();

    final again = Shelf(KanthaDatabase(NativeDatabase(file)));
    addTearDown(again.db.close);
    final re = await again.recrop('C-1', photo(9), measured);
    final added = await again.addCloth(box: 1, photo: photo(11), measured: measured, fabric: '', pieces: 1);
    expect((re.photoNumber, added.photoNumber), (1, 2), reason: 'photos stored after the upgrade are numbered from 1');
  });

  /* As where drift shares one database between tabs: an older tab opened it first, so drift runs no upgrade for this one. */
  test('a schema-2 database already open in an older tab: after the startup check the cloth list reads, '
      'and no row is written again', () async {
    final zip = ZipDecoder().decodeBytes(File('test/fixtures/backup/kantha-backup-v2.kantha').readAsBytesSync());
    final dir = Directory.systemTemp.createTempSync('kantha-shared-open');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite')..writeAsBytesSync(zip.findFile('kantha.sqlite')!.readBytes()!);
    final before = sqlite3.open(file.path);
    final photos = {for (final r in before.select('SELECT id, photo FROM cloths')) r['id'] as String: r['photo'] as Uint8List};
    final pages = before.select('PRAGMA page_count').single.values.single;
    before.close();

    final executor = NativeDatabase(file);
    await executor.ensureOpen(const _OlderTab());
    final shelf = Shelf(KanthaDatabase(executor));
    addTearDown(shelf.db.close);
    await expectLater(shelfNow(shelf), throwsA(anything), reason: 'drift ran no upgrade: photo_number is missing');
    await shelf.db.addMissingColumns();
    await shelf.db.addMissingColumns(); // a second tab's check finds the column there
    final cloth = (await shelfNow(shelf)).cloth;
    expect(cloth.map((c) => (c.id, c.version)), [('C-1', 1), ('C-2', 2)]);
    for (final c in cloth) {
      final picture = c.image! as ClothPhoto;
      expect(picture.photo, 0);
      expect(await picture.bytes(), photos[c.id], reason: '${c.id} shows its own photo');
    }
    await shelf.db.close();
    final after = sqlite3.open(file.path);
    expect(after.select('PRAGMA user_version').single.values.single, 2, reason: 'the upgrade is left to run when it next can');
    expect(after.select('PRAGMA page_count').single.values.single, (pages as int) + 1,
        reason: 'one column added and the pictures table made (its one page), no row written again');
    after.close();

    final next = KanthaDatabase(NativeDatabase(file));
    addTearDown(next.close);
    expect((await clothRows(Shelf(next))).map((r) => r.photoNumber), [0, 0], reason: 'the upgrade skips the column now there');
    expect((await next.customSelect('PRAGMA user_version').getSingle()).data.values.single, 5);
  });

  test('a schema-1 upgrade cut off after boxes.number was added finishes on the next open', () async {
    final zip = ZipDecoder().decodeBytes(File('test/fixtures/backup/kantha-backup-v1.kantha').readAsBytesSync());
    final dir = Directory.systemTemp.createTempSync('kantha-upgrade-resume');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite')..writeAsBytesSync(zip.findFile('kantha.sqlite')!.readBytes()!);
    sqlite3.open(file.path)
      ..execute('ALTER TABLE boxes ADD COLUMN number INTEGER NULL')
      ..close();
    final db = KanthaDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect({for (final r in await db.select(db.boxes).get()) r.id: (r.number, r.name)}, {1: (1, null), 2: (2, null)});
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 5);
    expect(await (db.select(db.counters)..where((c) => c.name.equals('boxNumber'))).map((c) => c.next).getSingle(), 3);
  });

  test('a schema-1 database already open in an older tab: the startup check adds no boxes column, '
      'and the upgrade later numbers every box once', () async {
    final zip = ZipDecoder().decodeBytes(File('test/fixtures/backup/kantha-backup-v1.kantha').readAsBytesSync());
    final dir = Directory.systemTemp.createTempSync('kantha-shared-open-v1');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite')..writeAsBytesSync(zip.findFile('kantha.sqlite')!.readBytes()!);

    final executor = NativeDatabase(file);
    await executor.ensureOpen(const _OlderTab(1));
    final db = KanthaDatabase(executor);
    await db.addMissingColumns();
    Future<List<String>> columns(String table) async =>
        [for (final r in await db.customSelect('PRAGMA table_info($table)').get()) r.read<String>('name')];
    expect(await columns('boxes'), ['id', 'made'], reason: 'boxes.number and boxes.name are left to the upgrade');
    expect(await columns('cloths'), contains('photo_number'));
    // The older tab makes a box, as the schema-1 code does: the next id, no number.
    await db.customStatement("INSERT INTO boxes (id, made) VALUES (3, '2026-10-20T00:00:00.000Z')");
    await db.customStatement("UPDATE counters SET next = 4 WHERE name = 'box'");
    await db.close();

    final next = KanthaDatabase(NativeDatabase(file));
    addTearDown(next.close);
    final numbers = [for (final r in await (next.select(next.boxes)..orderBy([(b) => OrderingTerm.asc(b.id)])).get()) r.number];
    expect(numbers, [1, 2, 3]);
    expect((await next.customSelect('PRAGMA user_version').getSingle()).data.values.single, 5);
    final made = await Shelf(next).makeBox();
    expect((await (next.select(next.boxes)..where((b) => b.id.equals(made))).getSingle()).number, 4,
        reason: 'the next box is dealt a number no box has');
  });

  test('a backup made at schema 2 imports: every photo shows, each with a new number', () async {
    final shelf = Shelf(memoryDb());
    await importBackup(File('test/fixtures/backup/kantha-backup-v2.kantha').readAsBytesSync(), shelf, side);
    final rows = await clothRows(shelf);
    expect(rows.map((r) => (r.id, r.version, r.photoNumber)), [('C-1', 1, 1), ('C-2', 2, 2)]);
    for (final c in (await shelfNow(shelf)).cloth) {
      expect(await (c.image! as ClothPhoto).bytes(), rows.firstWhere((r) => r.id == c.id).photo, reason: c.id);
    }
  });

  /* kantha-backup-v3.kantha was made by the studio at 9f04768 (schema 3), the last before pictures: Box 1 with C-1
     (35 pieces) and C-2, and P-1, "Zinnia", made from C-1. */
  test('a schema-3 database on this device comes up to schema 5 without its rows written again: one empty table more, '
      'every cloth and design as it was, and no picture made', () async {
    final zip = ZipDecoder().decodeBytes(File('test/fixtures/backup/kantha-backup-v3.kantha').readAsBytesSync());
    final dir = Directory.systemTemp.createTempSync('kantha-upgrade-4');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite')..writeAsBytesSync(zip.findFile('kantha.sqlite')!.readBytes()!);
    final before = sqlite3.open(file.path);
    expect(before.select('PRAGMA user_version').single.values.single, 3);
    final pages = before.select('PRAGMA page_count').single.values.single as int;
    final cloth = before.select('SELECT * FROM cloths ORDER BY id').map((r) => r.values).toList();
    final designs = before.select('SELECT * FROM designs ORDER BY id').map((r) => r.values).toList();
    before.close();

    final shelf = Shelf(KanthaDatabase(NativeDatabase(file)));
    final now = await shelfNow(shelf);
    expect(now.designs.map((d) => (d.id, d.name)), [('P-1', 'Zinnia')]);
    expect(now.pictures, isEmpty, reason: 'a design saved before pictures has none until it is saved again');
    await shelf.db.close();
    final after = sqlite3.open(file.path);
    addTearDown(after.close);
    expect(after.select('PRAGMA user_version').single.values.single, 5);
    expect(after.select('PRAGMA page_count').single.values.single, pages + 1, reason: 'the pictures table, empty');
    expect(after.select('SELECT * FROM cloths ORDER BY id').map((r) => r.values).toList(), cloth);
    // Schema 5's cols column, its default read for every row and none written again.
    expect(after.select('SELECT * FROM designs ORDER BY id').map((r) => r.values).toList(), [for (final d in designs) [...d, 5]]);
  });

  test('a schema-3 database already open in an older tab: the startup check makes the pictures table, once, and '
      'pictures save', () async {
    final zip = ZipDecoder().decodeBytes(File('test/fixtures/backup/kantha-backup-v3.kantha').readAsBytesSync());
    final dir = Directory.systemTemp.createTempSync('kantha-shared-open-v3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite')..writeAsBytesSync(zip.findFile('kantha.sqlite')!.readBytes()!);
    final executor = NativeDatabase(file);
    await executor.ensureOpen(const _OlderTab(3));
    final shelf = Shelf(KanthaDatabase(executor));
    addTearDown(shelf.db.close);
    await expectLater(shelfNow(shelf), throwsA(anything), reason: 'drift ran no upgrade: the pictures table is missing');
    await shelf.db.addMissingColumns();
    await shelf.db.addMissingColumns();
    final design = (await shelf.db.select(shelf.db.designs).get()).single;
    expect(await shelf.savePicture(design.id, design.saved, name: design.name, png: photo(1), thumb: photo(2)), isTrue);
    expect((await shelfNow(shelf)).pictures.single.design, 'P-1');
  });

  test('a backup made at schema 3 imports: its box, cloth and design, and no pictures', () async {
    final shelf = Shelf(memoryDb());
    await importBackup(File('test/fixtures/backup/kantha-backup-v3.kantha').readAsBytesSync(), shelf, side);
    final now = await shelfNow(shelf);
    expect(now.boxes.map((b) => b.number), [1]);
    expect(now.cloth.map((c) => (c.id, c.stock)), [('C-1', 35), ('C-2', 2)]);
    expect(now.designs.map((d) => (d.id, d.name, d.grid.toSet().single)), [('P-1', 'Zinnia', 'C-1')]);
    expect(now.pictures, isEmpty);
  });

  test('back up and restore carry the pictures, a Picture only one too, byte for byte; no picture id is dealt twice',
      () async {
    final a = Shelf(memoryDb());
    final box = await a.makeBox();
    final c1 = await a.addCloth(box: box, photo: photo(3), measured: measured, fabric: '', pieces: 35);
    final c2 = await a.addCloth(box: box, photo: photo(5), measured: measured, fabric: '', pieces: 35);
    final kept = (await a.saveDesign(design(c1.id, name: 'Kept'))).design;
    final gone = (await a.saveDesign(design(c2.id, name: 'Gone'))).design;
    for (final (i, d) in [kept, gone].indexed) {
      // Each picture larger than a page of SQLite, as a real one is.
      await a.savePicture(d.id, d.saved, name: d.name, png: photo(7 + i), thumb: photo(11 + i));
    }
    await a.removeCloth(c2.id);
    final file = await exportBackup(a.db, side);
    final b = Shelf(memoryDb());
    await b.makeBox();
    await importBackup(file, b, side);
    expect(await b.db.select(b.db.pictures).get(), await a.db.select(a.db.pictures).get());
    expect({for (final p in await b.watchPictures().first) p.name: p.design}, {'Kept': kept.id, 'Gone': null});
    final d = (await b.db.select(b.db.designs).get()).single;
    await b.savePicture(d.id, d.saved, name: d.name, png: photo(1), thumb: photo(1));
    expect((await b.watchPictures().first).map((p) => p.id).toSet(), {2, 3},
        reason: 'the Picture only one keeps its id, 2; the new one is dealt past both the backup had');
  });

  /* A backup's own parts, to be changed by a test and zipped again. */
  Future<(Map<String, dynamic>, Uint8List)> partsOf(Uint8List file) async {
    final zip = ZipDecoder().decodeBytes(file);
    return (jsonDecode(utf8.decode(zip.findFile('manifest.json')!.readBytes()!)) as Map<String, dynamic>,
        zip.findFile('kantha.sqlite')!.readBytes()!);
  }

  test('photos are copied a page at a time, and every page arrives whole', () async {
    final a = Shelf(memoryDb());
    final box = await a.makeBox();
    for (var i = 1; i <= 5; i++) {
      await a.addCloth(box: box, photo: photo(i + 10), measured: measured, fabric: 'Cotton', pieces: i);
    }
    final b = Shelf(memoryDb());
    await b.replaceEverythingWith(a.db, page: 2);
    final cloth = await clothRows(b);
    expect(cloth.map((c) => c.id), ['C-1', 'C-2', 'C-3', 'C-4', 'C-5']);
    for (var i = 0; i < 5; i++) {
      expect(cloth[i].photo, photo(i + 11));
    }

    final pages = <int>[];
    await clothPages(a.db, (rows) async => pages.add(rows.length), size: 2);
    expect(pages, [2, 2, 1]);
  });

  test('the database inside is checked before it is opened: never made by Kantha, or by a newer one', () async {
    final a = Shelf(memoryDb());
    await a.makeBox();
    final (manifest, db) = await partsOf(await exportBackup(a.db, side));
    Uint8List withVersion(int v) {
      final out = Uint8List.fromList(db);
      ByteData.sublistView(out).setInt32(60, v);
      return zipOf({'manifest.json': utf8.encode(jsonEncode(manifest)), 'kantha.sqlite': out});
    }
    await refused(withVersion(0), 'notBackup');
    // Some other app's database, with none of Kantha's tables: opened by drift it would be made empty,
    // and replace her things with nothing.
    final other = File('${Directory.systemTemp.path}/kantha-other-${DateTime.now().microsecondsSinceEpoch}.sqlite');
    addTearDown(() { if (other.existsSync()) other.deleteSync(); });
    sqlite3.open(other.path)..execute('CREATE TABLE notes (text TEXT)')..close();
    await refused(zipOf({'manifest.json': utf8.encode(jsonEncode(manifest)), 'kantha.sqlite': other.readAsBytesSync()}), 'notBackup');
    await refused(withVersion(6), 'tooNew');
    await refused(zipOf({'manifest.json': utf8.encode('{"app":"kantha","kind":"backup","format":"1","schema":1}'), 'kantha.sqlite': db}),
        'notBackup');
  });

  test("a backup whose cloth sits in a box it does not hold is refused as the file's fault, and nothing changes", () async {
    final made = await side.create();
    final copy = KanthaDatabase(made.executor);
    await copy.customStatement('PRAGMA foreign_keys = OFF');
    await copy.into(copy.cloths).insert(ClothsCompanion.insert(id: 'C-1', box: 7, name: 'C-1 White', fabric: 'Cotton',
        pieces: 1, l: 90, a: 0, b: 0, spread: 1, colour: 'white', photo: photo(1), added: DateTime.now().toUtc()));
    await copy.close();
    final db = await made.bytes();
    await made.dispose();
    await refused(zipOf({'manifest.json': utf8.encode('{"app":"kantha","kind":"backup","format":1,"schema":1}'), 'kantha.sqlite': db}),
        'notBackup');
  });

  test('the side files are gone afterwards', () async {
    final dir = Directory.systemTemp.createTempSync('kantha-side-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final here = IoSideDb(dir);
    final a = Shelf(memoryDb());
    await a.makeBox();
    final file = await exportBackup(a.db, here);
    await importBackup(file, Shelf(memoryDb()), here);
    await expectLater(importBackup(zipOf({'manifest.json': utf8.encode('{"app":"kantha","kind":"backup","format":1,"schema":1}'),
        'kantha.sqlite': (await partsOf(file)).$2.sublist(0, 200)}), Shelf(memoryDb()), here), throwsA(isA<BackupError>()));
    expect(dir.listSync(), isEmpty);
  });
}

/* Every cloth row as stored, photo and all, in the order they were added (Shelf.watchCloth leaves the photo out). */
Future<List<ClothRow>> clothRows(Shelf s) => (s.db.select(s.db.cloths)..orderBy([(c) => OrderingTerm.asc(c.added)])).get();

/* The side files `inner` makes, with every statement run on them written down. */
class _Watched implements SideDb {
  _Watched(this.inner);
  final SideDb inner;
  final statements = <String>[];
  @override
  Future<SideFile> create() async => _WatchedFile(await inner.create(), statements);
  @override
  Future<SideFile> open(Uint8List bytes) async => _WatchedFile(await inner.open(bytes), statements);
}

class _WatchedFile extends QueryInterceptor implements SideFile {
  _WatchedFile(this.inner, this.statements);
  final SideFile inner;
  final List<String> statements;
  @override
  late final QueryExecutor executor = inner.executor.interceptWith(this);
  @override
  Future<Uint8List> bytes() => inner.bytes();
  @override
  Future<void> dispose() => inner.dispose();
  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) {
    statements.add(statement);
    return executor.runCustom(statement, args);
  }
  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) {
    statements.add(statement);
    return executor.runSelect(statement, args);
  }
}

/* A side database that counts what it makes. */
class _Counting implements SideDb {
  _Counting(this.inner, this.made);
  final SideDb inner;
  final void Function() made;
  @override
  Future<SideFile> create() { made(); return inner.create(); }
  @override
  Future<SideFile> open(Uint8List bytes) => inner.open(bytes);
}

/* A tab on the release before: it opened the shared database first, with no upgrade to run. */
class _OlderTab implements QueryExecutorUser {
  const _OlderTab([this.schemaVersion = 2]);
  @override
  final int schemaVersion;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
