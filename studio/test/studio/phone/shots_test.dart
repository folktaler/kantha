import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/sample_box.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/studio/controller.dart';
import '../../support/db.dart';
import '../../support/fonts.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';

/* The phone redesign's screenshots, shots/ beside this file, as golden files: the studio at an
   iPhone 13's 390 × 844 at 3×, with its real safe-area insets and the bundled faces; 10 and 11 at a 1360 × 880 desk
   at 2×, the one screen in its centred column (2026-10-11 one-screen spec). The earlier shot folders were
   made by a Playwright script against a live build; these come from the widget tree, so they show exactly what the
   app lays out, and a browser's own rendering is not in them.

   Skipped in a normal run: pixels differ from machine to machine (the font rasteriser, the engine), so the suite does
   not depend on them. To make them again, remove the skip and run
   `flutter test --update-goldens test/studio/phone/shots_test.dart`; run it once more without the flag to see they
   match, then put the skip back. */
const _skip = 'golden shots; run with --update-goldens to refresh';
const _shots = 'shots';

/* The faces the screens use: Geist, Newsreader and Public Sans, and Material's icons (the How to arrow). The Tabler
   icons are drawn from SVG and need no font. */
Future<void> _faces() async {
  await loadFonts();
  final root = Platform.environment['FLUTTER_ROOT'];
  final material = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (root != null && material.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(material.readAsBytesSync())))).load();
  }
}

/* An iPhone 13: 1170 × 2532 at 3×, its status bar 47 tall and its home indicator 34. */
Future<void> _iPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  await letWork(tester, turns: 10);
}

/* A desk: a 1360 × 880 window at 2×, no insets. The studio is its 600 px column, centred (2026-10-11 one-screen spec). */
Future<void> _desk(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1360 * 2, 880 * 2);
  tester.view.devicePixelRatio = 2;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  await letWork(tester, turns: 10);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  // The cloth's pictures are decoded off the fake clock.
  await letWork(tester, turns: 10);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_shots/$name.png'));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/* The Sample box, whose cloth is painted, not photographed (a fixture photo is not decoded on the test's clock). */
Future<StudioController> _onSample(WidgetTester tester, {CaptureDelivery? delivery}) async {
  final shelf = Shelf(memoryDb());
  await tester.runAsync(() => makeSampleBox(shelf));
  return pumpStudio(tester, on: shelf, size: phone, delivery: delivery);
}

/* The studio on a phone (or on a desk), the faces loaded. */
Future<StudioController> _studio(WidgetTester tester, Future<StudioController> Function() pump, {bool desk = false}) async {
  // No DEBUG ribbon: the app as she sees it.
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
  await tester.runAsync(_faces);
  final c = await pump();
  await (desk ? _desk(tester) : _iPhone(tester));
  return c;
}

void main() {
  group('the phone redesign\'s shots', () {
    testWidgets('01 the Sample board, Design tab', (tester) async {
      await _studio(tester, () => _onSample(tester));
      await _shoot(tester, '01-patterns');
    });

    testWidgets('02 the Cloth box tab', (tester) async {
      await _studio(tester, () => _onSample(tester));
      await _tap(tester, key('tab-cloth'));
      await _shoot(tester, '02-cloth-box');
    });

    testWidgets('03 the Design tab, stitches on', (tester) async {
      await _studio(tester, () => _onSample(tester));
      await _tap(tester, key('stitch-switch'));
      await _shoot(tester, '03-design-stitches');
    });

    testWidgets('04 Share', (tester) async {
      await _studio(tester, () => _onSample(tester, delivery: CaptureDelivery()));
      await openShare(tester);
      await _shoot(tester, '04-export');
    });

    testWidgets('05 My designs', (tester) async {
      final c = await _studio(tester, () => _onSample(tester));
      await saveAs(tester, c, 'Marigold');
      c.newDesign();
      await letWork(tester, done: () => !c.solving && c.grid != null);
      await saveAs(tester, c, 'Indigo border');
      await _tap(tester, key('phone-title'));
      await _shoot(tester, '05-my-designs');
    });

    testWidgets('06 Add a piece, after one add', (tester) async {
      final c = await _studio(tester, () => pumpStudio(tester, size: phone, photos: FixturePhotos(), solver: StockSolver()));
      final box = await boxWith(tester, c, 0);
      await _tap(tester, key('tab-cloth'));
      await _tap(tester, key('add-pieces'));
      final photo = inSheet(find.text('Photo of the piece'));
      await tester.tap(photo);
      await letWork(tester, turns: 10);
      final add = inSheet(find.text('Add to box'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await letWork(tester, done: () => c.piecesIn(box) == 1);
      final top = tester.state<ScrollableState>(inSheet(find.byType(Scrollable)).first);
      top.position.jumpTo(0);
      await _shoot(tester, '06-add-a-piece');
    });

    testWidgets('07 an empty box: the tooltip', (tester) async {
      final c = await _studio(tester, () => pumpStudio(tester, size: phone, solver: StockSolver()));
      await boxWith(tester, c, 0);
      await _tap(tester, key('tab-cloth'));
      await _shoot(tester, '07-empty-box');
    });

    testWidgets('08 a box of 10 pieces: the banner and the dashed squares', (tester) async {
      final c = await _studio(tester, () => pumpStudio(tester, size: phone, solver: StockSolver()));
      await boxWith(tester, c, 10);
      await _shoot(tester, '08-short-box');
    });

    testWidgets('09 the toast after the first Save', (tester) async {
      await _studio(tester, () => _onSample(tester));
      await tester.tap(key('phone-save'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_shots/09-saved-toast.png'));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('10 on a desk: the Sample board, Design tab, in the centred column', (tester) async {
      await _studio(tester, () => _onSample(tester), desk: true);
      await _shoot(tester, '10-desk-patterns');
    });

    testWidgets('11 on a desk: Share, the sheet as wide as the column', (tester) async {
      await _studio(tester, () => _onSample(tester, delivery: CaptureDelivery()), desk: true);
      await openShare(tester);
      await _shoot(tester, '11-desk-export');
    });
  }, skip: _skip);
}
