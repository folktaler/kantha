import 'dart:convert';
import 'dart:typed_data';
// Loaded when a backup is made or opened, not with the studio's first screen (his decision, 20 Oct).
import 'package:archive/archive.dart' deferred as archive;
import 'package:drift/drift.dart';
import '../platform/deferred.dart';
import 'database.dart';
import 'shelf.dart';
import 'side_db.dart';
import '../platform/report.dart';

/* Spec decisions 14–17: one file, `kantha-backup-<date>.kantha`, a zip holding a manifest and
   the database itself (made by KanthaDatabase, so the same schema). */
const backupFormat = 1;

/* The zip code a backup needs, loaded the first time one is made or opened. */
Future<void> loadBackupCode() => loadTwice(archive.loadLibrary);

class BackupError implements Exception {
  const BackupError(this.key);
  final String key; // notBackup | tooNew | failed | notLoaded (the zip code would not load: nothing was read)
  @override
  String toString() => 'BackupError($key)';
}

String backupFileName(DateTime d) =>
    'kantha-backup-${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.kantha';

/* `load` is loadBackupCode, asked first, before anything is copied; a test passes a load that fails. */
Future<Uint8List> exportBackup(KanthaDatabase live, SideDb side, {DateTime? now,
    Future<void> Function() load = loadBackupCode}) async {
  try {
    await load();
  } catch (e, s) {
    // Not the device's fault: nothing has been copied.
    reportError(e, s, 'while the backup code loaded, asked twice');
    throw const BackupError('notLoaded');
  }
  final file = await side.create();
  KanthaDatabase? copy;
  try {
    final into = copy = KanthaDatabase(file.executor);
    final boxes = await live.select(live.boxes).get();
    final designs = await live.select(live.designs).get(), counters = await live.select(live.counters).get();
    await into.transaction(() async {
      await into.batch((b) {
        b.insertAll(into.boxes, boxes);
        b.insertAll(into.designs, designs);
        b.insertAll(into.counters, counters);
      });
      // The photos a page at a time: a full box is tens of megabytes.
      await clothPages(live, (rows) => into.batch((b) => b.insertAll(into.cloths, rows)));
      await picturePages(live, (rows) => into.batch((b) => b.insertAll(into.pictures, rows)));
    });
    await into.close();
    copy = null;
    final db = await file.bytes();
    final manifest = utf8.encode(jsonEncode({'app': 'kantha', 'kind': 'backup', 'format': backupFormat,
        'schema': live.schemaVersion, 'made': (now ?? DateTime.now()).toUtc().toIso8601String()}));
    final zip = archive.Archive()
      ..addFile(archive.ArchiveFile.bytes('manifest.json', manifest))
      ..addFile(archive.ArchiveFile.bytes('kantha.sqlite', db));
    return archive.ZipEncoder().encodeBytes(zip);
  } catch (e, s) {
    reportError(e, s, 'while a backup was made');
    throw const BackupError('failed');
  } finally {
    await copy?.close();
    await file.dispose();
  }
}

/* Her cloth, `size` rows at a time, so only one page of photos is held at once. */
Future<void> clothPages(KanthaDatabase from, Future<void> Function(List<ClothRow>) each, {int size = 20}) async {
  for (var at = 0;; at += size) {
    final rows = await (from.select(from.cloths)
          ..orderBy([(c) => OrderingTerm.asc(c.id)])
          ..limit(size, offset: at))
        .get();
    if (rows.isNotEmpty) await each(rows);
    if (rows.length < size) return;
  }
}

/* The schema version SQLite keeps in its file header (bytes 60–63), read before drift opens
   the file — opening it runs the migrations. Null when the bytes are not an SQLite database. */
int? _userVersion(Uint8List db) {
  const magic = 'SQLite format 3\u0000';
  if (db.length < 100 || String.fromCharCodes(db.sublist(0, 16)) != magic) return null;
  return ByteData.sublistView(db, 60, 64).getInt32(0);
}

/* `load` is loadBackupCode; a test passes a load that fails. */
Future<void> importBackup(Uint8List bytes, Shelf shelf, SideDb side, {Future<void> Function() load = loadBackupCode}) async {
  try {
    await load();
  } catch (e, s) {
    // Not the file's fault: it has not been read.
    reportError(e, s, 'while the backup code loaded, asked twice');
    throw const BackupError('notLoaded');
  }
  // Typed by inference: a type from a library loaded later cannot be written down.
  final zip = () {
    try { return archive.ZipDecoder().decodeBytes(bytes); } catch (_) { throw const BackupError('notBackup'); }
  }();
  final m = zip.findFile('manifest.json'), dbFile = zip.findFile('kantha.sqlite');
  if (m == null || dbFile == null) throw const BackupError('notBackup');
  final Object? manifest;
  try { manifest = jsonDecode(utf8.decode(m.readBytes()!)); } catch (_) { throw const BackupError('notBackup'); }
  if (manifest is! Map || manifest['app'] != 'kantha' || manifest['kind'] != 'backup') throw const BackupError('notBackup');
  final format = manifest['format'], schema = manifest['schema'];
  if (format is! int || schema is! int) throw const BackupError('notBackup');
  if (format > backupFormat || schema > shelf.db.schemaVersion) throw const BackupError('tooNew');
  final Uint8List dbBytes;
  try { dbBytes = dbFile.readBytes()!; } catch (_) { throw const BackupError('notBackup'); }
  final version = _userVersion(dbBytes);
  // 0 is a database drift never made: opening it would create empty tables and replace her things with nothing.
  if (version == null || version < 1) throw const BackupError('notBackup');
  if (version > shelf.db.schemaVersion) throw const BackupError('tooNew');

  final file = await side.open(dbBytes);
  final from = KanthaDatabase(file.executor);
  try {
    try {
      await from.select(from.boxes).get(); // opens it: drift's migrations bring an older file up to date
    } catch (_) {
      throw const BackupError('notBackup');
    }
    try {
      await shelf.replaceEverythingWith(from);
    } on ShelfError catch (e, s) {
      if (e.key == 'badImport') throw const BackupError('notBackup');
      reportError(e, s, 'while a backup replaced this device');
      throw const BackupError('failed');
    } on BackupError {
      rethrow;
    } catch (e, s) {
      // A damaged file can open and still fail on a table it lacks.
      reportError(e, s, 'while a backup was read');
      throw const BackupError('notBackup');
    }
  } finally {
    await from.close();
    await file.dispose();
  }
}
