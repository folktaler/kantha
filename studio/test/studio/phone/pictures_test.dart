import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/downloads/photo_png.dart' show photoWidth, photoHeight, thumbWidth, thumbHeight;
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/phone/phone_sheet.dart';
import 'package:kantha_studio/studio/take_menus.dart';
import '../../support/db.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';

/* A saved design and its picture (owner, 20 Oct 2026): the picture is Save photo's photo, made at every save and shown
   small in My designs; when the design's pieces go (Delete box, Remove this piece) the design goes and its picture
   stays, as Picture only, opened by View with Save photo and Share…; she deletes a picture as a file, and a design she
   deletes takes its picture with it. */

Finder inRow(String words) => find.descendant(of: find.byType(SheetRow), matching: find.text(words));
Finder inDialog(String words) => find.descendant(of: find.byType(AlertDialog), matching: find.text(words));

/* `run`, finished while the test's frames are drawn: a picture waits for a frame between its photo and its small copy,
   which tester.runAsync alone never draws. */
Future<T> finish<T>(WidgetTester tester, Future<T> Function() run) async {
  late T out;
  Object? failed;
  var done = false;
  run().then((v) { out = v; done = true; }, onError: (Object e) { failed = e; done = true; });
  await letWork(tester, done: () => done, turns: 300);
  expect(done, isTrue, reason: 'it finished');
  if (failed != null) throw failed!;
  return out;
}

/* A shelf on which another tab saves `meanwhile` just after the studio has found every design pictured, before the
   delete itself. */
class SavesMeanwhile extends Shelf {
  SavesMeanwhile(super.db);
  DesignInput? meanwhile;
  @override
  Future<List<DesignRow>> designsWithoutPicture(Set<String> cloth) async {
    final out = await super.designsWithoutPicture(cloth);
    final d = meanwhile;
    if (out.isEmpty && d != null) {
      meanwhile = null;
      await saveDesign(d);
    }
    return out;
  }
}

/* A shelf that says what a box holds only once the test lets it. */
class SlowClothIn extends Shelf {
  SlowClothIn(super.db);
  Completer<void>? gate;
  @override
  Future<Set<String>> clothIn(int box) async {
    await gate?.future;
    return super.clothIn(box);
  }
}

/* The studio on a phone, drawing each save's picture as the app does (KanthaApp leaves a test's controller as it is). */
Future<StudioController> pumpDrawing(WidgetTester tester, CaptureDelivery delivery) async {
  final c = await pumpStudio(tester, size: phone, delivery: delivery);
  final t = TakeAway(delivery: delivery);
  c.drawPicture = (d) => t.picture(c, d);
  return c;
}

/* Saved under `name`, and its picture made and listed. */
Future<void> saveDrawn(WidgetTester tester, StudioController c, String name) async {
  await saveAs(tester, c, name);
  expect(await finish(tester, () => c.pictureMaking!), isTrue, reason: 'its picture was made');
  await letWork(tester, done: () => c.pictureOf(c.savedId!) != null);
}

Future<void> openDesigns(WidgetTester tester) async {
  await tester.tap(key('phone-title'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('each save makes the picture Save photo makes, and its small copy; My designs shows it at its row\'s size',
      (tester) async {
    final d = CaptureDelivery();
    final c = await pumpDrawing(tester, d);
    await saveDrawn(tester, c, 'Areca');
    final p = c.pictureOf(c.savedId!)!;
    final png = (await tester.runAsync(() => c.shelf.pictureOf(p.id)))!;
    final photo = img.decodePng(png)!;
    expect((photo.width, photo.height), (photoWidth, photoHeight));
    final thumb = img.decodePng((await tester.runAsync<Uint8List?>(() => c.shelf.thumbOf(p.id)))!)!;
    expect((thumb.width, thumb.height), (thumbWidth, thumbHeight));
    await openDesigns(tester);
    final shown = tester.widget<Image>(find.descendant(of: key('thumb-${p.id}'), matching: find.byType(Image)));
    expect(shown.image, isA<ResizeImage>().having((r) => (r.width, r.height), 'decoded at', (38, 48)),
        reason: 'decoded at the drawn size (one device pixel a point here), never the full photo');
    expect(tester.getSize(key('thumb-${p.id}')), const Size(38, 48));
  });

  testWidgets('a design saved before pictures shows its row with an empty frame', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await saveAs(tester, c, 'Areca'); // no drawPicture: as a design saved before this change
    expect(c.pictures, isEmpty);
    await openDesigns(tester);
    expect(inRow('Areca'), findsOneWidget);
    expect(inRow('Open'), findsOneWidget);
    expect(inSheet(find.byType(Image)), findsNothing);
  });

  testWidgets('Delete box on a box that holds pieces asks in his words, then removes the box, its cloth and photos; the '
      'designs made from them go and their pictures stay, as Picture only, one saved before pictures among them', (tester) async {
    final d = CaptureDelivery();
    final c = await pumpDrawing(tester, d);
    final box = c.box!;
    await saveDrawn(tester, c, 'Areca');
    // Banyan as a design saved before this change: no picture, until one is made just before its cloth goes.
    final draw = c.drawPicture;
    c.drawPicture = null;
    c.newDesign();
    await letWork(tester, done: () => !c.solving && c.grid != null);
    await saveAs(tester, c, 'Banyan');
    expect(c.pictureOf(c.savedId!), isNull);
    c.drawPicture = draw;
    final cloth = {for (final x in c.cloth) if (x.box == box) x.id};

    await tester.tap(key('tab-cloth'));
    await tester.pumpAndSettle();
    await tapShown(tester, key('delete-box'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Box 1 and its pieces?'), findsOneWidget);
    await tester.tap(inDialog('Delete'));
    await letWork(tester, done: () => !c.ownBoxes.contains(box) && c.saved.isEmpty, turns: 300);

    expect(c.ownBoxes, isNot(contains(box)));
    final rows = (await tester.runAsync(() => c.shelf.db.select(c.shelf.db.cloths).get()))!;
    expect(rows.where((r) => cloth.contains(r.id)), isEmpty, reason: 'its cloth, photos and all');
    expect(c.saved, isEmpty);
    expect({for (final p in c.pictures) p.name: p.design}, {'Areca': null, 'Banyan': null});
    await openDesigns(tester);
    expect(inRow('Picture only'), findsNWidgets(2));
    expect(inRow('View'), findsNWidgets(2));
    expect(inRow('Open'), findsNothing);
  });

  testWidgets('the Sample box with pieces asks in its own words', (tester) async {
    final c = await pumpOnSample(tester, size: phone);
    await tester.tap(key('tab-cloth'));
    await tester.pumpAndSettle();
    await tapShown(tester, key('delete-box'));
    await tester.pumpAndSettle();
    expect(find.text('Delete the Sample box and its pieces?'), findsOneWidget);
    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();
    expect(c.sampleBox, isNotNull, reason: 'Cancel keeps it');
  });

  testWidgets('Remove this piece on a piece saved designs use says how many stay as pictures; then they do', (tester) async {
    final c = await pumpDrawing(tester, CaptureDelivery());
    await saveDrawn(tester, c, 'Areca');
    expect(await finish(tester, () => c.duplicate(c.saved.single)), isTrue);
    expect(await finish(tester, () => c.pictureMaking!), isTrue);
    await letWork(tester, done: () => c.saved.length == 2 && c.pictures.length == 2);
    final id = c.saved.first.grid.first;
    expect(c.designsUsing({id}), hasLength(2));

    await tester.tap(key('tab-cloth'));
    await tester.pumpAndSettle();
    await tapShown(tester, key('swatch-$id'));
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    await tapShown(tester, inSheet(find.text('Remove this piece')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this piece? 2 saved patterns using it stay as pictures. They can’t be changed or printed.'),
        findsOneWidget);
    expect(c.words.clothRemoveUsed(1),
        'Remove this piece? 1 saved pattern using it stays as a picture. It can’t be changed or printed.');
    await tester.tap(inDialog('Remove this piece'));
    await letWork(tester, done: () => c.saved.isEmpty && sheet.evaluate().isEmpty, turns: 300);
    expect(c.pictures.map((p) => p.design), [null, null]);
  });

  testWidgets('a Picture only row opens View: the picture, Save photo and Share…, each handing over the picture as '
      'stored', (tester) async {
    final d = CaptureDelivery();
    final c = await pumpDrawing(tester, d);
    await saveDrawn(tester, c, 'Areca');
    final p = c.pictureOf(c.savedId!)!;
    await finish(tester, () => c.removeCloth(c.saved.single.grid.first));
    await letWork(tester, done: () => c.saved.isEmpty);
    final png = (await tester.runAsync(() => c.shelf.pictureOf(p.id)))!;
    await openDesigns(tester);
    expect(inRow('Picture only'), findsOneWidget);
    await tester.tap(inRow('View'));
    await letWork(tester, done: () => find.descendant(of: key('picture-view'), matching: find.byType(Image)).evaluate().isNotEmpty);
    expect(find.text('Areca'), findsWidgets, reason: 'titled with its name');
    expect(inRow('Save photo'), findsOneWidget);
    expect(inRow('Share…'), findsOneWidget);
    await tester.tap(inRow('Save photo'));
    await letWork(tester, done: () => d.saved.isNotEmpty);
    expect(d.saved, ['areca.png']);
    expect(d.bytes['areca.png'], png);
    await tester.tap(inRow('View'));
    await letWork(tester, done: () => inRow('Share…').evaluate().isNotEmpty && idle(tester));
    await letWork(tester, done: () => find.descendant(of: key('picture-view'), matching: find.byType(Image)).evaluate().isNotEmpty);
    await tester.tap(inRow('Share…'));
    await letWork(tester, done: () => d.shared.isNotEmpty);
    expect(d.shared, ['areca.png']);
  });

  testWidgets('deleting a design deletes its picture', (tester) async {
    final c = await pumpDrawing(tester, CaptureDelivery());
    await saveDrawn(tester, c, 'Areca');
    await openDesigns(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await tester.tap(inRow('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Delete'));
    await letWork(tester, done: () => c.saved.isEmpty && c.pictures.isEmpty);
    expect(c.pictures, isEmpty);
    expect((await tester.runAsync(() => c.shelf.db.select(c.shelf.db.pictures).get()))!, isEmpty);
  });

  testWidgets('deleting a Picture only picture leaves everything else: boxes, cloth, designs and the other pictures',
      (tester) async {
    final c = await pumpDrawing(tester, CaptureDelivery());
    await saveDrawn(tester, c, 'Areca');
    await finish(tester, () => c.removeCloth(c.saved.single.grid.first));
    await letWork(tester, done: () => c.saved.isEmpty);
    c.newDesign();
    await letWork(tester, done: () => !c.solving && c.grid != null);
    await saveDrawn(tester, c, 'Banyan');
    final db = c.shelf.db;
    Future<List<Object>> everything() async => [
          ...await db.select(db.boxes).get(), ...await db.select(db.cloths).get(), ...await db.select(db.designs).get(),
          ...await db.select(db.counters).get(), ...await db.select(db.settings).get(),
        ];
    final before = (await tester.runAsync(everything))!;
    final banyan = c.pictureOf(c.savedId!)!;
    await openDesigns(tester);
    // Banyan, saved last, first; Areca, Picture only, under it.
    expect(tester.getTopLeft(inRow('Picture only')).dy, greaterThan(tester.getTopLeft(inRow('Banyan')).dy));
    await tester.tap(find.bySemanticsLabel('More').at(1));
    await tester.pumpAndSettle();
    await tester.tap(inRow('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Areca”? This cannot be undone.'), findsOneWidget);
    await tester.tap(inDialog('Delete'));
    await letWork(tester, done: () => c.pictures.length == 1);
    expect(c.pictures.map((p) => p.id), [banyan.id]);
    expect((await tester.runAsync(everything))!, before);
    expect(inRow('Picture only'), findsNothing);
    expect(inRow('Banyan'), findsOneWidget);
  });

  testWidgets('a rename makes its picture again, captioned with the name she sees', (tester) async {
    final c = await pumpDrawing(tester, CaptureDelivery());
    await saveDrawn(tester, c, 'Areca');
    final id = c.savedId!;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    expect(await finish(tester, () => c.rename(c.saved.single, 'Mira')), isTrue);
    expect(await finish(tester, () => c.pictureMaking!), isTrue, reason: 'its picture was made');
    await letWork(tester, done: () => c.pictures.single.name == 'Mira');
    expect([for (final p in c.pictures) (p.name, p.design)], [('Mira', id)]);
    expect(await tester.runAsync(() => c.shelf.designsWithoutPicture(c.saved.single.grid.toSet())), isEmpty);
  });

  testWidgets('a duplicate gets a picture of its own, captioned with its own name', (tester) async {
    final c = await pumpDrawing(tester, CaptureDelivery());
    await saveDrawn(tester, c, 'Areca');
    final id = c.savedId!;
    expect(await finish(tester, () => c.duplicate(c.saved.single)), isTrue);
    expect(await finish(tester, () => c.pictureMaking!), isTrue, reason: 'its picture was made');
    await letWork(tester, done: () => c.saved.length == 2 && c.pictures.length == 2);
    final copy = c.saved.firstWhere((d) => d.id != id);
    expect({for (final p in c.pictures) p.name: p.design}, {'Areca': id, 'Areca copy': copy.id});
    expect(await tester.runAsync(() => c.shelf.designsWithoutPicture(copy.grid.toSet())), isEmpty);
  });

  /* A picture belongs to one save of a design: before its cloth goes, each design has a picture of its latest save. */
  group('before a delete', () {
    Future<Set<String>> clothOf(WidgetTester tester, StudioController c, int box) async =>
        (await tester.runAsync(() => c.shelf.clothIn(box)))!;
    Future<Uint8List> pngOf(WidgetTester tester, StudioController c, int picture) async =>
        (await tester.runAsync(() => c.shelf.pictureOf(picture)))!;

    testWidgets('a design whose copy in the studio is stale still gets a picture of its latest save', (tester) async {
      final c = await pumpStudio(tester, size: phone, delivery: CaptureDelivery());
      final box = c.box!;
      await saveAs(tester, c, 'Areca'); // saved before pictures: none
      final stale = c.saved.single;
      final t = TakeAway(delivery: CaptureDelivery());
      c.drawPicture = (d) => t.picture(c, d);
      final cloth = await clothOf(tester, c, box);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await c.shelf.renameDesign(stale.id, 'Mira'); // as another tab renames it
      });
      c.saved = [stale]; // before this tab's copy has caught up
      expect(await finish(tester, () => c.deleteBox(box, cloth)), isTrue);
      await letWork(tester, done: () => c.saved.isEmpty && c.pictures.isNotEmpty);
      expect([for (final p in c.pictures) (p.name, p.design)], [('Mira', null)]);
    });

    testWidgets('saved again, then its box deleted straight away, it keeps the latest picture', (tester) async {
      final c = await pumpDrawing(tester, CaptureDelivery());
      final box = c.box!;
      await saveDrawn(tester, c, 'Areca');
      final draw = c.drawPicture!;
      // An older phone: the picture is drawn well after the save.
      c.drawPicture = (d) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return draw(d);
      };
      final cloth = await clothOf(tester, c, box);
      c.setName('Banyan');
      final gone = await finish(tester, () async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await c.save();
        return c.deleteBox(box, cloth);
      });
      expect(gone, isTrue);
      await letWork(tester, done: () => c.saved.isEmpty && c.pictures.length == 1 && c.pictures.single.design == null);
      expect(c.pictures.map((p) => p.name), ['Banyan']);
    });

    testWidgets('renamed, then its box deleted, its picture is captioned with the new name', (tester) async {
      final c = await pumpDrawing(tester, CaptureDelivery());
      final box = c.box!;
      await saveDrawn(tester, c, 'Areca');
      final before = await pngOf(tester, c, c.pictureOf(c.savedId!)!.id);
      final draw = c.drawPicture!, drawn = <String>[];
      c.drawPicture = (d) {
        drawn.add(d.name);
        return draw(d);
      };
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        expect(await c.rename(c.saved.single, 'Mira’s quilt'), isTrue);
      });
      await letWork(tester, done: () => c.saved.single.name == 'Mira’s quilt');
      final cloth = await clothOf(tester, c, box);
      expect(await finish(tester, () => c.deleteBox(box, cloth)), isTrue);
      await letWork(tester, done: () => c.saved.isEmpty && c.pictures.single.design == null);
      expect(drawn, ['Mira’s quilt'], reason: 'the caption is the name she sees');
      expect(c.pictures.single.name, 'Mira’s quilt');
      expect(await pngOf(tester, c, c.pictures.single.id), isNot(before));
    });

    testWidgets('duplicated, then deleted, each design has a picture of its own', (tester) async {
      final c = await pumpDrawing(tester, CaptureDelivery());
      final box = c.box!;
      await saveDrawn(tester, c, 'Areca');
      expect(await finish(tester, () => c.duplicate(c.saved.single)), isTrue);
      await letWork(tester, done: () => c.saved.length == 2);
      final cloth = await clothOf(tester, c, box);
      expect(await finish(tester, () => c.deleteBox(box, cloth)), isTrue);
      await letWork(tester, done: () => c.saved.isEmpty && c.pictures.length == 2);
      expect(c.pictures.map((p) => p.name).toSet(), {'Areca', 'Areca copy'});
      final pngs = [for (final p in c.pictures) await pngOf(tester, c, p.id)];
      expect(pngs.first, isNot(pngs.last), reason: 'each captioned with its own name');
    });

    testWidgets('a design saved after the pictures were made, before the delete, is not lost: the delete is refused, its '
        'picture made, then it goes', (tester) async {
      final shelf = SavesMeanwhile(memoryDb());
      final c = await pumpStudio(tester, size: phone, delivery: CaptureDelivery(), on: shelf);
      final t = TakeAway(delivery: CaptureDelivery());
      c.drawPicture = (d) => t.picture(c, d);
      final box = c.box!;
      await saveDrawn(tester, c, 'Areca');
      final row = (await tester.runAsync(() => shelf.db.select(shelf.db.designs).getSingle()))!;
      // Another tab saves Banyan, on the same cloth, once the studio has found every design pictured.
      shelf.meanwhile = DesignInput(name: 'Banyan', layout: row.layout, mount: row.mount, box: row.box, seed: row.seed,
          started: row.started, firstSolve: row.firstSolve,
          grid: [for (final g in jsonDecode(row.grid) as List) GridCell((g as Map)['id'] as String, g['rot'] as int)]);
      final cloth = await clothOf(tester, c, box);
      expect(await finish(tester, () => c.deleteBox(box, cloth)), isTrue);
      expect(shelf.meanwhile, isNull, reason: 'Banyan was saved during the delete');
      await letWork(tester, done: () => c.saved.isEmpty && c.pictures.length == 2);
      expect(c.ownBoxes, isNot(contains(box)));
      expect({for (final p in c.pictures) p.name: p.design}, {'Areca': null, 'Banyan': null},
          reason: 'Banyan stays, as Picture only');
    });

    testWidgets('a second press of Delete box while its question is being prepared opens no second question',
        (tester) async {
      final shelf = SlowClothIn(memoryDb());
      final c = await pumpStudio(tester, size: phone, on: shelf);
      await tester.tap(key('tab-cloth'));
      await tester.pumpAndSettle();
      final gate = shelf.gate = Completer<void>();
      await tapShown(tester, key('delete-box'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing, reason: 'still being prepared');
      await tester.tap(key('delete-box'));
      await tester.pump(const Duration(milliseconds: 300));
      shelf.gate = null;
      gate.complete();
      await letWork(tester, done: () => find.byType(AlertDialog).evaluate().isNotEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(inDialog('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(c.ownBoxes, contains(c.box));
    });

    testWidgets('a box that took cloth after she was asked is not deleted; she is asked again in the words for what it '
        'holds now', (tester) async {
      final c = await pumpDrawing(tester, CaptureDelivery());
      final box = (await tester.runAsync(c.shelf.makeBox))!;
      await letWork(tester, done: () => c.ownBoxes.contains(box));
      c.openBox(box);
      await tester.pumpAndSettle();
      await tester.tap(key('tab-cloth'));
      await tester.pumpAndSettle();
      await tapShown(tester, find.text('Delete box'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Box 2? It holds no cloth.'), findsOneWidget);
      final added = (await tester.runAsync(() => c.shelf.addPiecesForTest(box, 3)))!; // another tab adds a piece
      await tester.tap(inDialog('Delete'));
      await letWork(tester, done: () => find.text('Delete Box 2 and its pieces?').evaluate().isNotEmpty);
      expect(find.text('Delete Box 2 and its pieces?'), findsOneWidget);
      await tester.tap(inDialog('Cancel'));
      await tester.pumpAndSettle();
      expect(c.ownBoxes, contains(box));
      expect((await clothOf(tester, c, box)), {added});
    });

    testWidgets('a picture that cannot be drawn twice deletes nothing, says try again, and reports the design',
        (tester) async {
      final c = await pumpStudio(tester, size: phone, delivery: CaptureDelivery());
      final box = c.box!;
      await saveAs(tester, c, 'Areca'); // no picture yet
      final id = c.savedId!;
      var tries = 0;
      c.drawPicture = (d) async {
        tries++;
        return null;
      };
      await tester.tap(key('tab-cloth'));
      await tester.pumpAndSettle();
      await tapShown(tester, key('delete-box'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Delete'));
      await letWork(tester, done: () => c.warn);
      expect(tries, 2);
      expect(c.note, 'That did not work. Try again in a moment.');
      expect(c.note, c.words.clothErrorsPieceFailed);
      expect('${tester.takeException()}', contains(id));
      expect(c.ownBoxes, contains(box));
      expect(c.saved.map((d) => d.id), [id]);
      expect((await clothOf(tester, c, box)), isNotEmpty);
    });

    testWidgets('a second press of Delete box while a delete makes its pictures does nothing', (tester) async {
      final c = await pumpStudio(tester, size: phone, delivery: CaptureDelivery());
      final box = c.box!;
      await saveAs(tester, c, 'Areca'); // no picture yet: the delete makes one
      final t = TakeAway(delivery: CaptureDelivery());
      final held = Completer<void>();
      var draws = 0;
      c.drawPicture = (d) async {
        draws++;
        await held.future;
        return t.picture(c, d);
      };
      await tester.tap(key('tab-cloth'));
      await tester.pumpAndSettle();
      await tapShown(tester, key('delete-box'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Delete'));
      // The button's spinner turns while it is busy, so the clock is moved by hand, not settled.
      for (var i = 0; i < 100 && draws == 0; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(c.deleting, isTrue);
      final button = find.descendant(of: key('delete-box'), matching: find.byType(PhoneButton));
      expect(tester.widget<PhoneButton>(button).busy, isTrue);
      await tester.pump(const Duration(milliseconds: 500)); // the question closes
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(key('delete-box'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AlertDialog), findsNothing, reason: 'not asked again');
      expect(await tester.runAsync(() => c.deleteBox(box, const {})), isFalse, reason: 'nor by the studio');
      held.complete();
      await letWork(tester, done: () => !c.ownBoxes.contains(box), turns: 300);
      expect(draws, 1);
      expect(c.pictures.map((p) => p.name), ['Areca']);
    });
  });
}
