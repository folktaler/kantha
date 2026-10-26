import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/database.dart';

/* A fresh database in memory, closed when the test ends. Tests open two at once on
   purpose (a backup goes from one device to another), so drift's warning about a
   second database of the same class is turned off. */
KanthaDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = KanthaDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}
