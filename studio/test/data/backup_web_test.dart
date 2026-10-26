@TestOn('browser')
library;

import 'dart:typed_data';
import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/backup.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/data/side_db.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:sqlite3/wasm.dart';

const measured = Measured(lab: (l: 37.8, a: -6.3, b: -4.6), name: 'darkslategray', spread: 3.1, width: 100, height: 100);
Uint8List photo(int seed) => Uint8List.fromList(List.generate(4096, (i) => (i * seed) & 255));

/* The live database's stand-in: the web's own sqlite3 in memory (the app's runs in drift's worker). */
Future<KanthaDatabase> webMemoryDb() async {
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  sqlite3.registerVirtualFileSystem(InMemoryFileSystem(name: 'live-${DateTime.now().microsecondsSinceEpoch}'), makeDefault: true);
  final db = KanthaDatabase(WasmDatabase.inMemory(sqlite3));
  addTearDown(db.close);
  return db;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('in a browser a backup is written into the side database in memory, and read back from it', () async {
    final side = createSideDb();
    final a = Shelf(await webMemoryDb());
    final box = await a.makeBox();
    await a.addCloth(box: box, photo: photo(3), measured: measured, fabric: 'Cotton', pieces: 4);
    final c2 = await a.addCloth(box: box, photo: photo(5), measured: measured, fabric: 'Linen', pieces: 2);
    final d = (await a.saveDesign(DesignInput(name: 'Zinnia', layout: 'contrast', mount: 'none', box: box, seed: 1,
        started: null, firstSolve: null, grid: List.generate(35, (_) => GridCell(c2.id, 0))))).design;
    await a.savePicture(d.id, d.saved, name: d.name, png: photo(7), thumb: photo(9));

    final file = await exportBackup(a.db, side, now: DateTime(2026, 10, 6));
    final b = Shelf(await webMemoryDb());
    await b.makeBox(); await b.makeBox();
    await importBackup(file, b, side);

    expect((await b.watchBoxes().first).map((x) => x.id), [1]);
    final cloth = await clothRows(b);
    expect(cloth.map((x) => (x.id, x.pieces, x.fabric)), [('C-1', 4, 'Cotton'), ('C-2', 2, 'Linen')]);
    expect(cloth.last.photo, photo(5));
    expect(await b.db.select(b.db.pictures).get(), await a.db.select(a.db.pictures).get(), reason: 'the picture comes too');
    await expectLater(importBackup(Uint8List.fromList([1, 2, 3]), b, side),
        throwsA(isA<BackupError>().having((e) => e.key, 'key', 'notBackup')));
  });
}

/* Every cloth row as stored, photo and all, in the order they were added (Shelf.watchCloth leaves the photo out). */
Future<List<ClothRow>> clothRows(Shelf s) => (s.db.select(s.db.cloths)..orderBy([(c) => OrderingTerm.asc(c.added)])).get();
