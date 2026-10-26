import 'package:drift/drift.dart';

part 'database.g.dart';

/* Her boxes, and the sample box a fresh install opens on (data/numbers.dart). */
@DataClassName('BoxRow')
class Boxes extends Table {
  IntColumn get id => integer()();
  DateTimeColumn get made => dateTime()();
  /* Her boxes carry the number she sees, given once and never reused; a sample box has none and a name. */
  IntColumn get number => integer().nullable()();
  TextColumn get name => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/* A cloth she photographed: its photo (JPEG, quality storedJpegQuality, long side ≤ storedLongSide; photos stored before
   20 Oct 2026 are quality 90, ≤ 1500 px), what it measured, and how many pieces. */
@DataClassName('ClothRow')
class Cloths extends Table {
  TextColumn get id => text()();
  IntColumn get box => integer().references(Boxes, #id)();
  TextColumn get name => text()();
  TextColumn get fabric => text()();
  IntColumn get pieces => integer()();
  RealColumn get l => real()();
  RealColumn get a => real()();
  RealColumn get b => real()();
  RealColumn get spread => real()();
  TextColumn get colour => text()();
  BlobColumn get photo => blob()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get added => dateTime()();
  /* Which photo this is: a number from the 'photo' counter, dealt each time a photo is stored (added, re-cropped or
     brought by an import), so no two photos on this device ever carry the same one. 0 for a photo stored before
     schema 3, which each cloth has at most one of (an import deals new numbers). ClothPhoto names a photo by it. */
  IntColumn get photoNumber => integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DesignRow')
class Designs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get layout => text()();
  TextColumn get mount => text()();
  IntColumn get box => integer().nullable()();
  IntColumn get seed => integer().nullable()();
  TextColumn get started => text().nullable()();
  TextColumn get firstSolve => text().nullable()();
  TextColumn get grid => text()();
  DateTimeColumn get saved => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/* A saved design's picture: the photo Save photo makes (png, 1080 × 1350) and a small copy of it for My designs
   (thumb, thumbWidth × thumbHeight), made each time she saves the design. Its own row, so it stays when the design goes
   because its cloth did: then `design` is null and My designs shows it as Picture only. `name` is the design's name
   when the picture was made, and `saved` the design's saved time it was made from: a picture belongs to one save of
   its design. Added at schema 4 as a new table: no row of the others is written again. */
@DataClassName('PictureRow')
class Pictures extends Table {
  IntColumn get id => integer()();
  TextColumn get design => text().nullable()();
  TextColumn get name => text()();
  DateTimeColumn get made => dateTime()();
  DateTimeColumn get saved => dateTime()();
  BlobColumn get png => blob()();
  BlobColumn get thumb => blob()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/* The next number for each kind of id. Never goes down, so an id is never dealt twice. */
@DataClassName('CounterRow')
class Counters extends Table {
  TextColumn get name => text()();
  IntColumn get next => integer()();
  @override
  Set<Column<Object>> get primaryKey => {name};
}

@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Boxes, Cloths, Designs, Pictures, Counters, Settings])
class KanthaDatabase extends _$KanthaDatabase {
  /* `freesSpace` is true only for the studio's own database on a phone's file or OPFS (main.dart, connect.dart
     freesSpace). When the file is first made, it is then made with auto_vacuum FULL, and SQLite shortens the file at
     every commit by the pages a delete freed, so the space of a deleted photo goes back (his decision, 20 Oct). Never
     on IndexedDB or memory, and never for a backup's own database (the default). A file made before, or made without
     it, keeps auto_vacuum NONE until she frees its space from the Menu (freeSpace, his decision, 21 Oct), which only
     a database with `freesSpace` offers. */
  KanthaDatabase(super.e, {bool Function()? freesSpace}) : _freesSpace = freesSpace ?? _never;
  final bool Function() _freesSpace;
  static bool _never() => false;
  /* Whether this database is on OPFS or a phone's file: only there does the Menu say its size or offer Free up space
     (owner, 22 Oct). */
  bool get freesSpace => _freesSpace();

  /* The least empty room in the file for which the Menu offers Free up space: a quarter of the file, and 1 MB. */
  static const freeShare = 4, freeAtLeast = 1000000;

  /* The room her database file takes on this device (page_count × page_size: the file itself, which the Menu can
     shrink), how much of it is pages a delete left empty (freelist_count), and whether the Menu offers to free them:
     only where `freesSpace` holds and the empty pages are at least a quarter of the file and 1 MB. A file with
     auto_vacuum FULL keeps no empty pages past a commit, so it is never offered. */
  Future<({int bytes, int empty, bool mayFree})> space() async {
    final r = await customSelect('SELECT p.page_count * s.page_size AS bytes, f.freelist_count * s.page_size AS empty '
        'FROM pragma_page_count() p, pragma_page_size() s, pragma_freelist_count() f').getSingle();
    final bytes = r.read<int>('bytes'), empty = r.read<int>('empty');
    return (bytes: bytes, empty: empty, mayFree: _freesSpace() && empty * freeShare >= bytes && empty >= freeAtLeast);
  }

  /* Free up space (his decision, 21 Oct): SQLite's own PRAGMA auto_vacuum = FULL, then VACUUM, which writes the file
     again without its empty pages, so it is smaller now and shrinks at every delete from then on. Only where `freesSpace`
     holds: there SQLite's rollback journal is kept beside the file, so a VACUUM cut off part-way (a failure, the tab or
     app closed) is rolled back and the file is as it was. Run under drift's exclusive hold of the database: in another
     tab (drift's navigator lock on Chrome's OPFS, its shared worker on Firefox's) every read and write waits until it
     ends, and then reads the new file. Returns the file's size before and after. */
  Future<({int before, int after})> freeSpace() {
    if (!_freesSpace()) return Future.error(StateError('Free up space runs only on OPFS or a phone\'s file'));
    return exclusively(() async {
      final before = (await space()).bytes;
      await customStatement('PRAGMA auto_vacuum = FULL');
      await customStatement('VACUUM');
      return (before: before, after: (await space()).bytes);
    });
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Before the first table, where SQLite takes it without a VACUUM.
          if (_freesSpace()) await customStatement('PRAGMA auto_vacuum = FULL');
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Each column is added only when it is missing: an upgrade cut off after a step has committed, before drift
          // writes the new version number, then finishes on the next open instead of failing on the column for ever.
          if (from < 2) {
            await transaction(() async {
              await _addMissing(m, [(boxes, boxes.number), (boxes, boxes.name)]);
              // Boxes made before numbers were stored were numbered by position: give each its position, in id order.
              // A box already given its number keeps it.
              final rows = await (select(boxes)..orderBy([(b) => OrderingTerm.asc(b.id)])).get();
              for (var i = 0; i < rows.length; i++) {
                if (rows[i].number != null) continue;
                await (update(boxes)..where((b) => b.id.equals(rows[i].id))).write(BoxesCompanion(number: Value(i + 1)));
              }
              await into(counters).insertOnConflictUpdate(CountersCompanion.insert(name: 'boxNumber', next: rows.length + 1));
            });
          }
          // One ALTER TABLE ADD COLUMN with a constant default: SQLite writes no row again, so no photo is copied.
          if (from < 3) await _addMissing(m, [(cloths, cloths.photoNumber)]);
          // A new table (CREATE TABLE IF NOT EXISTS): nothing already stored is touched.
          if (from < 4) await m.createTable(pictures);
        },
        beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
      );

  /* Run once when the studio opens, before its first read. Where drift shares one open database between tabs (OPFS on
     Firefox, IndexedDB), a tab opened after a deploy finds the database already open in an older tab, and drift runs
     no upgrade for it. So the studio adds photo_number itself if it is missing, as the upgrade would: one ALTER TABLE
     ADD COLUMN with the same default, no row written again; and the pictures table, if it is missing, as the schema-4
     step makes it. A normal open only reads the tables' columns; a write transaction is opened only when one is
     missing. The version number is left as it is; the upgrade, when it next
     runs, finds the column there and skips it. Not boxes.number or boxes.name: the schema-2 step also numbers her boxes
     and sets the boxNumber counter, and a box dealt a number before that would share it with one numbered then. */
  Future<void> addMissingColumns() async {
    final columns = <_Column>[(cloths, cloths.photoNumber)];
    final noPictures = (await _missing([(pictures, pictures.id)])).isNotEmpty;
    if ((await _missing(columns)).isEmpty && !noPictures) return;
    await transaction(() async {
      final m = createMigrator();
      await _addMissing(m, columns);
      if (noPictures) await m.createTable(pictures);
    });
  }

  /* Adds each of these columns its table does not have yet: the one guard every upgrade step and addMissingColumns use. */
  Future<void> _addMissing(Migrator m, List<_Column> columns) async {
    for (final (table, column) in await _missing(columns)) {
      await m.addColumn(table, column);
    }
  }

  /* The columns of these that their tables do not have, each table's columns read once (PRAGMA table_info). */
  Future<List<_Column>> _missing(List<_Column> columns) async {
    final names = <String, Set<String>>{};
    final missing = <_Column>[];
    for (final (table, column) in columns) {
      final has = names[table.actualTableName] ??= {
        for (final r in await customSelect('PRAGMA table_info(${table.actualTableName})').get()) r.read<String>('name'),
      };
      if (!has.contains(column.name)) missing.add((table, column));
    }
    return missing;
  }
}

typedef _Column = (TableInfo<Table, Object?>, GeneratedColumn<Object>);
