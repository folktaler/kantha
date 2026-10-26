import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/data/backup.dart';
import 'package:kantha_studio/data/side_db_io.dart';
import 'package:kantha_studio/downloads/cloth_images.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/studio/shelf_feed.dart';
import '../support/db.dart';
import '../support/studio_fixture.dart';

void main() {
  test('a cloth stored with spread 12 feeds as busy with edge 0.06; spread 0 feeds plain', () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    await shelf.addCloth(box: box, photo: fixtureJpeg, measured: measuredFor(spread: 12), fabric: '', pieces: 1);
    await shelf.addCloth(box: box, photo: fixtureJpeg, measured: measuredFor(spread: 0), fabric: '', pieces: 1);
    final s = await shelfNow(shelf);
    expect([for (final c in s.cloth) c.busy], [true, false]);
    expect(s.cloth.first.edge, closeTo(0.06, 1e-9));
    expect(s.cloth.last.edge, 0.0);
    expect(s.boxes.single, isA<BoxView>().having((b) => b.number, 'number', 1).having((b) => b.sample, 'sample', false));
  });

  test("the watched list carries no photo; each cloth's photo is read by its id and the photo's number when it is shown",
      () async {
    final shelf = Shelf(memoryDb());
    final box = await shelf.makeBox();
    final row = await shelf.addCloth(box: box, photo: fixtureJpeg, measured: measuredFor(spread: 0), fabric: '', pieces: 1);
    final watched = (await shelf.watchCloth().first).single;
    expect(watched, isNot(isA<ClothRow>()), reason: 'a record of the cloth without its photo column');
    final s = await shelfNow(shelf);
    final image = s.cloth.single.image! as ClothPhoto;
    expect((image.id, image.photo), (row.id, row.photoNumber));
    expect(row.photoNumber, greaterThan(0), reason: 'a photo stored now is numbered');
    expect(await image.bytes(), fixtureJpeg);
    expect(image, ClothPhoto(shelf, row.id, row.photoNumber, row.version, row.added), reason: 'the same photo is the same picture');
    expect(image, isNot(ClothPhoto(shelf, row.id, row.photoNumber + 1, row.version, row.added)),
        reason: 'another photo is another picture');
    expect(await ClothPhoto(shelf, row.id, row.photoNumber + 1, row.version, row.added).bytes(), isNull,
        reason: 'a picture names its photo: one the cloth does not hold reads nothing');
    await shelf.recrop(row.id, img.encodeJpg(img.Image(width: 8, height: 8)), measuredFor(spread: 0));
    expect(await image.bytes(), isNull, reason: "after a re-crop, the old photo's picture reads nothing, not the new photo");
    await shelf.removeCloth(row.id);
    expect(await image.bytes(), isNull);
    expect(image, isA<ImageProvider>());
  });

  /* A JPEG `w` × `h`, all one grey `v`. */
  Uint8List jpeg(int w, int h, int v) => img.encodeJpg(img.Image(width: w, height: h)..clear(img.ColorRgb8(v, v, v)));

  testWidgets('a backup that reuses ids (C-1 at version 1 is another cloth there) shows its own photo, not this '
      "device's", (tester) async {
    final side = IoSideDb(Directory.systemTemp);
    final here = Shelf(memoryDb()), there = Shelf(memoryDb());
    final (before, after) = (jpeg(40, 20, 30), jpeg(24, 36, 220));
    final file = (await tester.runAsync(() async {
      await here.addCloth(box: await here.makeBox(), photo: before, measured: measuredFor(), fabric: '', pieces: 1);
      await there.addCloth(box: await there.makeBox(), photo: after, measured: measuredFor(), fabric: '', pieces: 1);
      return exportBackup(there.db, side);
    }))!;
    Future<ClothView> shown() async {
      final view = (await tester.runAsync(() => shelfNow(here)))!.cloth.single;
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Image(image: view.image!)));
      for (var i = 0; i < 50 && tester.widget<RawImage>(find.byType(RawImage)).image == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      return view;
    }
    (int, int) size() { final i = tester.widget<RawImage>(find.byType(RawImage)).image!; return (i.width, i.height); }

    final old = await shown();
    expect(size(), (40, 20));
    await tester.runAsync(() => importBackup(file, here, side));
    final now = await shown();
    expect((now.id, now.version), (old.id, old.version), reason: 'the same id and version as the cloth it replaced');
    expect(now.image, isNot(old.image));
    expect(size(), (24, 36), reason: "the backup's photo, not the one cached before");
    final images = ClothImages();
    expect(await tester.runAsync(() => images.jpeg(now)), after, reason: 'and the files embed it');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a cloth gone from the shelf while its square is drawn shows nothing, and nothing is reported', (tester) async {
    final shelf = Shelf(memoryDb());
    final view = (await tester.runAsync(() async {
      final row = await shelf.addCloth(box: await shelf.makeBox(), photo: fixtureJpeg, measured: measuredFor(), fabric: '', pieces: 1);
      final v = (await shelfNow(shelf)).cloth.single;
      await shelf.removeCloth(row.id);
      return v;
    }))!;
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Image(image: view.image!)));
    for (var i = 0; i < 50 && tester.widget<RawImage>(find.byType(RawImage)).image == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    final shown = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect((shown.width, shown.height), (1, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('two tabs on one database: a backup imported in one, the other shows the photo the backup brought',
      (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = Directory.systemTemp.createTempSync('kantha_tabs_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite');
    final side = IoSideDb(dir);
    final tabA = Shelf(KanthaDatabase(NativeDatabase(file))), tabB = Shelf(KanthaDatabase(NativeDatabase(file)));
    final there = Shelf(memoryDb());
    final (before, after) = (jpeg(40, 20, 30), jpeg(24, 36, 220));
    final backup = (await tester.runAsync(() async {
      await tabA.addCloth(box: await tabA.makeBox(), photo: before, measured: measuredFor(), fabric: '', pieces: 1);
      await there.addCloth(box: await there.makeBox(), photo: after, measured: measuredFor(), fabric: '', pieces: 1);
      return exportBackup(there.db, side);
    }))!;
    Future<ClothView> shownInB() async {
      final view = (await tester.runAsync(() => shelfNow(tabB)))!.cloth.single;
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Image(image: view.image!)));
      await decoded(tester);
      return view;
    }

    final old = await shownInB();
    expect(size(tester), (40, 20));
    await tester.runAsync(() => importBackup(backup, tabA, side));
    final now = await shownInB();
    expect((now.id, now.version), (old.id, old.version), reason: 'the same id and version as the cloth it replaced');
    expect(now.image, isNot(old.image));
    expect(size(tester), (24, 36), reason: "the backup's photo in the other tab, not the one it cached before");
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await tabA.db.close();
      await tabB.db.close();
    });
  });

  testWidgets('a backup made on this device, imported, then re-cropped: the new photo is shown and embedded, not the '
      "re-crop's from before the import", (tester) async {
    final side = IoSideDb(Directory.systemTemp);
    final shelf = Shelf(memoryDb());
    final images = ClothImages();
    final (first, x, y) = (jpeg(40, 20, 30), jpeg(24, 36, 220), jpeg(30, 50, 140));
    final backup = (await tester.runAsync(() async {
      await shelf.addCloth(box: await shelf.makeBox(), photo: first, measured: measuredFor(), fabric: '', pieces: 1);
      return exportBackup(shelf.db, side);
    }))!;
    Future<ClothView> recropped(Uint8List photo) async {
      final view = (await tester.runAsync(() async {
        await shelf.recrop('C-1', photo, measuredFor());
        return (await shelfNow(shelf)).cloth.single;
      }))!;
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Image(image: view.image!)));
      await decoded(tester);
      return view;
    }

    final before = await recropped(x);
    expect(size(tester), (24, 36));
    expect(await tester.runAsync(() => images.jpeg(before)), x);
    await tester.runAsync(() => importBackup(backup, shelf, side));
    final after = await recropped(y);
    expect((after.id, after.version), (before.id, before.version), reason: 'the same id and version as before the import');
    expect(after.image, isNot(before.image));
    expect(size(tester), (30, 50), reason: 'the new photo, not the one decoded before the import');
    expect(await tester.runAsync(() => images.jpeg(after)), y, reason: 'and the files embed it');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  /* As a tab still on the code from before photo numbers re-crops: it raises the version and leaves photo_number. */
  testWidgets('a cloth re-cropped with its version raised and its photo number unchanged shows and embeds the new photo',
      (tester) async {
    final shelf = Shelf(memoryDb());
    final images = ClothImages();
    final (first, second) = (jpeg(40, 20, 30), jpeg(24, 36, 220));
    Future<ClothView> shown() async {
      final view = (await tester.runAsync(() => shelfNow(shelf)))!.cloth.single;
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Image(image: view.image!)));
      await decoded(tester);
      return view;
    }

    final row = (await tester.runAsync(() async =>
        shelf.addCloth(box: await shelf.makeBox(), photo: first, measured: measuredFor(), fabric: '', pieces: 1)))!;
    final before = await shown();
    expect(size(tester), (40, 20));
    expect(await tester.runAsync(() => images.jpeg(before)), first);
    await tester.runAsync(() => shelf.db.customUpdate('UPDATE cloths SET photo = ?, version = version + 1 WHERE id = ?',
        variables: [Variable.withBlob(second), Variable.withString(row.id)]));
    final after = await shown();
    expect((after.image! as ClothPhoto).photo, row.photoNumber, reason: 'the photo number as it was');
    expect(after.version, before.version + 1);
    expect(after.image, isNot(before.image));
    expect(size(tester), (24, 36), reason: 'the new photo, not the one decoded before');
    expect(await tester.runAsync(() => images.jpeg(after)), second, reason: 'and the files embed it');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('two tabs on one database: one imports a backup made there and re-crops; the other shows the new photo',
      (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = Directory.systemTemp.createTempSync('kantha_tabs_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite');
    final side = IoSideDb(dir);
    final tabA = Shelf(KanthaDatabase(NativeDatabase(file))), tabB = Shelf(KanthaDatabase(NativeDatabase(file)));
    final images = ClothImages();
    final (first, x, y) = (jpeg(40, 20, 30), jpeg(24, 36, 220), jpeg(30, 50, 140));
    final backup = (await tester.runAsync(() async {
      await tabA.addCloth(box: await tabA.makeBox(), photo: first, measured: measuredFor(), fabric: '', pieces: 1);
      final b = await exportBackup(tabA.db, side);
      await tabA.recrop('C-1', x, measuredFor());
      return b;
    }))!;
    Future<List<ClothView>> shownInB(List<ClothView> held) async {
      final now = stableCloth(held, (await tester.runAsync(() => shelfNow(tabB)))!.cloth);
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Image(image: now.single.image!)));
      await decoded(tester);
      return now;
    }

    final old = await shownInB(const []);
    expect(size(tester), (24, 36));
    expect(await tester.runAsync(() => images.jpeg(old.single)), x);
    await tester.runAsync(() async {
      await importBackup(backup, tabA, side);
      await tabA.recrop('C-1', y, measuredFor());
    });
    final now = await shownInB(old);
    expect((now.single.id, now.single.version), (old.single.id, old.single.version),
        reason: 'the same id and version as the cloth the other tab showed');
    expect(now.single.image, isNot(old.single.image));
    expect(size(tester), (30, 50), reason: 'the new photo in the other tab, not the one it decoded before');
    expect(await tester.runAsync(() => images.jpeg(now.single)), y, reason: 'and its files embed it');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await tabA.db.close();
      await tabB.db.close();
    });
  });

  testWidgets('a cloth removed while its square is drawn keeps its photo, decoded again at another size', (tester) async {
    final shelf = Shelf(memoryDb());
    final first = (await tester.runAsync(() async {
      await shelf.addCloth(box: await shelf.makeBox(), photo: jpeg(40, 40, 90), measured: measuredFor(), fabric: '', pieces: 1);
      return (await shelfNow(shelf)).cloth;
    }))!;
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Image(image: first.single.image!)));
    await decoded(tester);
    // The shelf answers again (the cloth renamed: another view, the same picture), then the cloth is removed.
    final renamed = (await tester.runAsync(() async {
      await shelf.db.customStatement("UPDATE cloths SET name = 'Other'");
      return (await shelfNow(shelf)).cloth;
    }))!;
    final kept = stableCloth(first, renamed);
    expect(identical(kept.single, first.single), isFalse);
    await tester.runAsync(() => shelf.removeCloth(kept.single.id));
    final gone = stableCloth(kept, const []).single;
    expect((gone.box, gone.stock), (null, 0));
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr,
        child: Image(image: ResizeImage(gone.image!, width: 20, height: 20, policy: ResizeImagePolicy.fit))));
    await decoded(tester);
    expect(size(tester), (20, 20), reason: 'its own photo, not the clear 1 × 1 of a cloth never read');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a photo shown at two sizes is read from the shelf once', (tester) async {
    final shelf = _CountingShelf(memoryDb());
    final view = (await tester.runAsync(() async {
      await shelf.addCloth(box: await shelf.makeBox(), photo: jpeg(40, 40, 90), measured: measuredFor(), fabric: '', pieces: 1);
      return (await shelfNow(shelf)).cloth.single;
    }))!;
    for (final side in [64, 128]) {
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr,
          child: Image(image: ResizeImage(view.image!, width: side, height: side, policy: ResizeImagePolicy.fit))));
      for (var i = 0; i < 50 && tester.widget<RawImage>(find.byType(RawImage)).image == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    }
    expect(shelf.reads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("the board's square and the dock's swatch, decoded in the same frame, share one read of the shelf",
      (tester) async {
    final shelf = _CountingShelf(memoryDb());
    final view = (await tester.runAsync(() async {
      await shelf.addCloth(box: await shelf.makeBox(), photo: jpeg(200, 200, 90), measured: measuredFor(), fabric: '', pieces: 1);
      return (await shelfNow(shelf)).cloth.single;
    }))!;
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Row(children: [
      for (final side in [64, 128]) Image(image: ResizeImage(view.image!, width: side, height: side, policy: ResizeImagePolicy.fit)),
    ])));
    for (var i = 0; i < 50 && tester.widgetList<RawImage>(find.byType(RawImage)).any((r) => r.image == null); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect([for (final r in tester.widgetList<RawImage>(find.byType(RawImage))) (r.image!.width, r.image!.height)],
        [(64, 64), (128, 128)]);
    expect(shelf.reads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test("two tabs on one database: after a backup that reuses ids is imported in one, the other's restock takes the "
      "backup's photo", () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = Directory.systemTemp.createTempSync('kantha_tabs_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/kantha.sqlite');
    final side = IoSideDb(dir);
    final tabA = Shelf(KanthaDatabase(NativeDatabase(file))), tabB = Shelf(KanthaDatabase(NativeDatabase(file)));
    addTearDown(() async {
      await tabA.db.close();
      await tabB.db.close();
    });
    final there = Shelf(memoryDb());
    final (before, after) = (jpeg(40, 20, 30), jpeg(24, 36, 220));
    await tabA.addCloth(box: await tabA.makeBox(), photo: before, measured: measuredFor(), fabric: '', pieces: 1);
    await there.addCloth(box: await there.makeBox(), photo: after, measured: measuredFor(), fabric: '', pieces: 1);
    final backup = await exportBackup(there.db, side);
    final held = (await shelfNow(tabB)).cloth;
    await importBackup(backup, tabA, side);
    final now = (await shelfNow(tabB)).cloth;
    expect((now.single.id, now.single.version, now.single.name, now.single.stock, now.single.box, now.single.lab),
        (held.single.id, held.single.version, held.single.name, held.single.stock, held.single.box, held.single.lab),
        reason: 'the backup brings the same id, version, name, count, box and colour: only its photo differs');
    final restocked = stableCloth(held, now).single;
    expect(restocked.image, now.single.image);
    expect(await (restocked.image! as ClothPhoto).bytes(), after);
  });
}

class _CountingShelf extends Shelf {
  _CountingShelf(super.db);
  var reads = 0;
  @override
  Future<Uint8List?> photoOf(String id, int photo, int version, DateTime added) {
    reads++;
    return super.photoOf(id, photo, version, added);
  }
}

/* Pumps until the one Image on screen has its picture. */
Future<void> decoded(WidgetTester tester) async {
  for (var i = 0; i < 50 && tester.widget<RawImage>(find.byType(RawImage)).image == null; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

(int, int) size(WidgetTester tester) {
  final i = tester.widget<RawImage>(find.byType(RawImage)).image!;
  return (i.width, i.height);
}
