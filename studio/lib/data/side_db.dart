import 'package:drift/drift.dart';
import 'side_db_io.dart' if (dart.library.js_interop) 'side_db_web.dart' as impl;

/* A second SQLite file, beside the live one, for a backup to be written into or read from. */
abstract interface class SideFile {
  QueryExecutor get executor;
  Future<Uint8List> bytes();
  Future<void> dispose();
}

abstract interface class SideDb {
  Future<SideFile> create();
  Future<SideFile> open(Uint8List bytes);
}

SideDb createSideDb() => impl.create();
