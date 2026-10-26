import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import '../measure/measure.dart';
import '../solver/geometry.dart' show cells;
import 'box_view.dart' show sampleBoxName;
import 'database.dart';

const clothsPerBox = 200;
const _sampleSwap = 'sample';

class ShelfError implements Exception {
  const ShelfError(this.key, [this.values = const {}]);
  final String key;
  final Map<String, Object> values;
  @override
  String toString() => 'ShelfError($key)';
}

class GridCell {
  const GridCell(this.id, this.rot);
  final String id;
  final int rot;
  Map<String, Object> toJson() => {'id': id, 'rot': rot};
}

class DesignInput {
  const DesignInput({required this.name, required this.layout, required this.mount, required this.box, required this.seed,
      required this.started, required this.firstSolve, required this.grid});
  final String name, layout, mount;
  final int? box, seed;
  final String? started, firstSolve;
  final List<GridCell> grid;
}

/* A cloth as the studio lists it: everything but its photo, which it names by its number (photoNumber). The photo is
   read when it is shown (photoOf), so a change to the cloth table does not read every photo again. */
typedef ClothFacts = ({String id, int box, String name, String fabric, int pieces, double l, double a, double b,
    double spread, String colour, int version, DateTime added, int photo});

/* A picture as My designs lists it: everything but its photo and small copy, read when shown. */
typedef PictureFacts = ({int id, String? design, String name, DateTime made});
/* A cloth to be added: its name, its photo and what was measured of it, and how many pieces. */
typedef NewCloth = ({String name, Uint8List photo, Measured measured, int pieces});

final _idPattern = RegExp(r'^[A-Z]+-\d+$');
String _capitalised(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/* Now, to the millisecond, for a time the shelf stores. drift stores it as Dart writes it, and Dart leaves out
   microseconds that are 0 (.123Z, not .123000Z): a time with them (.123500Z) would sort before it as text. To the
   millisecond, every time is written .123Z, as the web, whose clock has no microseconds, already wrote them. Times
   stored before 26 Oct may have microseconds, so the lists order by julianday, the moment, not the text. */
DateTime _stamp() => DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch, isUtc: true);

/* The only code that writes her boxes, cloth and designs. Every change is one
   transaction: if the device refuses a write, nothing is left half-made. */
class Shelf {
  Shelf(this.db);
  final KanthaDatabase db;

  Future<T> _write<T>(Future<T> Function() run) async {
    try {
      return await db.transaction(run);
    } on ShelfError {
      rethrow;
    } on Exception {
      throw const ShelfError('storage');
    }
  }

  /* A counter's next value; 1 for one never counted. */
  Future<int> counterAt(String name) async =>
      (await (db.select(db.counters)..where((c) => c.name.equals(name))).getSingleOrNull())?.next ?? 1;

  Future<int> _next(String name) async {
    final n = await counterAt(name);
    await db.into(db.counters).insertOnConflictUpdate(CountersCompanion.insert(name: name, next: n + 1));
    return n;
  }

  Future<int> makeBox({bool sample = false}) async => (await makeNumberedBox(sample: sample)).id;

  /* makeBox, with the number the box is given (null for a Sample box): Add a box names it before the feed lists it. */
  Future<({int id, int? number})> makeNumberedBox({bool sample = false}) => _write(() => _insertBox(sample));

  /* A box and its cloth in one write, none nested inside it: a transaction opened inside another breaks drift's
     navigator locks on the web (the inner commit hands the lock back, the outer commit then fails). Every count
     is checked before anything is written; the fabric is not asked (decision 9) and is stored as ''. */
  Future<int> addBoxWithCloth({required bool sample,
      required List<NewCloth> cloth}) async {
    for (final c in cloth) { _check(c.pieces); }
    return _write(() async {
      final box = (await _insertBox(sample)).id;
      for (final c in cloth) {
        await _insertCloth(box: box, photo: c.photo, measured: c.measured, fabric: '', pieces: c.pieces, name: c.name);
      }
      return box;
    });
  }

  /* The rows themselves, without a transaction of their own: called only from inside `_write`. A Sample box made now
     holds the real cloth, so it is marked as one that needs no swap (replaceSample). */
  Future<({int id, int? number})> _insertBox(bool sample) async {
    final id = await _next('box');
    final number = sample ? null : await _next('boxNumber');
    await db.into(db.boxes).insert(BoxesCompanion.insert(
        id: Value(id), made: _stamp(), number: Value(number), name: Value(sample ? sampleBoxName : null)));
    if (sample) await _markSampleReplaced();
    return (id: id, number: number);
  }

  /* The done-once marker of the Sample box's swap: the counter `sample` at 2. A counter, so it travels with a backup,
     and an old backup imported later is swapped on its next open. */
  Future<void> _markSampleReplaced() =>
      db.into(db.counters).insertOnConflictUpdate(CountersCompanion.insert(name: _sampleSwap, next: 2));

  Future<Set<String>> _swatchesIn(int box, Set<String> names) async =>
      (await (db.selectOnly(db.cloths)..addColumns([db.cloths.id])
            ..where(db.cloths.box.equals(box) & db.cloths.name.isIn(names)))
          .map((r) => r.read(db.cloths.id)!).get()).toSet();

  Future<int?> _sampleBox() async => (await (db.selectOnly(db.boxes)..addColumns([db.boxes.id])
        ..where(db.boxes.name.equals(sampleBoxName))..orderBy([OrderingTerm.asc(db.boxes.id)])..limit(1))
      .map((r) => r.read(db.boxes.id)!).getSingleOrNull());

  /* The ids of the drawn swatches (`names`) the Sample box still holds, re-cropped ones too: an empty set when it
     holds none, or there is no Sample box. Null once the swap is done. */
  Future<Set<String>?> swatchesToReplace(Set<String> names) async {
    if (await counterAt(_sampleSwap) >= 2) return null;
    final box = await _sampleBox();
    return box == null ? const {} : _swatchesIn(box, names);
  }

  /* The Sample box's swap (owner, 22 Oct), in one transaction with its done-once marker: the drawn swatches (`names`)
     it holds go, re-cropped ones too, with the designs made from them (their pictures stay, as Picture only; refused,
     'noPicture', and nothing changed, while any lacks a picture of its latest save), and `cloth` goes in. The box
     keeps its id and name, and cloth she photographed into it stays. A box that holds no swatch (she emptied it) and
     a Sample box she deleted stay as she left them: only the marker is written. Done already (another tab): nothing.
     Swatches found here when no `cloth` was given (the caller's first read found none, and another tab has since
     imported a backup that holds them): nothing changes and no marker is written, so the next open swaps them. */
  Future<void> replaceSample(Set<String> names,
          List<NewCloth> cloth) =>
      _write(() async {
        if (await counterAt(_sampleSwap) >= 2) return;
        final box = await _sampleBox();
        final old = box == null ? const <String>{} : await _swatchesIn(box, names);
        if (old.isNotEmpty && cloth.isEmpty) return;
        if (old.isNotEmpty) {
          for (final c in cloth) { _check(c.pieces); }
          await _dropDesignsOf(old);
          await (db.delete(db.cloths)..where((c) => c.id.isIn(old))).go();
          for (final c in cloth) {
            await _insertCloth(box: box!, photo: c.photo, measured: c.measured, fabric: '', pieces: c.pieces, name: c.name);
          }
        }
        await _markSampleReplaced();
      });

  Future<ClothRow> _insertCloth({required int box, required Uint8List photo, required Measured measured,
      required String fabric, required int pieces, String? name}) async {
    final held = await (db.select(db.boxes)..where((b) => b.id.equals(box))).getSingleOrNull();
    if (held == null) throw const ShelfError('badBox');
    final count = await (db.selectOnly(db.cloths)..addColumns([db.cloths.id.count()])..where(db.cloths.box.equals(box)))
        .map((r) => r.read(db.cloths.id.count())!).getSingle();
    if (count >= clothsPerBox) throw const ShelfError('boxFull', {'limit': clothsPerBox});
    final id = 'C-${await _next('cloth')}';
    final row = ClothsCompanion.insert(
      id: id, box: box, name: name ?? '$id ${_capitalised(measured.name)}', fabric: fabric, pieces: pieces,
      l: measured.lab.l, a: measured.lab.a, b: measured.lab.b, spread: measured.spread, colour: measured.name,
      photo: photo, added: _stamp(), photoNumber: Value(await _next('photo')),
    );
    await db.into(db.cloths).insert(row);
    return (db.select(db.cloths)..where((c) => c.id.equals(id))).getSingle();
  }

  /* A box goes with its cloth, photos and all (owner, 20 Oct), and the designs made from that cloth (_dropDesignsOf):
     their pictures stay. `cloth` is the cloth she was asked about: a box that holds any other (another tab added it,
     or the studio's copy had not caught up) is refused, 'boxNotEmpty', and nothing goes. So is one whose designs do not
     all have a picture of their latest save (one saved since the pictures were made), 'noPicture'. Its number is not
     reused. */
  Future<void> deleteBox(int id, {required Set<String> cloth}) => _write(() async {
        final row = await (db.select(db.boxes)..where((b) => b.id.equals(id))).getSingleOrNull();
        if (row == null) throw const ShelfError('noSuchBox');
        final held = await clothIn(id);
        if (!cloth.containsAll(held)) throw const ShelfError('boxNotEmpty');
        await _dropDesignsOf(held);
        await (db.delete(db.cloths)..where((c) => c.box.equals(id))).go();
        await (db.delete(db.boxes)..where((b) => b.id.equals(id))).go();
      });

  /* The ids of the cloth in this box, as stored now. */
  Future<Set<String>> clothIn(int box) async =>
      (await (db.selectOnly(db.cloths)..addColumns([db.cloths.id])..where(db.cloths.box.equals(box)))
          .map((r) => r.read(db.cloths.id)!).get()).toSet();

  /* The saved designs that use any of this cloth and have no picture of their latest save: none, or one made before
     the design was saved again or renamed. */
  Future<List<DesignRow>> designsWithoutPicture(Set<String> cloth) =>
      _write(() async => _withoutPicture(await designsUsing(cloth)));

  /* Of the designs `ids`, those with no picture of their latest save; without a transaction of its own: called only
     from inside `_write`. */
  Future<List<DesignRow>> _withoutPicture(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final designs = await (db.select(db.designs)..where((d) => d.id.isIn(ids))).get();
    final t = db.pictures;
    final pictured = await (db.selectOnly(t)..addColumns([t.design, t.saved])..where(t.design.isIn(ids)))
        .map((r) => (design: r.read(t.design)!, saved: r.read(t.saved)!)).get();
    return [
      for (final d in designs)
        if (!pictured.any((p) => p.design == d.id && p.saved.isAtSameMomentAs(d.saved))) d,
    ];
  }

  /* The ids of the saved designs that use any of this cloth. */
  Future<List<String>> designsUsing(Set<String> cloth) async {
    if (cloth.isEmpty) return const [];
    final rows = await (db.selectOnly(db.designs)..addColumns([db.designs.id, db.designs.grid])).get();
    return [
      for (final r in rows)
        if ((jsonDecode(r.read(db.designs.grid)!) as List).any((c) => cloth.contains((c as Map)['id'])))
          r.read(db.designs.id)!,
    ];
  }

  /* The designs made from this cloth go; each one's picture stays, as Picture only (design null). Refused, 'noPicture',
     and nothing dropped, while any of them has no picture of its latest save. Called only from inside `_write`. */
  Future<void> _dropDesignsOf(Set<String> cloth) async {
    final gone = await designsUsing(cloth);
    if ((await _withoutPicture(gone)).isNotEmpty) throw const ShelfError('noPicture');
    if (gone.isEmpty) return;
    await (db.update(db.pictures)..where((p) => p.design.isIn(gone))).write(const PicturesCompanion(design: Value(null)));
    await (db.delete(db.designs)..where((d) => d.id.isIn(gone))).go();
  }

  /* The fabric is stored as given, '' included: it is no longer asked (spec 2026-10-07 sample box, decision 9). */
  void _check(int pieces) {
    if (pieces < 1 || pieces > 500) throw const ShelfError('badCount');
  }

  Future<ClothRow> addCloth({required int box, required Uint8List photo, required Measured measured,
      required String fabric, required int pieces, String? name}) async {
    _check(pieces);
    return _write(() =>
        _insertCloth(box: box, photo: photo, measured: measured, fabric: fabric, pieces: pieces, name: name));
  }

  /* A name made from its colour ("C-3 Brown") follows the new measurement; a name it was given ("Madder", a Sample
     cloth's) is kept. */
  Future<ClothRow> recrop(String id, Uint8List photo, Measured measured) => _write(() async {
        final was = await (db.select(db.cloths)..where((c) => c.id.equals(id))).getSingleOrNull();
        if (was == null) throw const ShelfError('noSuchCloth');
        final name = was.name.startsWith('$id ') ? '$id ${_capitalised(measured.name)}' : was.name;
        await (db.update(db.cloths)..where((c) => c.id.equals(id))).write(ClothsCompanion(
          name: Value(name), photo: Value(photo), l: Value(measured.lab.l),
          a: Value(measured.lab.a), b: Value(measured.lab.b), spread: Value(measured.spread),
          colour: Value(measured.name), version: Value(was.version + 1), photoNumber: Value(await _next('photo')),
        ));
        return (db.select(db.cloths)..where((c) => c.id.equals(id))).getSingle();
      });

  Future<void> editCloth(String id, {required String fabric, required int pieces}) async {
    _check(pieces);
    return _write(() async {
      final n = await (db.update(db.cloths)..where((c) => c.id.equals(id)))
          .write(ClothsCompanion(fabric: Value(fabric), pieces: Value(pieces)));
      if (n == 0) throw const ShelfError('noSuchCloth');
    });
  }

  /* The cloth goes, and the designs made from it; their pictures stay (owner, 20 Oct). Refused, 'noPicture', while any
     of those designs has no picture of its latest save. */
  Future<void> removeCloth(String id) => _write(() async {
        await _dropDesignsOf({id});
        final n = await (db.delete(db.cloths)..where((c) => c.id.equals(id))).go();
        if (n == 0) throw const ShelfError('noSuchCloth');
      });

  void _checkDesign(DesignInput d) {
    if (d.grid.length != cells || d.grid.any((c) => !_idPattern.hasMatch(c.id) || c.rot < 0 || c.rot > 3)) {
      throw const ShelfError('badDesign');
    }
  }

  DesignsCompanion _row(String id, DesignInput d) => DesignsCompanion.insert(
        id: id, name: d.name, layout: d.layout, mount: d.mount, box: Value(d.box), seed: Value(d.seed),
        started: Value(d.started), firstSolve: Value(d.firstSolve),
        grid: jsonEncode([for (final c in d.grid) c.toJson()]), saved: _stamp(),
      );

  /* Saving again changes the design she saved; if she has deleted it, this is saved as a new one. */
  Future<({DesignRow design, bool replaced})> saveDesign(DesignInput d, {String? replacing}) async {
    _checkDesign(d);
    return _write(() async {
      final existing = replacing == null ? null
          : await (db.select(db.designs)..where((x) => x.id.equals(replacing))).getSingleOrNull();
      final id = existing?.id ?? 'P-${await _next('design')}';
      if (existing != null) {
        await db.update(db.designs).replace(_row(id, d));
      } else {
        await db.into(db.designs).insert(_row(id, d)); // never over a design already there
      }
      return (design: await (db.select(db.designs)..where((x) => x.id.equals(id))).getSingle(), replaced: existing != null);
    });
  }

  Future<DesignRow> renameDesign(String id, String name) => _write(() async {
        final n = await (db.update(db.designs)..where((x) => x.id.equals(id)))
            .write(DesignsCompanion(name: Value(name), saved: Value(_stamp())));
        if (n == 0) throw const ShelfError('badDesign');
        return (db.select(db.designs)..where((x) => x.id.equals(id))).getSingle();
      });

  Future<DesignRow> duplicateDesign(String id, String name) => _write(() async {
        final p = await (db.select(db.designs)..where((x) => x.id.equals(id))).getSingleOrNull();
        if (p == null) throw const ShelfError('badDesign');
        final copy = 'P-${await _next('design')}';
        // The copy's picture is its own, made by the studio once it is copied: none is copied.
        await db.into(db.designs).insert(p.copyWith(id: copy, name: name, saved: _stamp()));
        return (db.select(db.designs)..where((x) => x.id.equals(copy))).getSingle();
      });

  /* She deletes a design: its picture goes with it. */
  Future<void> deleteDesign(String id) => _write(() async {
        await (db.delete(db.pictures)..where((x) => x.design.equals(id))).go();
        await (db.delete(db.designs)..where((x) => x.id.equals(id))).go();
      });

  /* The design's picture, made from it as it was saved at `saved`, which it keeps: it replaces the one the design had.
     False, and nothing written, when the design has gone or been saved again since (renamed, too). */
  Future<bool> savePicture(String design, DateTime saved, {required String name, required Uint8List png,
      required Uint8List thumb}) => _write(() async {
        final row = await (db.select(db.designs)..where((x) => x.id.equals(design))).getSingleOrNull();
        if (row == null || !row.saved.isAtSameMomentAs(saved)) return false;
        await (db.delete(db.pictures)..where((x) => x.design.equals(design))).go();
        await db.into(db.pictures).insert(PicturesCompanion.insert(id: Value(await _next('picture')), design: Value(design),
            name: name, made: _stamp(), saved: saved, png: png, thumb: thumb));
        return true;
      });

  /* She deletes a picture, as she would a file: nothing else changes. */
  Future<void> deletePicture(int id) => _write(() => (db.delete(db.pictures)..where((x) => x.id.equals(id))).go());

  /* A picture's photo, and its small copy; null when it has gone. */
  Future<Uint8List?> pictureOf(int id) =>
      (db.selectOnly(db.pictures)..addColumns([db.pictures.png])..where(db.pictures.id.equals(id)))
          .map((r) => r.read(db.pictures.png)!).getSingleOrNull();
  Future<Uint8List?> thumbOf(int id) =>
      (db.selectOnly(db.pictures)..addColumns([db.pictures.thumb])..where(db.pictures.id.equals(id)))
          .map((r) => r.read(db.pictures.thumb)!).getSingleOrNull();

  /* One cloth as it is stored now, photo and all; null when there is no such cloth. */
  Future<ClothRow?> clothById(String id) => (db.select(db.cloths)..where((c) => c.id.equals(id))).getSingleOrNull();

  /* The photo of one cloth as it was listed: the cloth with this id, while it still holds the photo numbered `photo`
     at this version and added at this time. Null when it no longer does (removed, re-cropped, or replaced by an
     import). */
  Future<Uint8List?> photoOf(String id, int photo, int version, DateTime added) {
    final t = db.cloths;
    // `added` is compared as read, not as SQL text: a time stored in another form of the same moment still matches.
    return (db.selectOnly(t)..addColumns([t.photo, t.added])
          ..where(t.id.equals(id) & t.photoNumber.equals(photo) & t.version.equals(version)))
        .map((r) => r.read(t.added)!.isAtSameMomentAs(added) ? r.read(t.photo)! : null)
        .getSingleOrNull();
  }

  Stream<List<BoxRow>> watchBoxes() => (db.select(db.boxes)..orderBy([(b) => OrderingTerm.asc(b.id)])).watch();
  /* The number in an id made by _next, C-12 or P-12: 12. */
  static Expression<int> _number(Expression<String> id) => FunctionCallExpression<String>('substr', [id, const Constant(3)])
      .cast<int>();

  /* Every cloth, without its photo, as it changes, in the order it was added: by the moment (see _stamp), and
     cloth added within one millisecond by its number, C-1 before C-2, which neither a re-crop nor an import changes. */
  Stream<List<ClothFacts>> watchCloth() {
    final t = db.cloths;
    return (db.selectOnly(t)
          ..addColumns([t.id, t.box, t.name, t.fabric, t.pieces, t.l, t.a, t.b, t.spread, t.colour, t.version, t.added,
              t.photoNumber])
          ..orderBy([OrderingTerm.asc(t.added.julianday), OrderingTerm.asc(_number(t.id))]))
        .map((r) => (id: r.read(t.id)!, box: r.read(t.box)!, name: r.read(t.name)!, fabric: r.read(t.fabric)!,
            pieces: r.read(t.pieces)!, l: r.read(t.l)!, a: r.read(t.a)!, b: r.read(t.b)!, spread: r.read(t.spread)!,
            colour: r.read(t.colour)!, version: r.read(t.version)!, added: r.read(t.added)!, photo: r.read(t.photoNumber)!))
        .watch();
  }
  /* Every picture, without its photo or its small copy, as they change. */
  Stream<List<PictureFacts>> watchPictures() {
    final t = db.pictures;
    return (db.selectOnly(t)..addColumns([t.id, t.design, t.name, t.made])
          ..orderBy([OrderingTerm.desc(t.made.julianday), OrderingTerm.desc(t.id)]))
        .map((r) => (id: r.read(t.id)!, design: r.read(t.design), name: r.read(t.name)!, made: r.read(t.made)!))
        .watch();
  }
  /* The newest saved first: by the moment (see _stamp), and within one millisecond P-2 before P-1. */
  Stream<List<DesignRow>> watchDesigns() => (db.select(db.designs)
        ..orderBy([(x) => OrderingTerm.desc(x.saved.julianday), (x) => OrderingTerm.desc(_number(x.id))]))
      .watch();

  Future<String?> setting(String key) async =>
      (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;
  Future<void> setSetting(String key, String value) =>
      _write(() => db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value)));

  /* Import (Task 16): this device becomes exactly what `from` holds — boxes,
     cloth, designs, pictures and counters. Settings stay: they are this device's own.
     A backup whose cloth sits in a box it does not hold, or that will not
     read, is refused whole ('badImport'); 'storage' is left for this device
     refusing a write. A counter behind the ids the backup already uses is
     raised past them: the backup is still her data, and no id may be dealt
     twice. The cloth, photos and all, is copied a page at a time (`page`
     rows), so a large backup is never held in memory whole. Each photo it
     brings is given a new number, past any this device has dealt, so no
     picture shown before (in this tab or another) is taken for it. */
  Future<void> replaceEverythingWith(KanthaDatabase from, {int page = 20}) async {
    final boxes = await from.select(from.boxes).get();
    final designs = await from.select(from.designs).get();
    // Each cloth's id and box, without its photo.
    final cloth = await (from.selectOnly(from.cloths)..addColumns([from.cloths.id, from.cloths.box]))
        .map((r) => (id: r.read(from.cloths.id)!, box: r.read(from.cloths.box)!)).get();
    // A cloth in a box the backup does not hold is the file's fault, not this device's: refused before anything is touched.
    final held = {for (final b in boxes) b.id};
    if (cloth.any((c) => !held.contains(c.box))) throw const ShelfError('badImport');
    final next = {for (final c in await from.select(from.counters).get()) c.name: c.next};
    void atLeast(String name, Iterable<int> used) {
      for (final n in used) {
        if (n >= (next[name] ?? 1)) next[name] = n + 1;
      }
    }
    int? numbered(String prefix, String id) {
      final m = RegExp('^$prefix-(\\d+)\$').firstMatch(id);
      return m == null ? null : int.parse(m.group(1)!);
    }
    atLeast('box', boxes.map((b) => b.id));
    atLeast('boxNumber', [for (final b in boxes) if (b.number != null) b.number!]);
    atLeast('cloth', cloth.map((c) => numbered('C', c.id)).nonNulls);
    atLeast('design', designs.map((d) => numbered('P', d.id)).nonNulls);
    atLeast('picture', await (from.selectOnly(from.pictures)..addColumns([from.pictures.id]))
        .map((r) => r.read(from.pictures.id)!).get());
    await _write(() async {
      var photo = math.max(await counterAt('photo'), next['photo'] ?? 1);
      await db.delete(db.pictures).go();
      await db.delete(db.designs).go();
      await db.delete(db.cloths).go();
      await db.delete(db.boxes).go();
      await db.delete(db.counters).go();
      await db.batch((b) {
        b.insertAll(db.boxes, boxes);
        b.insertAll(db.designs, designs);
      });
      for (var at = 0;; at += page) {
        final List<ClothRow> rows;
        try {
          rows = await (from.select(from.cloths)..orderBy([(c) => OrderingTerm.asc(c.id)])..limit(page, offset: at)).get();
        } on Exception {
          throw const ShelfError('badImport'); // the file would not read: undone whole, and not blamed on this device
        }
        if (rows.isNotEmpty) await db.batch((b) => b.insertAll(db.cloths, [for (final r in rows) r.copyWith(photoNumber: photo++)]));
        if (rows.length < page) break;
      }
      // The pictures a few at a time: each holds a full-size photo.
      for (var at = 0;; at += _picturePage) {
        final List<PictureRow> rows;
        try {
          rows = await _picturesAt(from, at);
        } on Exception {
          throw const ShelfError('badImport');
        }
        if (rows.isNotEmpty) await db.batch((b) => b.insertAll(db.pictures, rows));
        if (rows.length < _picturePage) break;
      }
      next['photo'] = photo;
      await db.batch((b) => b.insertAll(db.counters, [for (final e in next.entries) CounterRow(name: e.key, next: e.value)]));
    });
  }
}

/* Pictures are copied this many at a time: each holds a full-size photo. */
const _picturePage = 4;
Future<List<PictureRow>> _picturesAt(KanthaDatabase from, int at) =>
    (from.select(from.pictures)..orderBy([(p) => OrderingTerm.asc(p.id)])..limit(_picturePage, offset: at)).get();

/* The pictures in `from`, a few at a time, so only a few full-size photos are held at once (a backup is made so). */
Future<void> picturePages(KanthaDatabase from, Future<void> Function(List<PictureRow>) each) async {
  for (var at = 0;; at += _picturePage) {
    final rows = await _picturesAt(from, at);
    if (rows.isNotEmpty) await each(rows);
    if (rows.length < _picturePage) return;
  }
}
