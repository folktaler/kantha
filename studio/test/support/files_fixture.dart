import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:image/image.dart' as img;
import 'package:kantha_studio/backup/files.dart';
import 'package:kantha_studio/data/backup.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/data/side_db_io.dart';
import 'package:kantha_studio/downloads/delivery.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'db.dart';

/* The file picker, answering with one backup file (or nothing: she cancelled). */
class FixtureFiles implements Files {
  FixtureFiles(this.file);
  FixtureFiles.withBackupOf(Uint8List? bytes, {String name = 'kantha-backup-2026-10-06.kantha'})
      : file = bytes == null ? null : (name: name, bytes: bytes);
  final ({String name, Uint8List bytes})? file;
  var picked = 0;
  @override
  Future<({String name, Uint8List bytes})?> pickBackup() async {
    picked++;
    return file;
  }
}

/* The side database a VM test writes into: a file in the system's temporary directory. */
final testSideDb = IoSideDb(Directory.systemTemp);

/* The backup of a device that holds nothing of hers yet. Run it inside tester.runAsync. */
Future<Uint8List> emptyDeviceBackup() => exportBackup(memoryDb(), testSideDb);

/* A backup holding Box 1 with one cloth of `pieces` pieces — enough to fill a template from 35. */
Future<Uint8List> oneBoxBackup({int pieces = 40}) async {
  final from = Shelf(memoryDb());
  final box = await from.makeBox();
  final photo = img.encodeJpg(img.Image(width: 64, height: 64)..clear(img.ColorRgb8(150, 40, 60)), quality: 90);
  await from.addCloth(box: box, photo: photo, measured: measureBytes(photo), fabric: 'Linen', pieces: pieces);
  return exportBackup(from.db, testSideDb);
}

/* Today's backup file name. */
final today = backupFileName(DateTime.now());

/* A shelf whose reads fail once an import is in: the studio's re-reading after it breaks. */
class BrokenAfterImport extends Shelf {
  BrokenAfterImport(super.db);
  bool broken = false;
  @override
  Future<void> replaceEverythingWith(KanthaDatabase from, {int page = 20}) async {
    await super.replaceEverythingWith(from, page: page);
    broken = true;
  }
  @override
  Stream<List<BoxRow>> watchBoxes() => broken ? Stream.error(StateError('the shelf would not read')) : super.watchBoxes();
}

/* Notes each file's name and keeps its bytes, and each backup handed over by its file name, with the rect that asked.
   `gate`, while open, holds Save photo until the test lets it through; `fail` makes Save photo's and the PDF's hand-over throw; `kept` is
   what the share sheet said of a backup: false is her dismissing it. */
class CaptureDelivery implements Delivery {
  CaptureDelivery({this.kept = true});
  bool kept;
  final saved = <String>[], pdfs = <String>[];
  final bytes = <String, Uint8List>{}, backups = <String, Uint8List>{};
  var handed = 0;
  Rect? origin;
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<void> savePhoto(Uint8List b, String f) async {
    await gate?.future;
    if (fail) throw StateError('the photo would not save');
    saved.add(f);
    bytes[f] = b;
  }
  @override
  Future<void> sharePdf(Uint8List b, String f, {Rect? origin}) async {
    if (fail) throw StateError('the print sheet would not open');
    pdfs.add(f);
    bytes[f] = b;
  }
  final shared = <String>[];
  @override
  Future<void> sharePhoto(Uint8List b, String f, {Rect? origin}) async {
    if (fail) throw StateError('the share sheet would not open');
    shared.add(f);
    bytes[f] = b;
  }
  @override
  Future<bool> saveBackup(Uint8List b, String f, {Rect? origin}) async {
    backups[f] = b;
    handed++;
    this.origin = origin;
    return kept;
  }
}
