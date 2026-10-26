import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';
import '../platform/release.dart';
import 'side_db.dart';

SideDb create() => _WebSideDb();

/* The page's own sqlite3.wasm with a file system in memory: a backup is written
   into it and read back out as bytes, and nothing touches the live database's storage
   (that one runs in drift's worker and cannot be read as bytes). */
class _WebSideDb implements SideDb {
  Future<(WasmSqlite3, InMemoryFileSystem)>? _ready;
  Future<(WasmSqlite3, InMemoryFileSystem)> _load() => _ready ??= () async {
        final sqlite3 = await WasmSqlite3.loadFromUrl(releaseFile('sqlite3.wasm', pageBase()));
        final fs = InMemoryFileSystem(name: 'kantha-side');
        sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
        return (sqlite3, fs);
      }();

  var _n = 0;
  @override
  Future<SideFile> create() async {
    final (s, fs) = await _load();
    return _WebSideFile(s, fs, '/side-${_n++}.sqlite');
  }

  @override
  Future<SideFile> open(Uint8List bytes) async {
    final (s, fs) = await _load();
    final path = '/side-${_n++}.sqlite';
    final f = fs.xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE).file;
    f.xWrite(bytes, 0);
    f.xClose();
    return _WebSideFile(s, fs, path);
  }
}

class _WebSideFile implements SideFile {
  _WebSideFile(WasmSqlite3 sqlite3, this.fs, this.path) : executor = WasmDatabase(sqlite3: sqlite3, path: path);
  final InMemoryFileSystem fs;
  final String path;
  @override
  final QueryExecutor executor;
  @override
  Future<Uint8List> bytes() async {
    final f = fs.xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_READONLY).file;
    final out = Uint8List(f.xFileSize());
    f.xRead(out, 0);
    f.xClose();
    return out;
  }

  @override
  Future<void> dispose() async {
    for (final p in [path, '$path-journal']) {
      fs.xDelete(p, 0);
    }
  }
}
