/* The three seams a journey swaps for fixtures — the photo source (no camera in a test), the delivery
   (no share sheet) and the file picker — and the database it opens, fresh or again. Nothing else in
   the app is stood in for: the solver, drift and every screen are the device's own.

   A restart (closeTheApp, then runKantha on sameDatabase) takes the app down, closes its drift
   connection and opens a new one through openKantha. On a phone that closes the SQLite file and opens
   it again: what comes back was on the device. In a browser the restart happens in the same page: the
   same JavaScript and the same drift worker, which lasts as long as the page, so a reopen can be
   answered from that worker. Under `flutter drive` drift picks sharedIndexedDb, because the test server
   sends no COOP/COEP headers. So a browser restart here proves that a new connection reads her things
   back. It does not prove that they reached IndexedDB, and OPFS is never used. Task 24's check of the
   headers on the real /studio is what covers OPFS. */
import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:kantha_studio/app.dart';
import 'package:kantha_studio/backup/files.dart';
import 'package:kantha_studio/cloth/photo_source.dart';
import 'package:kantha_studio/data/connect.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/downloads/delivery.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'wipe_io.dart' if (dart.library.js_interop) 'wipe_web.dart' as wipe;

/* A 1200 × 900 photo of one piece of cloth, 400 px square, on a table: the finder finds the one piece, so the crop
   starts on it, as it does for one piece. Each picture comes in the next of five colourways, so a box of five is five
   colours. (A photo of many pieces is the widget tests' and the browser check's: test/cloth/add_many_test.dart.) */
class FixturePhotos implements PhotoSource {
  static const _ways = [
    ((178, 34, 52), (240, 228, 200)), // madder on cream
    ((32, 52, 110), (225, 232, 240)), // indigo on white
    ((214, 160, 30), (40, 100, 70)), // turmeric on green
    ((28, 28, 32), (120, 120, 128)), // charcoal on slate
    ((40, 120, 40), (230, 225, 190)), // leaf on cream
  ];
  var picked = 0;

  @override
  Future<Uint8List?> pick({required bool camera}) async {
    final ((r1, g1, b1), (r2, g2, b2)) = _ways[picked++ % _ways.length];
    final a = img.ColorRgb8(r1, g1, b1), b = img.ColorRgb8(r2, g2, b2);
    final photo = img.Image(width: 1200, height: 900)..clear(b);
    img.fillRect(photo, x1: 400, y1: 250, x2: 799, y2: 649, color: a);
    return img.encodePng(photo);
  }
}

typedef SavedFile = ({String name, Uint8List bytes});

/* Where Share and Back up send their files: kept here, by name, with their bytes. */
class CaptureDelivery implements Delivery {
  final pdfs = <String>[], photos = <String>[];
  final backups = <SavedFile>[];
  final bytes = <String, Uint8List>{};

  @override
  Future<void> savePhoto(Uint8List png, String file) async { photos.add(file); bytes[file] = png; }
  @override
  Future<void> sharePdf(Uint8List pdf, String file, {Rect? origin}) async { pdfs.add(file); bytes[file] = pdf; }
  @override
  Future<void> sharePhoto(Uint8List png, String file, {Rect? origin}) async { photos.add(file); bytes[file] = png; }
  @override
  Future<bool> saveBackup(Uint8List zip, String file, {Rect? origin}) async {
    backups.add((name: file, bytes: zip));
    return true;
  }
}

/* The file picker: hands out `next` (null: she cancelled). */
class CaptureFiles implements Files {
  SavedFile? next;
  @override
  Future<SavedFile?> pickBackup() async => next;
}

/* One run's database names: `it-<name>-<run id>`, the run id fixed for this process, so
   sameDatabase opens again what freshDatabase made. */
final _run = DateTime.now().millisecondsSinceEpoch.toString();
String _named(String name) => 'it-$name-$_run';

/* The device's database under a test's own name, wiped first: drift's deleteDatabase in a
   browser, the file on a phone. */
QueryExecutor freshDatabase(String name) => LazyDatabase(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      await wipe.deleteKantha(_named(name));
      return openKantha(name: _named(name));
    });

/* The same database again, as the app finds it when it comes back. */
QueryExecutor sameDatabase(String name) => openKantha(name: _named(name));

/* The running app's own shelf, and through it its database. */
Shelf appShelf(WidgetTester t) => t.widget<KanthaApp>(find.byType(KanthaApp)).shelf;

/* Everything the database holds of hers, in id order. */
typedef Held = ({List<BoxRow> boxes, List<ClothRow> cloths, List<DesignRow> designs, Map<String, int> counters});

Future<Held> whatItHolds(KanthaDatabase db) async => (
      boxes: await (db.select(db.boxes)..orderBy([(x) => OrderingTerm(expression: x.id)])).get(),
      cloths: await (db.select(db.cloths)..orderBy([(x) => OrderingTerm(expression: x.id)])).get(),
      designs: await (db.select(db.designs)..orderBy([(x) => OrderingTerm(expression: x.id)])).get(),
      counters: {for (final c in await db.select(db.counters).get()) c.name: c.next},
    );

/* Two readings hold the same: each box, each cloth with its photo byte for byte, each design with its
   name and its grid (every cell's cloth and turn), and the next number for each kind of id. An import gives
   every photo a new number (Cloths.photoNumber; Shelf's import), so after one, `photosRenumbered` leaves the
   photo numbers and the photo counter out, for the caller to check. */
void expectSameHeld(Held now, Held was, {bool photosRenumbered = false}) {
  expect([for (final b in now.boxes) b.id], [for (final b in was.boxes) b.id], reason: 'the box numbers');
  expect([for (final c in now.cloths) c.id], [for (final c in was.cloths) c.id], reason: 'the cloths');
  for (var i = 0; i < was.cloths.length; i++) {
    expect(listEquals(now.cloths[i].photo, was.cloths[i].photo), isTrue, reason: '${was.cloths[i].id}: its photo, byte for byte');
    final row = photosRenumbered ? now.cloths[i].copyWith(photoNumber: was.cloths[i].photoNumber) : now.cloths[i];
    expect(row, was.cloths[i], reason: '${was.cloths[i].id}: all of it${photosRenumbered ? ' but its photo number' : ''}');
  }
  expect([for (final d in now.designs) d.id], [for (final d in was.designs) d.id], reason: 'the designs');
  for (var i = 0; i < was.designs.length; i++) {
    expect((now.designs[i].name, now.designs[i].grid), (was.designs[i].name, was.designs[i].grid),
        reason: '${was.designs[i].id}: its name, and each cell\'s cloth and turn');
    expect(now.designs[i], was.designs[i], reason: '${was.designs[i].id}: all of it');
  }
  Map<String, int> counters(Held h) => photosRenumbered ? ({...h.counters}..remove('photo')) : h.counters;
  expect(counters(now), counters(was), reason: 'the next number for each kind of id');
}

/* Each counter is past every id of its kind, so the next one made is new. */
void expectCountersPastEveryId(Held h) {
  int most(Iterable<int> ids) => ids.fold(0, (a, b) => a > b ? a : b);
  int number(String id) => int.parse(id.substring(id.indexOf('-') + 1));
  expect(h.counters['box'], greaterThan(most(h.boxes.map((b) => b.id))), reason: 'the next box');
  expect(h.counters['cloth'], greaterThan(most(h.cloths.map((c) => number(c.id)))), reason: 'the next cloth');
  expect(h.counters['design'], greaterThan(most(h.designs.map((d) => number(d.id)))), reason: 'the next design');
}

/* The app goes, as when she closes it: its screens are taken down, then its connection to the database
   is closed. runKantha on sameDatabase brings it back through a new one (see the note at the top). */
Future<void> closeTheApp(WidgetTester t) async {
  final db = appShelf(t).db;
  await t.pumpWidget(const SizedBox.shrink());
  await settle(t);
  await db.close();
}

/* What Print pattern PDF and Save photo handed over for the design `stem`: a PDF of one page, and a 1080 × 1350 PNG. */
void expectTheFiles(CaptureDelivery d, String stem) {
  final pdf = d.bytes['$stem.pdf'], png = d.bytes['$stem.png'];
  expect(pdf, isNotNull, reason: '$stem.pdf was handed over');
  final text = latin1.decode(pdf!);
  expect(text.substring(0, 5), '%PDF-', reason: 'a PDF');
  expect(RegExp(r'/Type\s*/Page(?![a-zA-Z])').allMatches(text), hasLength(1), reason: 'one page');
  expect(text.trimRight().endsWith('%%EOF'), isTrue, reason: 'the PDF is whole');
  expect(png, isNotNull, reason: '$stem.png was handed over');
  final photo = img.decodePng(png!);
  expect(photo, isNotNull, reason: 'the photo is a PNG');
  expect((photo!.width, photo.height), (1080, 1350), reason: 'the photo is 1080 × 1350');
}

/* The dock's Cloth box tab, where the box on the board is named and its swatches are; already showing, it is left. */
Future<void> clothTab(WidgetTester t) async {
  final panel = find.byKey(const ValueKey('dock-cloth'));
  if (panel.evaluate().isNotEmpty) return;
  await tapIt(t, find.byKey(const ValueKey('tab-cloth')));
  await waitFor(t, panel);
}

/* The dock's Design tab, where the templates are. */
Future<void> patternsTab(WidgetTester t) async {
  await tapIt(t, find.byKey(const ValueKey('tab-patterns')));
  await waitFor(t, find.byKey(const ValueKey('dock-patterns')));
}

/* The box on the board, as the Cloth box tab's picker names it to a screen reader: `Box 1\n35 pieces`. */
Finder boxPicker(String label) =>
    find.descendant(of: find.byKey(const ValueKey('dock-cloth')), matching: find.bySemanticsLabel(label));

/* The open sheet's `f`: what is under the sheet is not what a tap there reaches. */
Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

/* Closes the sheet on top with its ✕. */
Future<void> closeSheet(WidgetTester t) async {
  await tapIt(t, inSheet(find.bySemanticsLabel('Close')).last);
  await t.pumpAndSettle();
}

/* Every cloth of `box` in the Cloth box tab's swatch row, under the name its colour gave it, with all its pieces: some
   still free, or all of them on the board (a box of exactly 35 uses every piece). */
Future<void> expectSwatches(WidgetTester t, int box) async {
  final cloths = (await whatItHolds(appShelf(t).db)).cloths.where((c) => c.box == box).toList();
  expect(cloths, isNotEmpty, reason: 'box $box holds cloth');
  await clothTab(t);
  for (final c in cloths) {
    final n = c.pieces;
    final label = RegExp('^${RegExp.escape(c.name)} — (\\d+ of $n pieces still free|all $n pieces are in the design)');
    expect(find.descendant(of: find.byKey(const ValueKey('dock-swatches')), matching: find.bySemanticsLabel(label)),
        findsOneWidget, reason: '${c.name} in the swatch row');
  }
}

/* The 35 cells' labels, row by row: what is where on the board. */
List<String> cellNames(WidgetTester t) {
  final cell = RegExp(r'^Row (\d+), column (\d+) — ');
  final found = <(int, int, String)>[];
  void walk(SemanticsNode n) {
    final m = cell.firstMatch(n.label);
    if (m != null) found.add((int.parse(m[1]!), int.parse(m[2]!), n.label));
    n.visitChildren((c) { walk(c); return true; });
  }
  for (final view in t.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) walk(root);
  }
  found.sort((p, q) => p.$1 != q.$1 ? p.$1.compareTo(q.$1) : p.$2.compareTo(q.$2));
  expect(found, hasLength(35), reason: 'the board has 35 cells');
  return [for (final f in found) f.$3];
}

/* A frame at a time for `seconds`, then until nothing is scheduled: work off the frame clock
   (the database, a worker, an isolate measuring) gets real time to answer. */
Future<void> settle(WidgetTester t, [int seconds = 2]) async {
  for (var i = 0; i < seconds * 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

/* Pumps until `f` finds something, for at most `seconds`: a measure or a solve takes as long as the device takes. */
Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 10 && f.evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
  if (f.evaluate().isEmpty) debugPrint('On screen instead: ${onScreen()}');
  expect(f, findsWidgets, reason: 'waited $seconds s for it');
}

/* Every piece of text on screen, for a failure to say where the journey stood. */
String onScreen() => find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText())
    .where((s) => s != null && s.trim().isNotEmpty).join(' | ');

/* Pumps until `done` holds, for at most `seconds`: a file is made as fast as the device makes it. */
Future<void> waitUntil(WidgetTester t, bool Function() done, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 10 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'waited $seconds s for it');
}

/* The studio as it stands, for the record: in a browser a screenshot through the driver
   (--dart-define=KANTHA_SHOT=true); on a phone it is held on screen for KANTHA_HOLD seconds,
   for the simulator's or the emulator's own screenshot. Neither is asked for in a plain run. */
Future<void> pictureOfTheStudio(IntegrationTestWidgetsFlutterBinding binding, WidgetTester t) async {
  if (kIsWeb && const bool.fromEnvironment('KANTHA_SHOT')) {
    // The picture is of the page, not the window: --browser-dimension sizes the window, and the browser
    // keeps some of it for itself, so the run asks for a taller window to give the page 1360 × 880.
    final page = t.view.physicalSize / t.view.devicePixelRatio;
    debugPrint('KANTHA_SHOT: the page is ${page.width.round()} × ${page.height.round()}');
    await binding.takeScreenshot('studio-saved-design');
  }
  const hold = int.fromEnvironment('KANTHA_HOLD');
  if (hold > 0) {
    debugPrint('KANTHA_HOLD: the studio is on screen for $hold s');
    for (var i = 0; i < hold * 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }
}

/* Taps what `f` finds — waiting up to 10 s for it to come (a panel rises, a screen opens), then
   scrolled into view, since a phone's screen does not hold everything at once. */
Future<void> tapIt(WidgetTester t, Finder f) async {
  for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (f.evaluate().isEmpty) debugPrint('Not on screen: $f. On screen instead: ${onScreen()}');
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
}

/* A fresh install: the Sample box, arranged (spec 2026-10-07 sample box, decision 1). The Cloth box tab names it and
   shows its cloths; the journey goes on from the Design tab, where the studio opens. */
Future<void> startFromSample(WidgetTester t) async {
  await waitFor(t, find.bySemanticsLabel(RegExp(r'^Row 1, column 1 — ')), seconds: 60);
  await clothTab(t);
  expect(boxPicker('Sample\n70 pieces · sample cloth'), findsOneWidget, reason: "the box picker's name");
  // The swatch's name is in what a screen reader hears: name — what is free · Fix this cloth.
  expect(find.descendant(of: find.byKey(const ValueKey('dock-swatches')),
          matching: find.bySemanticsLabel(RegExp(r'^Red and blue block print — \d+ of 7 pieces still free'))),
      findsOneWidget, reason: 'a Sample cloth in the swatch row');
  await patternsTab(t);
}

/* The Cloth box tab's picker → Your boxes → Add a box: Box 1, empty, on the board, and the sheet closed. */
Future<int> addOwnBox(WidgetTester t) async {
  await clothTab(t);
  await tapIt(t, find.byKey(const ValueKey('box-picker'))); await settle(t, 1);
  await tapIt(t, inSheet(find.text('Add a box'))); await settle(t);
  await waitFor(t, boxPicker('Box 1\n0 pieces'));
  expect(find.byType(BottomSheet), findsNothing, reason: 'Your boxes closes on the new box');
  final boxes = await appShelf(t).db.select(appShelf(t).db.boxes).get();
  return boxes.firstWhere((b) => b.number == 1).id;
}

/* Into `box`, on the board and empty: Add pieces, then five cloths of 7 pieces each (the count starts at 1, so More is
   pressed six times), each photographed and cropped (no fabric is asked), the sheet open between them. Done closes it on the board, arranged from Box 1's 35. */
Future<void> photographFive(WidgetTester t, {required int box}) async {
  await clothTab(t);
  await tapIt(t, find.byKey(const ValueKey('add-pieces'))); await settle(t);
  final db = appShelf(t).db;
  // The Sample box's cloths are already there: only what this sheet adds is new.
  final seen = {for (final c in await db.select(db.cloths).get()) c.id}, colours = <String>[];
  for (var n = 0; n < 5; n++) {
    await tapIt(t, inSheet(find.text('Photo of the pieces'))); await settle(t);
    // The cropper has the picture once the whole of it has been read.
    await waitFor(t, find.byKey(const ValueKey('crop-square')));
    await waitFor(t, inSheet(find.text('Add to box')));
    for (var i = 0; i < 6; i++) {
      await tapIt(t, inSheet(find.bySemanticsLabel('One more piece'))); await settle(t);
    }
    await tapIt(t, inSheet(find.text('Add 7 to box')));
    // Waited for in the database itself: from the second piece on, the panel already says Added before Add is pressed.
    var cloths = await db.select(db.cloths).get();
    for (var i = 0; i < 600 && cloths.length <= seen.length; i++) {
      await t.pump(const Duration(milliseconds: 100));
      cloths = await db.select(db.cloths).get();
    }
    final added = cloths.where((c) => !seen.contains(c.id)).toList();
    expect(added, hasLength(1), reason: 'one cloth for one Add (had ${seen.toList()}, now ${[for (final c in cloths) c.id]})');
    final c = added.single;
    seen.add(c.id);
    colours.add(c.colour);
    expect((c.box, c.fabric, c.pieces), (box, '', 7), reason: '${c.id} as she gave it, in Box 1, no fabric asked');
    expect(c.colour, isNotEmpty, reason: '${c.id} was measured');
    expect(c.name.toLowerCase(), contains(c.colour.toLowerCase()), reason: '${c.id} is named for its colour');
  }
  // If two colourways measure as one name, change the new colourways' colours, not this line.
  expect(colours.toSet(), hasLength(5), reason: 'five colourways measure as five colours: $colours');
  await tapIt(t, inSheet(find.text('Done'))); await settle(t);
  expect(find.byType(BottomSheet), findsNothing, reason: 'Done closes Add a piece');
  await waitFor(t, find.bySemanticsLabel(RegExp(r'^Row 1, column 1 — ')), seconds: 60);
  await waitFor(t, boxPicker('Box 1\n35 pieces'));
}

/* The title: the design's name, a button that opens My designs. */
final title = find.byKey(const ValueKey('phone-title'));
String titleOf(WidgetTester t) => t.widget<Pressable>(title).label ?? '';

/* The saved design on the board is named `name`. The title is not typed into: My designs' ⋯ → Rename gives it, and My
   designs is closed again after. The test's own text input stands in for the keyboard: an integration test leaves it
   unregistered, and in a browser the keys would otherwise go to the page's hidden text field. */
Future<void> nameTheDesign(WidgetTester t, String name) async {
  await tapIt(t, title); await settle(t, 1);
  final more = inSheet(find.bySemanticsLabel('More'));
  expect(more, findsOneWidget, reason: 'one saved design, the one on the board');
  await tapIt(t, more); await settle(t, 1);
  // Registered before the dialog opens: its field takes the focus as it comes, and so its input connection.
  final dialog = find.byType(AlertDialog);
  t.testTextInput.register();
  try {
    await tapIt(t, inSheet(find.text('Rename'))); await settle(t, 1);
    await t.enterText(find.descendant(of: dialog, matching: find.byType(EditableText)), name);
    await t.pumpAndSettle();
    expect(find.descendant(of: dialog, matching: find.text(name)), findsOneWidget, reason: 'the new name is in the field');
    await tapIt(t, find.descendant(of: dialog, matching: find.text('Rename')));
    await settle(t, 1);
  } finally {
    t.testTextInput.unregister();
  }
  await waitUntil(t, () => titleOf(t) == name);
  await settle(t, 1);
  expect(inSheet(find.text(name)), findsOneWidget, reason: 'My designs says the new name');
  await closeSheet(t);
  expect(find.byType(BottomSheet), findsNothing, reason: 'My designs is closed');
}

/* The design on the board, saved and named `name`. */
Future<void> saveDesignNamed(WidgetTester t, String name) async {
  await waitFor(t, find.bySemanticsLabel(RegExp(r'^Row 1, column 1 — ')), seconds: 60);
  await tapIt(t, find.byKey(const ValueKey('phone-save')));
  final db = appShelf(t).db;
  var designs = await db.select(db.designs).get();
  for (var i = 0; i < 300 && designs.isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
    designs = await db.select(db.designs).get();
  }
  expect(designs, hasLength(1), reason: 'Save kept the design');
  await settle(t);
  await nameTheDesign(t, name);
}

/* My designs: the saved designs' names, opened from the title. Closed again with its ✕. */
Future<void> openMyDesigns(WidgetTester t) async {
  await tapIt(t, title); await settle(t, 1);
  await waitFor(t, inSheet(find.text('My designs')));
}

/* Share → `row` (Save photo, Print pattern PDF): the board saved as it is first, the sheet opened, the row pressed. The
   sheet closes once the file is handed over. */
Future<void> exportRow(WidgetTester t, String row) async {
  await tapIt(t, find.byKey(const ValueKey('phone-export')));
  await waitFor(t, inSheet(find.text(row)), seconds: 60);
  await tapIt(t, inSheet(find.text(row)));
}

/* ≡ → Back up or move to another device → `row`. */
Future<void> backupRow(WidgetTester t, String row) async {
  await tapIt(t, find.byKey(const ValueKey('phone-menu'))); await settle(t, 1);
  await tapIt(t, find.descendant(of: find.byKey(const ValueKey('menu-panel')), matching: find.text('Back up or move to another device')));
  await settle(t, 1);
  await tapIt(t, inSheet(find.text(row)));
}
