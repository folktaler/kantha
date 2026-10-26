import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/measure/measure.dart';
import '../support/db.dart';

const measured = Measured(lab: (l: 37.8, a: -6.3, b: -4.6), name: 'darkslategray', spread: 3.1, width: 100, height: 100);
final photo = Uint8List.fromList(List.filled(64, 7));
Measured measuredWith({double l = 50, double spread = 0}) => Measured(lab: (l: l, a: 0, b: 0), name: 'grey', spread: spread, width: 8, height: 8);
List<GridCell> grid(String id) => List.generate(35, (_) => GridCell(id, 0));
DesignInput design(String id, {String name = 'Zinnia'}) => DesignInput(name: name, layout: 'contrast', mount: 'none',
    box: 1, seed: 7, started: null, firstSolve: null, grid: grid(id));

void main() {
  test('boxes are 1, 2, … in the order she made them', () async {
    final shelf = Shelf(memoryDb());
    expect(await shelf.makeBox(), 1);
    expect(await shelf.makeBox(), 2);
    expect((await shelf.watchBoxes().first).map((b) => b.id), [1, 2]);
  });

  test('a cloth gets an id never dealt before, even after one is removed', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 3);
    final b = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Linen', pieces: 1);
    expect([a.id, b.id], ['C-1', 'C-2']);
    expect(a.name, 'C-1 Darkslategray');
    await shelf.removeCloth(b.id);
    final c = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Other', pieces: 2);
    expect(c.id, 'C-3');
  });

  /* Stored before 26 Oct, a time may hold microseconds (.123400Z), and as text it sorts before .123Z. */
  Future<void> storedAt(Shelf shelf, String table, String column, Map<String, String> at) async {
    for (final e in at.entries) {
      await shelf.db.customStatement("UPDATE $table SET $column = '${e.value}' WHERE id = '${e.key}'");
    }
  }

  test('cloth comes in the order it was added, and within one millisecond C-1 before C-2', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    for (final f in ['Cotton', 'Linen', 'Silk']) {
      await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: f, pieces: 1);
    }
    // C-1 and C-2 in one millisecond, once rounded; C-1 with the higher photo number.
    await storedAt(shelf, 'cloths', 'added',
        {'C-1': '2026-10-26T07:16:40.123Z', 'C-2': '2026-10-26T07:16:40.123400Z', 'C-3': '2026-10-26T07:16:40.122400Z'});
    await shelf.db.customStatement("UPDATE cloths SET photo_number = 99 WHERE id = 'C-1'");
    expect((await shelf.watchCloth().first).map((c) => c.id), ['C-3', 'C-1', 'C-2']);
  });

  test('a re-cropped cloth keeps its place', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    for (final f in ['Cotton', 'Linen', 'Silk']) {
      await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: f, pieces: 1);
    }
    await storedAt(shelf, 'cloths', 'added', {for (final id in ['C-1', 'C-2', 'C-3']) id: '2026-10-26T07:16:40.123Z'});
    await shelf.recrop('C-1', photo, measured);
    expect((await shelf.watchCloth().first).map((c) => c.id), ['C-1', 'C-2', 'C-3']);
  });

  test('My designs: the newest saved first, and within one millisecond P-2 before P-1', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final c = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 35);
    for (final n in ['One', 'Two', 'Three']) { await shelf.saveDesign(design(c.id, name: n)); }
    await storedAt(shelf, 'designs', 'saved',
        {'P-1': '2026-10-26T07:16:40.123Z', 'P-2': '2026-10-26T07:16:40.123400Z', 'P-3': '2026-10-26T07:16:40.122400Z'});
    expect((await shelf.watchDesigns().first).map((d) => d.id), ['P-2', 'P-1', 'P-3']);
  });

  test('every time the shelf stores has milliseconds and no microseconds', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final c = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 35);
    await shelf.saveDesign(design(c.id));
    final stored = [
      for (final q in ['SELECT made AS t FROM boxes', 'SELECT added AS t FROM cloths', 'SELECT saved AS t FROM designs'])
        ...(await shelf.db.customSelect(q).get()).map((r) => r.read<String>('t')),
    ];
    expect(stored, hasLength(3));
    for (final t in stored) { expect(t, matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$'))); }
  });

  test('a count is 1 to 500', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    for (final n in [0, 501]) {
      expect(() => shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: n),
          throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'badCount')));
    }
  });

  test('a box holds 200 cloths, and says so on the 201st', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    for (var i = 0; i < clothsPerBox; i++) {
      await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 1);
    }
    expect(() => shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 1),
        throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'boxFull').having((e) => e.values['limit'], 'limit', 200)));
  });

  test('when the device refuses the write, nothing is left half-made', () async {
    final db = memoryDb();
    final shelf = Shelf(db);
    final box = await shelf.makeBox();
    await db.customStatement("CREATE TRIGGER refuse BEFORE INSERT ON cloths BEGIN SELECT RAISE(ABORT, 'disk full'); END");
    await expectLater(shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 1),
        throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'storage')));
    expect(await shelf.watchCloth().first, isEmpty);
    await db.customStatement('DROP TRIGGER refuse');
    expect((await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 1)).id, 'C-1');
  });

  test('a re-crop keeps the id, measures again and changes the version', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 3);
    final b = await shelf.recrop(a.id, photo, const Measured(lab: (l: 90, a: 0, b: 0), name: 'white', spread: 1, width: 9, height: 9));
    expect((b.id, b.name, b.l, b.version), ('C-1', 'C-1 White', 90.0, 2));
  });

  test('a re-crop keeps a name the cloth was given (a Sample cloth\'s), and renames one made from its colour', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox(sample: true);
    final named = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 7, name: 'Madder');
    final white = const Measured(lab: (l: 90, a: 0, b: 0), name: 'white', spread: 1, width: 9, height: 9);
    final b = await shelf.recrop(named.id, photo, white);
    expect((b.name, b.colour, b.l, b.version), ('Madder', 'white', 90.0, 2));
    final auto = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 7);
    expect(auto.name, 'C-2 Darkslategray');
    expect((await shelf.recrop(auto.id, photo, white)).name, 'C-2 White');
  });

  test('saving again replaces the design it was saved as; if that is gone, it is saved as new', () async {
    final shelf = Shelf(memoryDb());
    final first = await shelf.saveDesign(design('KF-1'));
    expect((first.design.id, first.replaced), ('P-1', false));
    final again = await shelf.saveDesign(design('KF-2', name: 'Zinnia 2'), replacing: first.design.id);
    expect((again.design.id, again.replaced, again.design.name), ('P-1', true, 'Zinnia 2'));
    await shelf.deleteDesign('P-1');
    final after = await shelf.saveDesign(design('KF-2'), replacing: 'P-1');
    expect((after.design.id, after.replaced), ('P-2', false));
  });

  test('a design is 35 cloth ids, each turned 0 to 3 quarters', () async {
    final shelf = Shelf(memoryDb());
    final bad = DesignInput(name: 'x', layout: 'contrast', mount: 'none', box: 1, seed: 1, started: null, firstSolve: null,
        grid: List.generate(34, (_) => GridCell('KF-1', 0)));
    expect(() => shelf.saveDesign(bad), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'badDesign')));
  });

  test('rename and duplicate keep the grid; duplicate is a new id', () async {
    final shelf = Shelf(memoryDb());
    final p = (await shelf.saveDesign(design('KF-1'))).design;
    expect((await shelf.renameDesign(p.id, 'For Amma')).name, 'For Amma');
    final copy = await shelf.duplicateDesign(p.id, 'For Amma copy');
    expect((copy.id, copy.grid), ('P-2', p.grid));
  });

  test('an import makes this device what the backup holds, counters too; its own settings stay', () async {
    final from = Shelf(memoryDb());
    final box = await from.makeBox();
    await from.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 3);
    await from.addCloth(box: box, photo: photo, measured: measured, fabric: 'Linen', pieces: 1);
    await from.removeCloth('C-2');
    await from.saveDesign(design('C-1'));

    final here = Shelf(memoryDb());
    final mine = await here.makeBox();
    await here.addCloth(box: mine, photo: photo, measured: measured, fabric: 'Other', pieces: 9);
    await here.setSetting('language', 'ml');

    await here.replaceEverythingWith(from.db);
    expect((await here.watchCloth().first).map((c) => (c.id, c.pieces)), [('C-1', 3)]);
    expect((await here.watchDesigns().first).map((d) => d.id), ['P-1']);
    expect(await here.setting('language'), 'ml');
    expect((await here.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 1)).id, 'C-3');
    expect(await here.makeBox(), 2);
  });

  test('a new design never overwrites one already saved, even if the counter has fallen behind', () async {
    final db = memoryDb();
    final shelf = Shelf(db);
    await shelf.saveDesign(design('KF-1', name: 'Precious'));
    await db.customStatement("UPDATE counters SET next = 1 WHERE name = 'design'");
    await expectLater(shelf.saveDesign(design('KF-2', name: 'Other')), throwsA(isA<ShelfError>()));
    expect((await shelf.watchDesigns().first).map((d) => (d.id, d.name)), [('P-1', 'Precious')]);
  });

  test('an import whose counters lag its rows is raised past them, so no id is dealt twice', () async {
    final from = Shelf(memoryDb());
    final box = await from.makeBox();
    await from.makeBox();
    await from.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 3);
    await from.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 3);
    await from.saveDesign(design('C-1'));
    await from.db.customStatement('UPDATE counters SET next = 1');
    await from.db.customStatement("DELETE FROM counters WHERE name = 'design'");

    final here = Shelf(memoryDb());
    await here.replaceEverythingWith(from.db);
    expect(await here.makeBox(), 3);
    expect((await here.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 1)).id, 'C-3');
    expect((await here.saveDesign(design('C-1'))).design.id, 'P-2');
  });

  test('an import the device cannot write is undone whole', () async {
    final from = Shelf(memoryDb());
    final box = await from.makeBox();
    await from.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 3);
    final here = Shelf(memoryDb());
    final mine = await here.makeBox();
    await here.addCloth(box: mine, photo: photo, measured: measured, fabric: 'Cotton', pieces: 2);
    await here.saveDesign(design('C-1'));
    // The device refuses the cloth's write, after the old rows are already deleted inside the transaction.
    await here.db.customStatement("CREATE TRIGGER full BEFORE INSERT ON cloths BEGIN SELECT RAISE(ABORT, 'disk full'); END");
    await expectLater(here.replaceEverythingWith(from.db), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'storage')));
    expect((await here.watchCloth().first).map((c) => c.id), ['C-1']);
    expect((await here.watchBoxes().first).map((b) => b.id), [1]);
    expect((await here.watchDesigns().first).map((d) => d.id), ['P-1']);
  });

  test("an import whose cloth sits in a box it does not hold is the file's fault, and changes nothing", () async {
    final from = memoryDb();
    await from.customStatement('PRAGMA foreign_keys = OFF');
    await from.into(from.cloths).insert(ClothsCompanion.insert(id: 'C-9', box: 7, name: 'C-9 White',
        fabric: 'Cotton', pieces: 1, l: 90, a: 0, b: 0, spread: 1, colour: 'white', photo: photo, added: DateTime.now().toUtc()));
    final here = Shelf(memoryDb());
    final mine = await here.makeBox();
    await here.addCloth(box: mine, photo: photo, measured: measured, fabric: 'Cotton', pieces: 2);
    await expectLater(here.replaceEverythingWith(from), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'badImport')));
    expect((await here.watchCloth().first).map((c) => c.id), ['C-1']);
  });

  test('times are written in UTC, whatever zone the device is in', () async {
    final db = memoryDb();
    final shelf = Shelf(db);
    final box = await shelf.makeBox();
    final c = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: 'Cotton', pieces: 1);
    await shelf.recrop(c.id, photo, measured);
    final p = (await shelf.saveDesign(design('C-1'))).design;
    await shelf.renameDesign(p.id, 'For Amma');
    await shelf.duplicateDesign(p.id, 'For Amma copy');
    final stored = await db.customSelect(
        'SELECT made AS t FROM boxes UNION ALL SELECT added FROM cloths UNION ALL SELECT saved FROM designs').get();
    expect(stored.map((r) => r.read<String>('t')), everyElement(endsWith('Z')));
    expect(stored, hasLength(4));
  });

  test('a box made carries the next number; a sample box carries none and a name', () async {
    final shelf = Shelf(memoryDb());
    final a = await shelf.makeBox(), b = await shelf.makeBox();
    final s = await shelf.makeBox(sample: true);
    final rows = {for (final r in await shelf.db.select(shelf.db.boxes).get()) r.id: r};
    expect((rows[a]!.number, rows[a]!.name), (1, null));
    expect((rows[b]!.number, rows[b]!.name), (2, null));
    expect((rows[s]!.number, rows[s]!.name), (null, 'sample'));
  });

  test('a deleted box retires its number: Box 2 of three goes, the next is Box 4', () async {
    final shelf = Shelf(memoryDb());
    await shelf.makeBox(); final second = await shelf.makeBox(); await shelf.makeBox();
    await shelf.deleteBox(second, cloth: const {});
    final fourth = await shelf.makeBox();
    final rows = {for (final r in await shelf.db.select(shelf.db.boxes).get()) r.id: r.number};
    expect(rows.values.toSet(), {1, 3, 4});
    expect(rows[fourth], 4);
  });

  /* A picture for a design as it was saved: its photo and small copy stand in as a few bytes. */
  Future<void> picture(Shelf shelf, DesignRow d, int seed) => shelf.savePicture(d.id, d.saved, name: d.name,
      png: Uint8List.fromList(List.filled(32, seed)), thumb: Uint8List.fromList(List.filled(8, seed)));

  test('deleting a box that holds pieces removes it, its cloth and their photos, and the designs made from them; their '
      'pictures stay, as Picture only; another box and its designs are untouched', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox(), other = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 35);
    await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 3);
    final b = await shelf.addCloth(box: other, photo: photo, measured: measured, fabric: '', pieces: 35);
    final gone = (await shelf.saveDesign(design(a.id, name: 'Areca'))).design;
    final kept = (await shelf.saveDesign(design(b.id, name: 'Betel'))).design;
    await picture(shelf, gone, 1);
    await picture(shelf, kept, 2);

    await shelf.deleteBox(box, cloth: await shelf.clothIn(box));

    expect((await shelf.watchBoxes().first).map((x) => x.id), [other]);
    expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.id), [b.id], reason: 'its cloth, photos and all');
    expect((await shelf.watchDesigns().first).map((x) => x.name), ['Betel']);
    final pictures = await shelf.watchPictures().first;
    expect({for (final p in pictures) p.name: p.design}, {'Areca': null, 'Betel': kept.id});
    final areca = pictures.firstWhere((p) => p.name == 'Areca');
    expect(await shelf.pictureOf(areca.id), List.filled(32, 1), reason: 'the picture is whole');
    expect(await shelf.thumbOf(areca.id), List.filled(8, 1));
    await expectLater(shelf.deleteBox(99, cloth: const {}), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'noSuchBox')));
  });

  test('a box is deleted only with the cloth she was asked about: one that took more since is refused, and nothing goes',
      () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 35);
    final asked = await shelf.clothIn(box);
    await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 3);
    await expectLater(shelf.deleteBox(box, cloth: asked), throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'boxNotEmpty')));
    expect((await shelf.watchBoxes().first).map((x) => x.id), [box]);
    expect((await shelf.db.select(shelf.db.cloths).get()).map((x) => x.id), contains(a.id));
    expect(await shelf.clothIn(box), hasLength(2));
  });

  test('a box or a piece is not deleted while a design made from it has no picture of its latest save: nothing goes',
      () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 35);
    final pictured = (await shelf.saveDesign(design(a.id, name: 'Areca'))).design;
    await picture(shelf, pictured, 1);
    await shelf.saveDesign(design(a.id, name: 'Banyan')); // saved since the pictures were made
    final noPicture = throwsA(isA<ShelfError>().having((e) => e.key, 'key', 'noPicture'));
    await expectLater(shelf.deleteBox(box, cloth: await shelf.clothIn(box)), noPicture);
    await expectLater(shelf.removeCloth(a.id), noPicture);
    expect((await shelf.watchBoxes().first).map((x) => x.id), [box]);
    expect(await shelf.clothIn(box), {a.id});
    expect((await shelf.watchDesigns().first).map((x) => x.name).toSet(), {'Areca', 'Banyan'});
    expect({for (final p in await shelf.watchPictures().first) p.name: p.design}, {'Areca': pictured.id});
  });

  test('removing a piece removes the designs made from it, keeping their pictures; a design not made from it stays',
      () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 35);
    final b = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 35);
    final one = (await shelf.saveDesign(design(a.id, name: 'One'))).design;
    final two = (await shelf.saveDesign(design(a.id, name: 'Two'))).design;
    await shelf.saveDesign(design(b.id, name: 'Three'));
    await picture(shelf, one, 1);
    await picture(shelf, two, 2);
    expect(await shelf.designsUsing({a.id}), unorderedEquals([one.id, two.id]));
    await shelf.removeCloth(a.id);
    expect((await shelf.watchDesigns().first).map((x) => x.name), ['Three']);
    expect({for (final p in await shelf.watchPictures().first) p.name: p.design}, {'One': null, 'Two': null});
  });

  test('deleting a design deletes its picture; deleting a picture leaves everything else', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 35);
    final one = (await shelf.saveDesign(design(a.id, name: 'One'))).design;
    final two = (await shelf.saveDesign(design(a.id, name: 'Two'))).design;
    await picture(shelf, one, 1);
    await picture(shelf, two, 2);
    await shelf.deleteDesign(one.id);
    expect((await shelf.watchPictures().first).map((p) => p.name), ['Two']);

    await shelf.removeCloth(a.id);
    final only = (await shelf.watchPictures().first).single;
    expect(only.design, isNull);
    final cloth = await shelf.db.select(shelf.db.cloths).get(), boxes = await shelf.db.select(shelf.db.boxes).get();
    final designs = await shelf.db.select(shelf.db.designs).get(), counters = await shelf.db.select(shelf.db.counters).get();
    await shelf.deletePicture(only.id);
    expect(await shelf.watchPictures().first, isEmpty);
    expect(await shelf.pictureOf(only.id), isNull);
    expect(await shelf.db.select(shelf.db.cloths).get(), cloth);
    expect(await shelf.db.select(shelf.db.boxes).get(), boxes);
    expect(await shelf.db.select(shelf.db.designs).get(), designs);
    expect(await shelf.db.select(shelf.db.counters).get(), counters);
  });

  test('a picture replaces the one its design had and keeps the save it was made from; one made from a save since '
      'overtaken, or of a design gone, is not kept; a duplicate has none until one is made of it', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final a = await shelf.addCloth(box: box, photo: photo, measured: measured, fabric: '', pieces: 35);
    final first = (await shelf.saveDesign(design(a.id))).design;
    await picture(shelf, first, 1);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final again = (await shelf.saveDesign(design(a.id), replacing: first.id)).design;
    expect(await shelf.savePicture(first.id, first.saved, name: 'Old', png: photo, thumb: photo), isFalse,
        reason: 'saved again since');
    await picture(shelf, again, 2);
    final pictures = await shelf.watchPictures().first;
    expect(pictures.map((p) => p.design), [first.id], reason: 'one picture for the design');
    expect(await shelf.pictureOf(pictures.single.id), List.filled(32, 2));
    expect((await shelf.db.select(shelf.db.pictures).getSingle()).saved, again.saved);
    expect(await shelf.designsWithoutPicture({a.id}), isEmpty);
    final copy = await shelf.duplicateDesign(first.id, 'Zinnia copy');
    expect((await shelf.watchPictures().first).map((p) => p.design), [first.id], reason: 'no picture is copied');
    expect((await shelf.designsWithoutPicture({a.id})).map((d) => d.id), [copy.id]);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final renamed = await shelf.renameDesign(first.id, 'Mira');
    expect((await shelf.designsWithoutPicture({a.id})).map((d) => d.id).toSet(), {first.id, copy.id},
        reason: 'a rename is a save: its picture is of the save before');
    expect(await shelf.savePicture(first.id, again.saved, name: 'Zinnia', png: photo, thumb: photo), isFalse);
    expect(await shelf.savePicture(first.id, renamed.saved, name: 'Mira', png: photo, thumb: photo), isTrue);
    await shelf.deleteDesign(copy.id);
    expect(await shelf.savePicture(copy.id, copy.saved, name: 'x', png: photo, thumb: photo), isFalse, reason: 'gone');
  });

  test('an empty fabric is stored as given; a name given is kept', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final row = await shelf.addCloth(box: box, photo: photo, measured: measuredWith(l: 50, spread: 12), fabric: '', pieces: 7, name: 'Madder');
    expect((row.fabric, row.name, row.spread), ('', 'Madder', 12.0));
    await shelf.editCloth(row.id, fabric: '', pieces: 9);
    expect((await shelf.clothById(row.id))!.pieces, 9);
  });
}
