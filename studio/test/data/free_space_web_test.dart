@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:drift/drift.dart' show driftRuntimeOptions;
// The wrapper drift puts round each tab's database in opfsLocks mode, the mode the built site opens in on Chrome.
// ignore: implementation_imports
import 'package:drift/src/web/wasm_setup/navigator_locks_interceptor.dart' show NavigatorLocksExecutor;
import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/connect.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

const measured = Measured(lab: (l: 37.8, a: -6.3, b: -4.6), name: 'darkslategray', spread: 3.1, width: 100, height: 100);
Uint8List photo(int seed) => Uint8List.fromList(List.generate(100000, (i) => (i * seed + i ~/ 7) & 255));

/* The browser's IndexedDB store, the one drift falls back to without OPFS: what is written there, read back after the
   store is closed and opened again, as on the next visit. */
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const path = '/kantha.sqlite';

  Future<(WasmSqlite3, IndexedDbFileSystem)> store(String name) async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    final fs = await IndexedDbFileSystem.open(dbName: name, vfsName: '$name-${DateTime.now().microsecondsSinceEpoch}');
    sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
    return (sqlite3, fs);
  }

  Future<int> storedSize(String name) async {
    final (_, fs) = await store(name);
    final size = fs.xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_READONLY).file.xFileSize();
    await fs.close();
    return size;
  }

  test('in IndexedDB a new database is made as the studio makes it there (connect.dart freesSpace: no): 20 removed '
      'cloths leave the stored file as large as it was, and are gone on the next visit', () async {
    final name = 'kantha-free-${DateTime.now().microsecondsSinceEpoch}';
    var (sqlite3, fs) = await store(name);
    var db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path), freesSpace: () => freesSpace(WasmStorageImplementation.unsafeIndexedDb));
    final shelf = Shelf(db);
    final box = await shelf.makeBox();
    expect((await db.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>('auto_vacuum'), 0);
    final ids = [
      for (var i = 1; i <= 20; i++)
        (await shelf.addCloth(box: box, photo: photo(i), measured: measured, fabric: 'Cotton', pieces: 1)).id,
    ];
    await db.close();
    await fs.close();
    final full = await storedSize(name);
    expect(full, greaterThan(20 * 100000));

    (sqlite3, fs) = await store(name);
    db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path));
    for (final id in ids) {
      await Shelf(db).removeCloth(id);
    }
    await db.close();
    await fs.close();
    expect(await storedSize(name), full);
    (sqlite3, fs) = await store(name);
    db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path));
    expect(await db.select(db.cloths).get(), isEmpty);
    await db.close();
    await fs.close();
    await IndexedDbFileSystem.deleteDatabase(name);
  });

  test('in IndexedDB a removed cloth is gone on the next visit, even when the tab closes straight after', () async {
    final name = 'kantha-remove-${DateTime.now().microsecondsSinceEpoch}';
    // As drift sets up IndexedDB in the studio: nothing reaches IndexedDB until drift flushes it.
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    final fs = await IndexedDbFileSystem.open(dbName: name, vfsName: '$name-a', writeAutomatically: false);
    sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
    final db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path, fileSystem: fs));
    final box = await Shelf(db).makeBox();
    for (var i = 1; i <= 2; i++) {
      await Shelf(db).addCloth(box: box, photo: photo(i), measured: measured, fabric: 'Cotton', pieces: 1);
    }
    // One transaction, and nothing after it: the tab is closed here, so the database is never closed.
    await Shelf(db).removeCloth('C-1');

    final (sqlite3b, fsb) = await store(name);
    final next = KanthaDatabase(WasmDatabase(sqlite3: sqlite3b, path: path));
    expect((await next.select(next.cloths).get()).map((c) => c.id), ['C-2']);
    await next.close();
    await fsb.close();
    await db.close();
    await fs.close();
    await IndexedDbFileSystem.deleteDatabase(name);
  });

  test('in IndexedDB a database made before 20 Oct is left as it was by opening, and keeps her cloth', () async {
    final name = 'kantha-old-${DateTime.now().microsecondsSinceEpoch}';
    var (sqlite3, fs) = await store(name);
    var db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path));
    final box = await Shelf(db).makeBox();
    for (var i = 1; i <= 3; i++) {
      await Shelf(db).addCloth(box: box, photo: photo(i), measured: measured, fabric: 'Cotton', pieces: 1);
    }
    // As the studio left it before 20 Oct.
    await db.customStatement('PRAGMA auto_vacuum = NONE');
    await db.customStatement('VACUUM');
    await db.close();
    await fs.close();

    (sqlite3, fs) = await store(name);
    db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path));
    expect((await db.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>('auto_vacuum'), 0,
        reason: 'no VACUUM on IndexedDB: a tab closed during one could leave the file part old, part new');
    await db.close();
    await fs.close();

    (sqlite3, fs) = await store(name);
    db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path));
    final raw = await db.customSelect('PRAGMA auto_vacuum').getSingle();
    expect(raw.read<int>('auto_vacuum'), 0);
    expect((await db.select(db.cloths).get()).map((c) => c.id), ['C-1', 'C-2', 'C-3']);
    await db.close();
    await fs.close();
    await IndexedDbFileSystem.deleteDatabase(name);
  });

  test('in IndexedDB a database with most of its room empty is never offered Free up space, and freeSpace refuses '
      'without changing it', () async {
    final name = 'kantha-offer-${DateTime.now().microsecondsSinceEpoch}';
    final (sqlite3, fs) = await store(name);
    final db = KanthaDatabase(WasmDatabase(sqlite3: sqlite3, path: path),
        freesSpace: () => freesSpace(WasmStorageImplementation.unsafeIndexedDb));
    final shelf = Shelf(db);
    final box = await shelf.makeBox();
    final ids = [
      for (var i = 1; i <= 20; i++)
        (await shelf.addCloth(box: box, photo: photo(i), measured: measured, fabric: 'Cotton', pieces: 1)).id,
    ];
    for (final id in ids.skip(2)) {
      await shelf.removeCloth(id);
    }
    final space = await db.space();
    expect(space.empty, greaterThan(1000000));
    expect(space.empty * 2, greaterThan(space.bytes));
    expect(space.mayFree, isFalse);
    await expectLater(db.freeSpace(), throwsStateError);
    expect(await db.space(), space);
    expect((await db.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>('auto_vacuum'), 0);
    expect(freesSpace(WasmStorageImplementation.sharedIndexedDb), isFalse);
    expect(freesSpace(WasmStorageImplementation.inMemory), isFalse);
    await db.close();
    await fs.close();
    await IndexedDbFileSystem.deleteDatabase(name);
  });

  test('two tabs on one database, as drift holds them on Chrome\'s OPFS (each its own connection, behind its navigator '
      'lock): a write from the other tab waits until Free up space has ended, and that tab then reads and writes the '
      'smaller file', () async {
    final name = 'kantha-tabs-${DateTime.now().microsecondsSinceEpoch}', lock = 'drift-db-$name';
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    sqlite3.registerVirtualFileSystem(InMemoryFileSystem(name: name), makeDefault: true);
    KanthaDatabase tab(bool Function() opfs) =>
        KanthaDatabase(NavigatorLocksExecutor(WasmDatabase(sqlite3: sqlite3, path: path), name), freesSpace: opfs);
    // Made before 20 Oct: auto_vacuum NONE. Then 18 of its 20 photos removed.
    var opfs = false;
    final a = tab(() => opfs), b = tab(() => true);
    final box = await Shelf(a).makeBox();
    final ids = [
      for (var i = 1; i <= 20; i++)
        (await Shelf(a).addCloth(box: box, photo: photo(i), measured: measured, fabric: 'Cotton', pieces: 1)).id,
    ];
    for (final id in ids.skip(2)) {
      await Shelf(a).removeCloth(id);
    }
    opfs = true;
    expect((await b.select(b.cloths).get()).map((c) => c.id), ['C-1', 'C-2'], reason: 'the other tab is open');
    final before = await a.space();
    expect(before.mayFree, isTrue);

    // The lock held here first, so the two requests queue behind it in order: Free up space, then the other tab's write.
    final locks = web.window.navigator.locks, release = Completer<void>(), held = Completer<void>();
    locks.request(lock, ((web.Lock? _) { held.complete(); return release.future.toJS; }).toJS);
    await held.future;
    Future<int> waiting() async => (await locks.query().toDart).pending.toDart.where((l) => l.name == lock).length;
    final order = <String>[];
    final freeing = a.freeSpace().then((r) { order.add('freed'); return r; });
    while (await waiting() < 1) { await Future<void>.delayed(const Duration(milliseconds: 5)); }
    final writing = Shelf(b).makeBox().then((n) { order.add('other tab wrote'); return n; });
    while (await waiting() < 2) { await Future<void>.delayed(const Duration(milliseconds: 5)); }
    release.complete();
    final r = await freeing, box2 = await writing;
    expect(order, ['freed', 'other tab wrote']);
    expect(r.after, lessThan(before.bytes ~/ 4));

    expect((await b.select(b.boxes).get()).map((x) => x.id), [box, box2]);
    expect((await b.select(b.cloths).get()).map((c) => c.id), ['C-1', 'C-2']);
    expect((await b.customSelect('PRAGMA auto_vacuum').getSingle()).read<int>('auto_vacuum'), 1);
    expect((await b.customSelect('PRAGMA integrity_check').getSingle()).read<String>('integrity_check'), 'ok');
    await Shelf(b).removeCloth('C-2');
    expect((await a.select(a.cloths).get()).map((c) => c.id), ['C-1'], reason: 'the first tab reads the other\'s write');
    expect((await a.space()).bytes, lessThan(r.after), reason: 'a delete in either tab now shrinks the file');
    await b.close();
    await a.close();
  });
}
