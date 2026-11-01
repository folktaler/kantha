import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'dart:ui' show Tristate;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/l10n/words.dart';
import 'package:kantha_studio/solver/compile.dart' show Unfillable;
import 'package:kantha_studio/solver/geometry.dart' show Mount;
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve_layout.dart' show LayoutSolve;
import 'package:kantha_studio/studio/painters.dart' show StitchPainter, hexColor;
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/fonts.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart' show QuickSolver, ShelfForTest, fixtureJpeg, measuredFor;

/* The Design tab (redesign handover, "Dock panel — Patterns tab"; decision 11; renamed Design by the owner, 19 Oct). */
Finder tile(LayoutKey k) => key('tile-${k.name}');
final strip = key('dock-patterns');

/* Whether a tile wears the selected mark, the white ↻ in its blue square (owner, 31 Oct 2026: press again for a new
   arrangement). */
bool checked(LayoutKey k) => find.descendant(of: tile(k), matching: find.byType(tabler.RotateClockwise)).evaluate().isNotEmpty;

/* When the press-again note was remembered as shown on this device, if it was. */
Future<String?> said(WidgetTester tester, StudioController c) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  return tester.runAsync<String?>(() => c.shelf.setting(StudioController.patternAgainKey));
}

/* The opacity a tile is drawn at. */
double opacityOf(WidgetTester tester, LayoutKey k) =>
    tester.widget<Opacity>(find.descendant(of: tile(k), matching: find.byType(Opacity)).first).opacity;


/* A solver that finds no arrangement, as the real one answers for cloth it cannot place. */
class _NoArrangement extends QuickSolver {
  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) async =>
      const LayoutSolve(false, null, null);
}

void main() {
  testWidgets('on a phone the Design tab holds every pattern tile in order, 80 × 124, the first selected; no line over the board',
      (tester) async {
    final c = await pumpStudio(tester, size: phone);
    expect(c.layout, LayoutKey.contrast);
    expect(find.descendant(of: key('dock-panel'), matching: strip), findsOneWidget);
    double? last;
    for (final k in layoutKeys) {
      expect(tile(k), findsOneWidget, reason: k.name);
      final r = tester.getRect(tile(k));
      expect((r.width, r.height), (80.0, 124.0), reason: k.name);
      if (last != null) expect(r.left, closeTo(last + 80 + 8, 0.5), reason: '${k.name}: 8 px after the one before');
      last = r.left;
    }
    final first = tester.getRect(tile(LayoutKey.contrast)), panel = tester.getRect(key('dock-panel'));
    expect(first.left, closeTo(16, 0.5));
    expect(first.top, closeTo(panel.top + 8, 0.5), reason: '8 px under the panel\'s top');
    expect(checked(LayoutKey.contrast), isTrue);
    expect(layoutKeys.where(checked), [LayoutKey.contrast]);
    // The name under the preview: 13.83/500 (the tag role), 14 px lines, two at most, centred.
    final name = tester.widget<Text>(find.descendant(of: tile(LayoutKey.contrast), matching: find.text(c.words.layoutTitle(LayoutKey.contrast))));
    expect((name.style!.fontSize, name.style!.fontWeight), (13.83, FontWeight.w500));
    expect(name.style!.height! * name.style!.fontSize!, closeTo(14.0, 0.01));
    expect((name.maxLines, name.textAlign), (2, TextAlign.center));

    // No line describing the pattern over the board (owner, 19 Oct).
    expect(key('pattern-description'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone a tap on Gradient arranges it: its tile selected, the title its own', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await tester.tap(find.descendant(of: strip, matching: find.text('Gradient')));
    await tester.pumpAndSettle();
    expect(c.layout, LayoutKey.gradient);
    expect(layoutKeys.where(checked), [LayoutKey.gradient]);
    expect(find.descendant(of: key('phone-title'), matching: find.text('Gradient')), findsOneWidget);
  });

  testWidgets('the chosen tile says to press it again; the first press on this device says so in a note, once', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await pumpStudio(tester, size: phone);
    const again = 'Press Chess again for a new arrangement.';
    final heard = tester.getSemantics(find.bySemanticsLabel('Chess\n$again')).getSemanticsData();
    expect((heard.flagsCollection.isButton, heard.flagsCollection.isSelected), (true, Tristate.isTrue));
    handle.dispose();

    Future<void> press(String name) async {
      await tester.tap(find.descendant(of: strip, matching: find.text(name)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    final grid = c.grid;
    await press('Chess');
    expect(find.descendant(of: key('phone-toast'), matching: find.text(again)), findsOneWidget);
    expect(c.grid, isNot(grid), reason: 'pressed again, a new arrangement');
    expect(await said(tester, c), isNotNull, reason: 'said, so remembered');
    await tester.pump(const Duration(seconds: 3));
    await press('Gradient');
    expect(find.text('Press Gradient again for a new arrangement.'), findsNothing, reason: 'once on this device');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('another note that goes out as the press deals is not spent on: the next press that deals says it',
      (tester) async {
    final c = await pumpStudio(tester, size: phone);
    const other = 'The cloth could not be read.';
    // The other note goes out as the new arrangement lands.
    final was = c.grid;
    void other0() {
      if (c.grid == was || c.note == other) return;
      c.note = other;
      // ignore: invalid_use_of_protected_member
      c.notifyListeners();
    }
    c.addListener(other0);
    await tester.tap(find.descendant(of: strip, matching: find.text('Chess')));
    await tester.pump();
    c.removeListener(other0);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text(other), findsOneWidget);
    expect(find.textContaining('again for a new arrangement'), findsNothing);
    expect(await said(tester, c), isNull, reason: 'kept for the next press');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.descendant(of: strip, matching: find.text('Gradient')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('Press Gradient again for a new arrangement.'), findsOneWidget);
    expect(await said(tester, c), isNotNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('on an empty box the chosen tile has the check, not ↻, and a press neither re-arranges nor spends the note',
      (tester) async {
    final c = await pumpStudio(tester, size: phone, seeded: false);
    expect((c.grid, c.solving), (null, false));
    expect(checked(c.layout), isFalse);
    expect(find.descendant(of: tile(c.layout), matching: find.byType(tabler.Check)), findsOneWidget);
    expect(tester.widget<Pressable>(tile(c.layout)).label, isNot(contains('again for a new arrangement')),
        reason: 'no "press again" while nothing would deal');
    await tester.tap(tile(LayoutKey.gradient));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('again for a new arrangement'), findsNothing);
    expect(await said(tester, c), isNull, reason: 'kept for a press that deals');
  });

  testWidgets('a press whose solve fails leaves the board empty, says no press-again note and keeps it', (tester) async {
    final c = await pumpStudio(tester, size: phone, solver: _NoArrangement());
    expect(c.grid, isNull);
    await tester.tap(find.descendant(of: strip, matching: find.text('Gradient')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(c.grid, isNull);
    expect(find.textContaining('again for a new arrangement'), findsNothing);
    expect(await said(tester, c), isNull, reason: 'kept for a press that deals');
  });

  // A saved design held open while no box can fill and there is no Sample box: a press only chooses the pattern and
  // empties the board, so the tile does not offer a new arrangement.
  testWidgets('on a held design with no box that can fill, the chosen tile has the check and does not say to press again',
      (tester) async {
    final c = await pumpStudio(tester, size: phone, seeded: false);
    await tester.runAsync(() async {
      final box = await c.shelf.makeBox();
      final ids = [for (var i = 0; i < 5; i++) await c.shelf.addPiecesForTest(box, 7)];
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await c.save();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await c.shelf.editCloth(ids.last, fabric: 'Cotton', pieces: 6);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c.openSaved(c.saved.single), isTrue);
    });
    await tester.pumpAndSettle();
    expect((c.grid != null, c.canDeal), (true, false));
    expect(checked(c.layout), isFalse);
    expect(tester.widget<Pressable>(tile(c.layout)).label, isNot(contains('again for a new arrangement')));
  });

  testWidgets('a device that has had the note does not have it again on its next visit', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await tester.runAsync(() => c.shelf.setSetting(StudioController.patternAgainKey, '2026-10-31T00:00:00Z'));
    await tester.tap(find.descendant(of: strip, matching: find.text('Gradient')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('Press Gradient again for a new arrangement.'), findsNothing);
    await tester.pumpAndSettle();
  });

  // A pattern the box cannot fill, pressed (the tile itself only says why; the controller still deals): its own note
  // stays, and the press-again note is neither said nor spent.
  testWidgets('a press that says it cannot fill keeps that note, and the press-again note waits', (tester) async {
    final c = await pumpOnSample(tester, size: phone);
    await tester.runAsync(() async {
      final greys = await c.shelf.makeBox();
      for (final l in [25.0, 50.0, 75.0]) {
        await c.shelf.addCloth(box: greys, photo: fixtureJpeg, measured: measuredFor(l: l), fabric: 'Cotton', pieces: 12);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.openBox(greys);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final bad = c.feasible.entries.firstWhere((e) => !e.value.fills);
    final cannot = c.words.canvasCantFill(c.words.notFillable(bad.value.why!));
    c.loadLayout(bad.key);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(c.grid, isNotNull, reason: 'dealt');
    expect(find.text(cannot), findsOneWidget);
    expect(find.textContaining('again for a new arrangement'), findsNothing);
    expect(await said(tester, c), isNull, reason: 'kept for a press that deals without a note');
    await tester.pump(const Duration(seconds: 3));
  });

  // The Sample box fills every pattern, so a box of three greys (36 pieces) stands in: it has no red for the heart.
  testWidgets('on a phone a pattern the box cannot fill stays in the strip at 35 %; a tap says why and changes nothing',
      (tester) async {
    final c = await pumpOnSample(tester, size: phone);
    expect(c.feasible.values.every((f) => f.fills), isTrue, reason: 'the Sample box fills every pattern');
    await tester.runAsync(() async {
      final greys = await c.shelf.makeBox();
      for (final l in [25.0, 50.0, 75.0]) {
        await c.shelf.addCloth(box: greys, photo: fixtureJpeg, measured: measuredFor(l: l), fabric: 'Cotton', pieces: 12);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.openBox(greys);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final bad = c.feasible.entries.firstWhere((e) => !e.value.fills);
    final good = c.feasible.entries.firstWhere((e) => e.value.fills).key;
    final k = bad.key;
    expect(opacityOf(tester, k), 0.35);
    expect(opacityOf(tester, good), 1.0);
    final was = c.layout, name = c.name;
    await tester.dragUntilVisible(tile(k), strip, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(tile(k));
    await tester.pump();
    final why = c.words.canvasLayoutCannot(c.words.layoutTitle(k), c.words.notFillable(bad.value.why ?? Unfillable.fewPieces));
    expect(find.descendant(of: key('phone-toast'), matching: find.text(why)), findsOneWidget);
    expect((c.layout, c.name), (was, name));
    expect(checked(k), isFalse);
    await tester.pump(const Duration(milliseconds: 2800));
  });

  testWidgets('on a phone the strip scrolls sideways to the last pattern, Heart', (tester) async {
    await pumpStudio(tester, size: phone);
    expect(tester.getRect(tile(LayoutKey.heart)).left, greaterThan(phone.width), reason: 'out of sight at first');
    final at = tester.getRect(tile(LayoutKey.contrast)).left;
    await tester.drag(strip, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(tile(LayoutKey.contrast)).left, lessThan(at - 200), reason: 'a drag left moves the strip');
    await tester.dragUntilVisible(tile(LayoutKey.heart), strip, const Offset(-300, 0));
    await tester.pumpAndSettle();
    final heart = tester.getRect(tile(LayoutKey.heart));
    expect(heart.left >= 0 && heart.right <= phone.width, isTrue, reason: '$heart');
  });

  group('Show stitches on the Design tab (owner, 20 and 21 Oct)', () {
    final stitches = key('stitch-switch');
    StitchPainter painter(WidgetTester tester) => tester.widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter).whereType<StitchPainter>().single;
    ScrollPosition design(WidgetTester tester) => tester.state<ScrollableState>(
        find.descendant(of: key('dock-design'), matching: find.byType(Scrollable)).first).position;
    Finder dot() => find.descendant(of: key('stitch-thread'), matching: find.byWidgetPredicate((w) =>
        w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).shape == BoxShape.circle));

    testWidgets('on a phone Show stitches is one row under the tiles: the switch, its words, then the colour, off at first',
        (tester) async {
      final c = await pumpStudio(tester, size: phone);
      final panel = tester.getRect(key('dock-panel')), row = tester.getRect(stitches);
      expect(row.top, greaterThanOrEqualTo(tester.getRect(tile(LayoutKey.contrast)).bottom), reason: 'under the tiles');
      expect(row.bottom, lessThanOrEqualTo(panel.bottom), reason: 'inside the panel');
      expect((row.left, row.right), (panel.left, panel.right));
      expect(row.height, 44.0);
      expect(design(tester).maxScrollExtent, 0, reason: 'the tiles and the row fit the panel at normal text size');
      // One line, left to right: the switch 16 px in, then "Show stitches" (sentence case), then the dot and the colour.
      final best = c.recommended.first.thread;
      final name = c.words.stitchColour(best.key);
      final track = tester.getRect(key('stitch-switch-track'));
      final words = tester.getRect(find.descendant(of: stitches, matching: find.text('Show stitches')));
      final spot = tester.getRect(dot()), colour = tester.getRect(find.descendant(of: key('stitch-thread'), matching: find.text(name)));
      expect(track.left, closeTo(panel.left + 16, 0.5));
      expect(track.right, lessThan(words.left));
      expect(words.right, lessThan(spot.left));
      expect(spot.right, lessThan(colour.left));
      for (final r in [words, spot, colour]) {
        expect(r.center.dy, closeTo(track.center.dy, 1), reason: 'one row');
      }
      expect(find.text('STITCHES'), findsNothing);
      // Off, and the colour still shows: the winning thread, as a dot in its colour and its plain name.
      expect(tester.widget<Pressable>(stitches).toggled, isFalse);
      expect(c.stitch, isFalse);
      expect(c.thread, best.key);
      expect(['Cream', 'Red', 'Blue', 'Yellow', 'Green', 'Black'], contains(name));
      expect((tester.widget<Container>(dot()).decoration! as BoxDecoration).color, hexColor(best.hex));
      // The spacing is not said, and there is no density or thread choice: no Standard, no Off, no Open.
      expect(key('stitch-spacing'), findsNothing);
      expect(find.textContaining('rows of'), findsNothing);
      for (final w in ['Standard', 'Off', 'Open']) {
        expect(find.text(w), findsNothing, reason: w);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a screen reader hears Show stitches, on or off, then the colour', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await pumpStudio(tester, size: phone);
      final name = c.words.stitchColour(c.thread);
      SemanticsData heard() => tester.getSemantics(find.bySemanticsLabel('Show stitches')).getSemanticsData();
      var d = heard();
      expect((d.label, d.value, d.flagsCollection.isToggled), ('Show stitches', name, Tristate.isFalse));
      await tester.tap(stitches);
      await tester.pumpAndSettle();
      d = heard();
      expect((d.label, d.value, d.flagsCollection.isToggled), ('Show stitches', name, Tristate.isTrue));
      handle.dispose();
    });

    testWidgets('on a phone a tap anywhere on the row turns the stitches on and off; the board draws them Open in the colour',
        (tester) async {
      final c = await pumpStudio(tester, size: phone);
      final name = c.words.stitchColour(c.thread);
      await tester.tap(find.descendant(of: key('stitch-thread'), matching: find.text(name)));
      await tester.pumpAndSettle();
      expect(c.stitch, isTrue);
      expect(tester.widget<Pressable>(stitches).toggled, isTrue);
      // The colour stays as it was, and still nothing about spacing.
      expect(find.descendant(of: key('stitch-thread'), matching: find.text(name)), findsOneWidget);
      expect(find.textContaining('rows of'), findsNothing);
      final p = painter(tester);
      expect((p.density.key, p.density.rows, p.density.per, p.thread.key), ('open', 5, 5, c.thread));
      await tester.tap(find.descendant(of: stitches, matching: find.text('Show stitches')));
      await tester.pumpAndSettle();
      expect(c.stitch, isFalse);
      expect(find.descendant(of: key('stitch-thread'), matching: find.text(name)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a phone the thread follows the design when the pattern changes', (tester) async {
      final c = await pumpStudio(tester, size: phone);
      await tester.tap(stitches);
      await tester.pumpAndSettle();
      for (final k in [LayoutKey.gradient, LayoutKey.contrast]) {
        await tester.tap(tile(k));
        await tester.pumpAndSettle();
        final best = c.recommended.first.thread.key;
        expect(c.thread, best, reason: k.name);
        expect(painter(tester).thread.key, best, reason: k.name);
        expect(find.descendant(of: key('stitch-thread'), matching: find.text(c.words.stitchColour(best))),
            findsOneWidget, reason: k.name);
      }
    });

    testWidgets('on a phone with its text at 130 % nothing runs over the tabs; larger text scrolls the panel', (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(loadFonts);
      // Every overflow is caught, not only the first: one in the dock fails the test. At 200 % the top bar's row
      // overflows (it did before the dock changed); the dock is what is checked here.
      final overflows = <String>[];
      final was = FlutterError.onError;
      FlutterError.onError = (d) {
        final all = d.toString();
        if (all.contains('overflowed') && !all.contains('phone_studio.dart')) overflows.add(all);
      };
      addTearDown(() => FlutterError.onError = was);
      for (final scale in [1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await pumpStudio(tester, size: phone);
        expect(overflows, isEmpty, reason: '$scale: no overflow in the dock');
        for (final k in ['rows-fewer', 'rows-more', 'columns-fewer', 'columns-more']) {
          final r = tester.getRect(key(k));
          expect(r.right, lessThanOrEqualTo(phone.width - 16 + 0.5), reason: '$scale: $k inside the panel');
        }
        for (final w in ['Rows', 'Columns']) {
          final words = tester.renderObject<RenderParagraph>(find.descendant(of: key('board-size'), matching: find.text(w)));
          expect(words.didExceedMaxLines, isFalse, reason: '$scale: "$w" whole, not cut short');
        }
        // Stacked, Rows over Columns, their minus buttons line up.
        final rows = tester.getRect(key('rows-fewer')), columns = tester.getRect(key('columns-fewer'));
        if (rows.top != columns.top) expect(rows.left, columns.left, reason: '$scale: stacked, lined up');
        final panel = tester.getRect(key('dock-panel'));
        if (scale == 2.0) expect(design(tester).maxScrollExtent, greaterThan(0), reason: 'the row is taller than the panel');
        await tester.drag(key('dock-design'), const Offset(0, -200));
        await tester.pumpAndSettle();
        final row = tester.getRect(stitches);
        expect(row.bottom, lessThanOrEqualTo(panel.bottom + 0.5), reason: '$scale: scrolled into the panel');
        expect(row.bottom, lessThanOrEqualTo(tester.getRect(key('dock-tabs')).top + 0.5));
      }
    });

    // Bold Text (iOS and Android) widens the words and the numbers: Rows and Columns go over each other as soon as
    // they would not fit, at every width across the change and at 130 %, with 12 rows and 12 columns.
    testWidgets('with Bold Text on, Rows and Columns are whole and nothing overflows at any phone width', (tester) async {
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(loadFonts);
      final overflows = <String>[];
      final was = FlutterError.onError;
      FlutterError.onError = (d) {
        final all = d.toString();
        if (all.contains('overflowed') && !all.contains('phone_studio.dart')) overflows.add(all);
      };
      addTearDown(() => FlutterError.onError = was);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(boldText: true);
      for (final scale in [1.0, 1.3]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final c = await pumpStudio(tester, size: phone);
        c.setBoardSize((rows: 12, cols: 12));
        await tester.pumpAndSettle();
        for (var w = 320.0; w <= 480; w += 2) {
          tester.view.physicalSize = Size(w, phone.height);
          await tester.pumpAndSettle();
          expect(overflows, isEmpty, reason: '$scale at $w: no overflow');
          for (final f in [find.text('Rows'), find.text('Columns'), key('rows-count'), key('columns-count')]) {
            final p = tester.renderObject<RenderParagraph>(find.descendant(of: key('board-size'), matching: f));
            expect(p.didExceedMaxLines, isFalse, reason: '$scale at $w: $f whole');
          }
          expect(tester.getRect(key('columns-more')).right, lessThanOrEqualTo(w - 16 + 0.5), reason: '$scale at $w');
        }
      }
    });

    testWidgets('the board keeps its size from tab to tab and when the stitches go on', (tester) async {
      await pumpStudio(tester, size: phone);
      final board = tester.getSize(key('phone-board'));
      await tester.tap(stitches);
      await tester.pumpAndSettle();
      expect(tester.getSize(key('phone-board')), board);
      for (final t in ['tab-cloth', 'tab-finish', 'tab-patterns']) {
        await tester.tap(key(t));
        await tester.pumpAndSettle();
        expect(tester.getSize(key('phone-board')), board, reason: t);
      }
    });
  });
}
