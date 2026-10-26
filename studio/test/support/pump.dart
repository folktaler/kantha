import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/app.dart';
import 'package:kantha_studio/backup/files.dart';
import 'package:kantha_studio/cloth/photo_source.dart';
import 'package:kantha_studio/data/sample_box.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/downloads/delivery.dart';
import 'package:kantha_studio/solver/geometry.dart' show a4;
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/painters.dart' show DashedRectPainter;
import 'package:kantha_studio/studio/phone/phone_sheet.dart' show SheetRow;
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:kantha_studio/studio/phone/phone_toast.dart';
import 'package:kantha_studio/studio/studio_screen.dart';
import 'package:kantha_studio/platform/solver_runner.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import 'db.dart';
import 'studio_fixture.dart';

export 'files_fixture.dart';

const desk = Size(1360, 880), laptop = Size(1272, 588), tablet = Size(820, 1180), phone = Size(390, 844);

Shelf? _lastShelf;

/* The test's window: `size` at one device pixel to the logical pixel, put back after the test. */
void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/* The studio at a window size, with her Box 1 (the pool fixture) arranged on it — or, `seeded: false`, empty.
   `photos` stands in for the camera and the gallery,
   `delivery` for where Share, DIY and Back up send their files, `files` for where a backup is opened from, `on` for a shelf of the test's own.
   `openLink` is where a link is sent, `kept` drift's word on whether the browser keeps anything (unknown when null),
   `sameDatabase` opens it again on the shelf the test's last pumpStudio used, as a second visit does, and `solver` stands in for
   QuickSolver. `safariOnIphone` is a phone's Safari, not opened from the Home Screen. */
Future<StudioController> pumpStudio(WidgetTester tester, {Size size = desk, PhotoSource? photos, Delivery? delivery,
    Files? files, Shelf? on, bool? kept, bool sameDatabase = false, bool seeded = true, void Function(Uri)? openLink,
    SolverRunner? solver, bool safariOnIphone = false}) async {
  _window(tester, size);
  final s = (await tester.runAsync(() => studio(on: on ?? (sameDatabase ? _lastShelf : null), seeded: seeded, solver: solver)))!;
  _lastShelf = s.shelf;
  addTearDown(() => _lastShelf = null);
  await tester.pumpWidget(KanthaApp.forTest(controller: s.c, shelf: s.shelf, photos: photos, delivery: delivery, files: files,
      kept: kept, openLink: openLink, safariOnIphone: safariOnIphone));
  await tester.pumpAndSettle();
  return s.c;
}

/* The studio on a fresh device's Sample box, and nothing else. */
Future<StudioController> pumpOnSample(WidgetTester tester, {Size size = desk}) async {
  final shelf = Shelf(memoryDb());
  await tester.runAsync(() => makeSampleBox(shelf));
  return pumpStudio(tester, on: shelf, size: size);
}

/* Her Box 1 of 105 pieces, the Sample box made after it, and an empty Box 2: the studio opens on the Sample box,
   the newest that can fill. (The fixture writes its cloth ids itself, so it goes first.) */
Future<({StudioController c, int box2})> pumpThree(WidgetTester tester, {Size size = desk}) async {
  final shelf = Shelf(memoryDb());
  final box2 = (await tester.runAsync(() async {
    await seedFixtureBox(shelf);
    await makeSampleBox(shelf);
    return shelf.makeBox();
  }))!;
  final c = await pumpStudio(tester, on: shelf, size: size);
  return (c: c, box2: box2);
}

/* Where the studio's buttons led, in order. */
class Went {
  final log = <String>[];
  late final actions = StudioActions(
    openTakeAway: (id) => log.add('export $id'),
    openCloth: (o) => log.add(o.kind == ClothOpenKind.add ? 'add ${o.box}' : 'fix ${o.clothId}'),
    openBoxes: () => log.add('boxes'),
    deleteBox: (b) async { log.add('delete box $b'); return false; },
    openBackup: () => log.add('backup'),
    openLink: (u) => log.add('link $u'),
    openDesigns: () => log.add('designs'),
    openPicture: (_, p) => log.add('view ${p.id}'),
  );
}

/* pumpStudio, with buttons that say where they led. */
Future<StudioController> pumpWith(WidgetTester tester, Went went, {Size size = desk, bool seeded = true}) async {
  _window(tester, size);
  final s = (await tester.runAsync(() => studio(seeded: seeded)))!;
  final toaster = Toaster();
  addTearDown(toaster.dispose);
  await tester.pumpWidget(KanthaFrame(home: StudioScreen(controller: s.c, actions: went.actions, toaster: toaster)));
  await tester.pumpAndSettle();
  return s.c;
}

/* Work that runs off the fake clock — the cropper reading a picture, an isolate measuring it,
   the shelf's watch answering — moves one hop per turn of the real event loop: a little real
   time, then a frame, until `done` holds or the turns are spent. */
Future<void> letWork(WidgetTester tester, {bool Function()? done, int turns = 60}) async {
  for (var i = 0; i < turns && !(done?.call() ?? false); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    // A millisecond on the test's clock: a deferred library (`deferred as`) finishes loading on a timer, which a pump
    // of no time does not run.
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pumpAndSettle();
}

/* The studio on a phone, its solver one that arranges from stock. */
Future<StudioController> pumpPhone(WidgetTester tester, {bool seeded = true, SolverRunner? solver}) =>
    pumpStudio(tester, size: phone, seeded: seeded, solver: solver ?? StockSolver());

Finder key(String k) => find.byKey(ValueKey(k));
final sheet = find.byType(BottomSheet);
Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
/* `f` in the open Menu (menu_panel.dart). */
Finder inMenu(Finder f) => find.descendant(of: find.byKey(const ValueKey('menu-panel')), matching: f);

/* A button, scrolled into view first. */
Future<void> tapShown(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await tapShown(tester, f);
  await tester.pumpAndSettle();
}

/* The camera and the gallery: an 800 × 800 picture of one colour, and which was asked for. */
class FixturePhotos implements PhotoSource {
  final asked = <bool>[];
  @override
  Future<Uint8List?> pick({required bool camera}) async {
    asked.add(camera);
    return img.encodePng(img.Image(width: 800, height: 800)..clear(img.ColorRgb8(30, 120, 140)));
  }
}

/* Saved as it is, under `name`, and the shelf's watch caught up. */
Future<void> saveAs(WidgetTester tester, StudioController c, String name) async {
  final before = c.saved.length;
  c.setName(name);
  await tester.runAsync(c.save);
  await letWork(tester, done: () => c.saved.length > before);
}

/* A new box of hers, turned to on the board while empty, as making one does, then given `pieces` pieces (in cloths of 5
   and what is over). */
Future<int> boxWith(WidgetTester tester, StudioController c, int pieces) async {
  final box = (await tester.runAsync(() => c.shelf.makeBox()))!;
  await letWork(tester, done: () => c.ownBoxes.contains(box));
  c.openBox(box);
  await letWork(tester, done: () => !c.solving);
  await tester.runAsync(() async {
    for (var left = pieces; left > 0; left -= 5) {
      await c.shelf.addCloth(box: box, photo: fixtureJpeg, measured: measuredFor(l: 30.0 + left), fabric: '',
          pieces: left < 5 ? left : 5);
    }
  });
  await letWork(tester, done: () => c.piecesIn(box) == pieces && !c.solving);
  return box;
}

/* An empty square's name. */
String cellLabel(int r, int c) => 'Row $r, column $c — tap to add cloth';

/* Every one of the 35 squares a button with its row and column, drawn white with a dashed edge and a plus. */
void expectDashed(WidgetTester tester) {
  for (var r = 1; r <= a4.rows; r++) {
    for (var col = 1; col <= a4.cols; col++) {
      expect(find.bySemanticsLabel(cellLabel(r, col)), findsOneWidget, reason: 'row $r, column $col');
    }
  }
  final cell = key('empty-cell-0');
  expect(cell, findsOneWidget);
  final dashes = tester.widgetList<CustomPaint>(find.descendant(of: cell, matching: find.byType(CustomPaint)))
      .map((p) => p.painter).whereType<DashedRectPainter>().toList();
  expect(dashes, hasLength(1));
  expect((dashes.single.color, dashes.single.width), (PhonePalette.strong, 1.0));
  final dashed = find.descendant(of: cell, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is DashedRectPainter));
  final outer = tester.getRect(cell), inner = tester.getRect(dashed);
  // To a millionth of a pixel: a board centred at a fractional offset leaves float dust in the subtraction.
  for (final edge in [inner.left - outer.left, outer.right - inner.right, inner.top - outer.top, outer.bottom - inner.bottom]) {
    expect(edge, closeTo(4.0, 1e-6), reason: '4 px in');
  }
  expect(iconLook(tester, find.descendant(of: cell, matching: find.byType(tabler.Plus))),
      (size: 16.0, color: PhonePalette.text.withValues(alpha: 0.6)));
  expect(tester.getSize(cell).shortestSide, greaterThanOrEqualTo(44), reason: 'a touch target');
}

/* No row is busy: the file a row makes is made and handed over (a busy row's spinner never settles). */
bool idle(WidgetTester tester) => find.byType(SheetRow).evaluate().every((e) => (e.widget as SheetRow).iconBusy == null);

/* The size and colour a Tabler icon is drawn at (phone_theme.dart tablerIcon). */
({double size, Color color}) iconLook(WidgetTester tester, Finder icon) {
  final data = tester.widget<tabler.IconTheme>(find.ancestor(of: icon, matching: find.byType(tabler.IconTheme)).first).data;
  return (size: data.width!, color: data.color!);
}

/* Share on the top bar, then the sheet, once its design has been saved and no row is busy. */
Future<void> openShare(WidgetTester tester) async {
  await tester.tap(key('phone-export'));
  await letWork(tester, done: () => find.text('Kantha stitching guide').evaluate().isNotEmpty && idle(tester), turns: 300);
}
