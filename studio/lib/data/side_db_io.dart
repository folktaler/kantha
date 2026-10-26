import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'side_db.dart';

SideDb create() => IoSideDb(null);

/* A temporary file on a phone (path_provider's temporary directory), or in `dir` when a test gives one. */
class IoSideDb implements SideDb {
  IoSideDb(this._dir);
  final Directory? _dir;
  Future<File> _file() async {
    final dir = _dir ?? await getTemporaryDirectory();
    return File('${dir.path}/kantha-side-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}.sqlite');
  }

  @override
  Future<SideFile> create() async => _IoSideFile(await _file());
  @override
  Future<SideFile> open(Uint8List bytes) async => _IoSideFile((await _file())..writeAsBytesSync(bytes));
}

class _IoSideFile implements SideFile {
  _IoSideFile(this.file) : executor = NativeDatabase(file);
  final File file;
  @override
  final QueryExecutor executor;
  @override
  Future<Uint8List> bytes() async => file.readAsBytes();
  @override
  Future<void> dispose() async {
    for (final f in [file, File('${file.path}-journal')]) {
      if (f.existsSync()) f.deleteSync();
    }
  }
}
