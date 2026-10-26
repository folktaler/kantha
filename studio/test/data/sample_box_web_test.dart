@TestOn('browser')
library;

import 'dart:typed_data';
import 'package:drift/drift.dart' show driftRuntimeOptions;
// The wrapper drift puts round the database in opfsLocks mode, the mode the built site opens in on Chrome.
// ignore: implementation_imports
import 'package:drift/src/web/wasm_setup/navigator_locks_interceptor.dart' show NavigatorLocksExecutor;
import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/sample_box.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:sqlite3/wasm.dart';

/* The live database as the built site holds it in opfsLocks mode: the web's own sqlite3, behind drift's navigator
   locks. A transaction opened inside another shares the outer one's lock, and its commit hands the lock back early,
   so the outer commit then fails ("Future already completed"). */
Future<KanthaDatabase> lockedWebDb() async {
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final name = 'sample-${DateTime.now().microsecondsSinceEpoch}';
  sqlite3.registerVirtualFileSystem(InMemoryFileSystem(name: name), makeDefault: true);
  final db = KanthaDatabase(NavigatorLocksExecutor(WasmDatabase.inMemory(sqlite3), name));
  addTearDown(db.close);
  return db;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('in a browser, behind drift\'s navigator locks, the Sample box is made whole on first launch', () async {
    final shelf = Shelf(await lockedWebDb());
    // This test's server does not serve the app's files: each photo is a small JPEG made here.
    final photo = img.encodeJpg(img.Image(width: 64, height: 64)..clear(img.ColorRgb8(180, 60, 50)), quality: 80);
    await makeSampleBox(shelf, read: (_) async => ByteData.sublistView(photo));
    expect((await shelf.db.select(shelf.db.boxes).get()).map((b) => b.name), ['sample']);
    final cloth = await shelf.db.select(shelf.db.cloths).get();
    expect(cloth.map((c) => c.name), [for (final s in sampleCloth) s.name]);
    expect(cloth.every((c) => c.pieces == samplePieces), isTrue);
  });
}
