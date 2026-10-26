import 'dart:async';
import 'dart:isolate' show RemoteError;
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/add_cloth.dart';
import 'package:kantha_studio/cloth/photo_source.dart';
import 'package:kantha_studio/cloth/prepare.dart' show PickedPhoto;
import 'package:kantha_studio/data/database.dart' show ClothRow;
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/measure/measure.dart' show Measured;
import 'package:kantha_studio/studio/controller.dart';
import '../support/db.dart';
import '../support/pump.dart';

/* A phone photo's shape, 3:4. */
class PortraitPhotos implements PhotoSource {
  @override
  Future<Uint8List?> pick({required bool camera}) async =>
      img.encodePng(img.Image(width: 600, height: 800)..clear(img.ColorRgb8(140, 60, 90)));
}

/* A camera that took nothing: she backed out of it. */
class NoPhotos implements PhotoSource {
  @override
  Future<Uint8List?> pick({required bool camera}) async => null;
}

/* A file that is not a picture, from a source that gives no name. */
class NotAPicture implements PhotoSource {
  @override
  Future<Uint8List?> pick({required bool camera}) async => Uint8List.fromList('not a picture'.codeUnits);
}

/* The same, from a source that names what it gave. */
class NamedNotAPicture extends NotAPicture implements NamedPhotoSource {
  @override
  String? get lastName => 'notes.txt';
}

/* A JPEG whose header is whole and whose body is broken: its scan names nine components.
   The header reads; the picture does not. */
Uint8List brokenJpeg() {
  final b = img.encodeJpg(img.Image(width: 200, height: 200)..clear(img.ColorRgb8(30, 120, 140)));
  for (var i = 0; i < b.length - 1; i++) {
    if (b[i] == 0xFF && b[i + 1] == 0xDA) {
      b[i + 4] = 9;
      break;
    }
  }
  return b;
}

class BrokenPhotos implements NamedPhotoSource {
  @override
  String? get lastName => 'broken.jpg';
  @override
  Future<Uint8List?> pick({required bool camera}) async => brokenJpeg();
}
/* A shelf whose adds fail, as a full box's do, until the test lets them through. */
class FailingAdd extends Shelf {
  FailingAdd(super.db);
  bool fail = true;
  @override
  Future<ClothRow> addCloth({required int box, required Uint8List photo, required Measured measured,
      required String fabric, required int pieces, String? name}) => fail
      ? Future.error(const ShelfError('boxFull', {'limit': 200}))
      : super.addCloth(box: box, photo: photo, measured: measured, fabric: fabric, pieces: pieces, name: name);
}

/* The ways the Add a piece sheet is closed. None waits for the frame to settle: a spinner may be turning. */
final closes = <String, Future<void> Function(WidgetTester)>{
  'Done': (tester) async {
    final done = inSheet(find.text('Done'));
    await tester.ensureVisible(done);
    await tester.pump();
    await tester.tap(done);
  },
  'the ×': (tester) => tester.tap(inSheet(find.bySemanticsLabel('Close')).last),
  'a tap on the scrim': (tester) => tester.tapAt(const Offset(5, 5)),
  'back': (tester) => tester.binding.handlePopRoute(),
  'Escape': (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape),
};

/* Box 2, new and empty, on the board, and its Add a piece sheet open. */
Future<StudioController> openAdd(WidgetTester tester, PhotoSource photos, {Shelf? on}) async {
  final c = await pumpStudio(tester, photos: photos, on: on);
  await tester.runAsync(() => c.shelf.makeBox());
  // The shelf's watch answers on the next turn of the real event loop.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  c.openBox(2);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tab-cloth')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-pieces')));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('a photograph and a count become a cloth in the open box, and the design is untouched', (tester) async {
    final c = await openAdd(tester, FixturePhotos());
    final before = c.grid;
    expect(before, isNull, reason: 'an empty box is the empty sheet (2026-10-07 sample-box spec, decision 13)');
    // Fabric is not asked: one line says what works best (2026-10-07 sample-box spec, decision 9).
    expect(inSheet(find.text('Cotton or linen works best.')), findsOneWidget);
    expect(find.text('Fabric type'), findsNothing);
    await tester.tap(find.text('Photo of the piece'));
    // The cropper reads the picture in an isolate, off the fake clock; Add turns until it has.
    await letWork(tester, turns: 10);
    expect(find.text('fill the square with the piece'), findsOneWidget);
    await tapShown(tester, inSheet(find.bySemanticsLabel('One more piece')));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('2 pieces')), findsOneWidget);
    await tapShown(tester, inSheet(find.text('Add 2 to box')));
    // Cropped, measured and stored: each hop is an isolate or the shelf's watch, each a turn of the real event loop.
    await letWork(tester, done: () => c.cloth.any((x) => x.box == 2));
    expect(inSheet(find.byKey(const ValueKey('cloth-added'))), findsOneWidget, reason: 'the sheet says what went in');
    expect(c.cloth.where((x) => x.box == 2).single.stock, 2);
    expect(c.grid, before);
  });

  // Every close adds a photo waiting first (owner, 22 October 2026; DECISIONS 58).
  for (final MapEntry(key: how, value: close) in closes.entries) {
    testWidgets('$how with a photo waiting adds it once, at the count shown, then closes the sheet', (tester) async {
      final c = await openAdd(tester, FixturePhotos());
      await tester.tap(find.text('Photo of the piece'));
      await letWork(tester, turns: 10);
      for (var i = 0; i < 2; i++) {
        await tapShown(tester, inSheet(find.bySemanticsLabel('One more piece')));
        await tester.pumpAndSettle();
      }
      expect(inSheet(find.text('3 pieces')), findsOneWidget);
      await close(tester);
      await letWork(tester, done: () => c.cloth.any((x) => x.box == 2) && sheet.evaluate().isEmpty);
      expect(sheet, findsNothing);
      expect(c.cloth.where((x) => x.box == 2).single.stock, 3, reason: 'one cloth, at the count shown');
    });

    testWidgets('$how whose add fails keeps the sheet open, with the error and the photo; $how again adds it',
        (tester) async {
      final shelf = FailingAdd(memoryDb());
      final c = await openAdd(tester, FixturePhotos(), on: shelf);
      await tester.tap(find.text('Photo of the piece'));
      await letWork(tester, turns: 10);
      await close(tester);
      const full = 'This box holds 200 cloths already. Take some out before adding more.';
      await letWork(tester, done: () => find.text(full).evaluate().isNotEmpty);
      expect(sheet, findsOneWidget, reason: 'the sheet stays open');
      expect(inSheet(find.text(full)), findsOneWidget);
      expect(inSheet(find.byKey(const ValueKey('crop-square'))), findsOneWidget, reason: 'the photo still waits in the crop');
      expect(inSheet(find.text('Add to box')), findsOneWidget, reason: 'not busy');
      expect(c.cloth.where((x) => x.box == 2), isEmpty);

      shelf.fail = false;
      await close(tester);
      await letWork(tester, done: () => c.cloth.any((x) => x.box == 2) && sheet.evaluate().isEmpty);
      expect(sheet, findsNothing);
      expect(c.cloth.where((x) => x.box == 2).single.stock, 1);
    });

    testWidgets('$how with no photo waiting closes the sheet and adds nothing', (tester) async {
      final c = await openAdd(tester, FixturePhotos());
      final before = c.cloth.length;
      await close(tester);
      await letWork(tester, turns: 5);
      expect(sheet, findsNothing);
      expect(c.cloth, hasLength(before));
    });

    testWidgets('$how twice in a row with a photo waiting adds one cloth', (tester) async {
      final c = await openAdd(tester, FixturePhotos());
      await tester.tap(find.text('Photo of the piece'));
      await letWork(tester, turns: 10);
      await close(tester);
      await tester.pump();
      await close(tester);
      await letWork(tester, done: () => c.cloth.any((x) => x.box == 2) && sheet.evaluate().isEmpty);
      await letWork(tester, turns: 5);
      expect(sheet, findsNothing);
      expect(c.cloth.where((x) => x.box == 2), hasLength(1));
    });
  }

  testWidgets('a close while the photo is still read says to wait, and that goes once the photo is ready', (tester) async {
    final c = await openAdd(tester, FixturePhotos());
    await tester.tap(find.text('Photo of the piece'));
    await tester.pump(); // the pick answers
    await tester.pump(); // the frame that draws it busy
    expect(find.text('Measuring…'), findsOneWidget);
    await closes['Done']!(tester);
    await tester.pump();
    const wait = 'The cropper is still loading. Give it a moment and press again.';
    expect(inSheet(find.text(wait)), findsOneWidget);
    await letWork(tester, turns: 10);
    expect(find.text('Measuring…'), findsNothing);
    expect(inSheet(find.text(wait)), findsNothing, reason: 'the photo is ready');
    expect(sheet, findsOneWidget, reason: 'that close was refused');
    expect(c.cloth.where((x) => x.box == 2), isEmpty);
  });

  testWidgets('the count starts at 1 on an empty box, on a box with a few pieces, and on a full one', (tester) async {
    final c = await openAdd(tester, FixturePhotos());
    expect(inSheet(find.text('1 piece')), findsOneWidget, reason: 'empty Box 2');
    await tester.tap(find.text('Photo of the piece'));
    await letWork(tester, turns: 10);
    for (var i = 0; i < 2; i++) {
      await tapShown(tester, inSheet(find.bySemanticsLabel('One more piece')));
      await tester.pumpAndSettle();
    }
    await tapShown(tester, inSheet(find.text('Add 3 to box')));
    await letWork(tester, done: () => c.piecesIn(2) == 3);
    expect(inSheet(find.text('1 piece')), findsOneWidget, reason: 'after an add, again at 1');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tapShown(tester, find.byKey(const ValueKey('add-pieces')));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('1 piece')), findsOneWidget, reason: 'Box 2 holds 3 pieces');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    c.openBox(1);
    await tester.pumpAndSettle();
    expect(c.piecesIn(1), greaterThanOrEqualTo(35));
    await tapShown(tester, find.byKey(const ValueKey('add-pieces')));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('1 piece')), findsOneWidget, reason: 'Box 1 holds a panel');
  });

  testWidgets('the count never goes below one', (tester) async {
    await openAdd(tester, FixturePhotos());
    for (var i = 0; i < 6; i++) {
      await tapShown(tester, inSheet(find.bySemanticsLabel('One fewer piece')));
      await tester.pumpAndSettle();
    }
    expect(inSheet(find.text('1 piece')), findsOneWidget);
    final fewer = tester.widget<IconButton>(find.ancestor(of: find.bySemanticsLabel('One fewer piece'), matching: find.byType(IconButton)));
    expect(fewer.onPressed, isNull);
  });

  testWidgets('the tile takes a photo with the camera, and Choose a picture opens the gallery', (tester) async {
    final photos = FixturePhotos();
    await openAdd(tester, photos);
    await tester.tap(find.text('Photo of the piece'));
    await letWork(tester, turns: 10);
    await tapShown(tester, find.text('Choose a different picture'));
    await tester.pumpAndSettle();
    await tapShown(tester, find.text('Choose a picture'));
    await letWork(tester, turns: 10);
    expect(photos.asked, [true, false]);
    expect(find.text('fill the square with the piece'), findsOneWidget);
  });

  testWidgets('nothing taken, nothing changes', (tester) async {
    await openAdd(tester, NoPhotos());
    await tester.tap(find.text('Photo of the piece'));
    await tester.pumpAndSettle();
    expect(find.text('fill the square with the piece'), findsNothing);
    expect(find.text('Photo of the piece'), findsOneWidget);
  });

  testWidgets('a file that is not a picture is named in the error; with no name to give, the error says it could not be read', (tester) async {
    await openAdd(tester, NamedNotAPicture());
    await tester.tap(find.text('Photo of the piece'));
    await letWork(tester, turns: 5);
    expect(find.text('fill the square with the piece'), findsNothing);
    expect(find.text('notes.txt could not be read as a picture.'), findsOneWidget);
    await tapShown(tester, inSheet(find.text('Done')));
    await tester.pumpAndSettle();

    await openAdd(tester, NotAPicture());
    await tester.tap(find.text('Photo of the piece'));
    await letWork(tester, turns: 5);
    expect(find.text('The factory answered in a way this could not read. Nothing was added.'), findsOneWidget);
  });

  testWidgets('Add asks for nothing but the photo: it is ready at once, and with no photo it says one is needed', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = await openAdd(tester, FixturePhotos());
    final add = tester.getSemantics(find.text('Add to box'));
    expect(add.flagsCollection.isButton, isTrue);
    expect(add.flagsCollection.isEnabled, Tristate.isTrue);
    await tapShown(tester, find.text('Add to box'));
    await tester.pumpAndSettle();
    expect(find.text('A photograph of the piece is needed.'), findsOneWidget);
    expect(c.cloth.where((x) => x.box == 2), isEmpty);
    semantics.dispose();
  });

  // Fix round 1.
  testWidgets('while the cropper reads the picture the button says Measuring…, drawn before the work starts', (tester) async {
    await openAdd(tester, FixturePhotos());
    await tester.tap(find.text('Photo of the piece'));
    await tester.pump(); // the pick answers
    await tester.pump(); // the frame that draws it busy
    expect(find.text('Measuring…'), findsOneWidget);
    await letWork(tester, turns: 10);
    expect(find.text('Measuring…'), findsNothing);
    expect(find.text('Add to box'), findsOneWidget);
  });

  testWidgets('the square starts at 70 % of the stage, as cropperjs started it, not 70 % of the picture', (tester) async {
    await openAdd(tester, PortraitPhotos());
    await tester.tap(find.text('Photo of the piece'));
    await letWork(tester, turns: 10);
    final stage = tester.getSize(find.byKey(const ValueKey('crop-stage')));
    final square = tester.getSize(find.byKey(const ValueKey('crop-square')));
    // Inside the stage's 1 px border its shorter side is 298 px; the 3:4 photo is drawn 223.5 px wide.
    expect(square.width, closeTo((stage.height - 2) * 0.7, 0.5));
    expect(square.height, closeTo(square.width, 0.01));
  });

  // Fix round 2.
  testWidgets('a picture whose header reads but whose body is broken is named in the error, and nothing waits on it', (tester) async {
    await openAdd(tester, BrokenPhotos());
    await tester.tap(find.text('Photo of the piece'));
    await letWork(tester, done: () => find.textContaining('could not be read').evaluate().isNotEmpty, turns: 20);
    expect(find.text('broken.jpg could not be read as a picture.'), findsOneWidget);
    expect(find.text('Measuring…'), findsNothing);
    expect(find.text('Add to box'), findsOneWidget, reason: 'not busy');
    expect(find.text('fill the square with the piece'), findsNothing);
    expect(find.text('Photo of the piece'), findsOneWidget, reason: 'she can pick again');
  });

  testWidgets('a read that fails another way (its isolate gone, out of memory) ends Measuring… and says the photo '
      'could not be read', (tester) async {
    final shelf = Shelf(memoryDb());
    final box = (await tester.runAsync(shelf.makeBox))!;
    final read = Completer<PickedPhoto>();
    await tester.pumpWidget(MaterialApp(localizationsDelegates: const [L.delegate], supportedLocales: L.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: AddCloth(box: box, shelf: shelf, photos: NamedPortrait(),
            words: lookupL(const Locale('en')), onClose: () {}, read: (_) => read.future)))));
    await tester.tap(find.text('Photo of the piece'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('Measuring…'), findsWidgets);
    read.completeError(RemoteError('Out of Memory', ''));
    await tester.pump();
    expect(tester.takeException(), isA<RemoteError>(), reason: 'reported');
    expect(find.text('piece.png could not be read as a picture.'), findsOneWidget);
    expect(find.text('Measuring…'), findsNothing);
    expect(find.text('Photo of the piece'), findsOneWidget, reason: 'she can pick again');
  });
}

/* A 3:4 picture named as the gallery names it. */
class NamedPortrait extends PortraitPhotos implements NamedPhotoSource {
  @override
  String? get lastName => 'piece.png';
}
