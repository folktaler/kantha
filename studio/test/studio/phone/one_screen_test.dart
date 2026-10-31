import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart' show Mount;
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/studio/board.dart';
import 'package:kantha_studio/studio/phone/phone_studio.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:kantha_studio/studio/pressable.dart';
import '../../support/fonts.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';
import '../../support/targets.dart';

/* One screen at every width (2026-10-11 one-screen spec, decisions 1, 2 and 8): the phone studio at every size, in a
   column at most 600 wide, centred on the canvas colour; then the phone redesign's
   acceptance checklist (11 Oct 2026), each line once. The details of each are
   pinned in the phone tests named after them. */
const savedFirst = 'Saved on this device. Back up from the menu to keep a copy.';

/* A tap whose work runs off the fake clock (a picture read, a piece measured, a cloth read): no settling on the tap,
   since a spinner turns until the work is done. */
Future<void> tapThenWork(WidgetTester tester, Finder f, {bool Function()? done}) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await letWork(tester, done: done, turns: done == null ? 10 : 60);
}

/* Closes the sheets that are open, the top one first, each with its ✕. */
Future<void> closeSheets(WidgetTester tester) async {
  for (var i = 0; i < 3 && sheet.evaluate().isNotEmpty; i++) {
    await tester.tap(inSheet(find.bySemanticsLabel('Close')).last);
    await tester.pumpAndSettle();
  }
  expect(sheet, findsNothing);
}

/* Save, and the shelf's watch caught up. */
Future<void> save(WidgetTester tester) async {
  await tester.tap(key('phone-save'));
  await letWork(tester, turns: 3);
}

/* The open sheet's own Material: its width and where it sits. */
Rect sheetRect(WidgetTester tester) =>
    tester.getRect(find.descendant(of: sheet, matching: find.byType(Material)).first);

/* The button that has the keyboard's focus. */
Pressable? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>();

/* Its name: what a screen reader hears, else the words on it. */
String focusedName() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  final p = focused();
  if (ctx == null || p == null) return '-';
  if (p.label != null) return p.label!;
  String? words;
  void walk(Element e) {
    if (words != null) return;
    final w = e.widget;
    if (w is Text) {
      words = w.data;
      return;
    }
    e.visitChildElements(walk);
  }
  (ctx as Element).visitChildElements(walk);
  return words ?? '?';
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pumpAndSettle();
}

void main() {
  for (final (what, size, width) in [('desk', desk, 600.0), ('laptop', laptop, 600.0), ('tablet', tablet, 600.0), ('phone', phone, 390.0)]) {
    testWidgets('on a $what the one screen: the phone studio in a column ${width.toInt()} wide, centred on the canvas colour; '
        'the board fits at 100 %', (tester) async {
      // Geist as the browser draws it.
      await tester.runAsync(loadFonts);
      final c = await pumpStudio(tester, size: size);
      expect(find.byType(PhoneStudio), findsOneWidget);
      for (final k in ['phone-topbar', 'dock-panel', 'dock-tabs', 'phone-canvas']) {
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(find.byType(TextField), findsNothing, reason: 'no name field in a header');
      final column = tester.getRect(find.byType(PhoneStudio));
      expect(column.width, width);
      expect(column.left, (size.width - width) / 2);
      expect(column.height, size.height);
      final ground = find.ancestor(of: find.byType(PhoneStudio), matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == PhonePalette.canvas));
      expect(ground, findsOneWidget, reason: 'outside the column, the canvas colour');
      expect(tester.getRect(ground), Offset.zero & size);
      final board = tester.getRect(find.byType(Board)), canvas = tester.getRect(key('phone-canvas'));
      expect(canvas.contains(board.topLeft) && canvas.contains(board.bottomRight), isTrue, reason: '$board in $canvas');
      expect(canvas.width, width);
      expect(board.width, lessThanOrEqualTo(width - 32), reason: '16 px each side');
      expect(c.percent, 100);
    });
  }

  // The column's edge (owner, 21 Oct): on a window wider than the column, a 1 px line in the border colour down each
  // side of it; below that the column is the window and has none.
  for (final (size, lines) in [(const Size(1280, 900), true), (phone, false)]) {
    testWidgets('at ${size.width.toInt()} wide the column has ${lines ? 'a 1 px line down each side' : 'no side lines'}',
        (tester) async {
      await pumpStudio(tester, size: size);
      final edge = tester.widget<DecoratedBox>(key('studio-column'));
      expect(tester.getRect(key('studio-column')), tester.getRect(find.byType(PhoneStudio)));
      expect(edge.position, DecorationPosition.foreground);
      final border = (edge.decoration as BoxDecoration).border;
      if (lines) {
        const line = BorderSide(color: PhonePalette.border);
        expect(border, const Border(left: line, right: line));
      } else {
        expect(border, isNull);
      }
    });
  }

  // Nothing over the board but the 4 cm line (owner, 19 Oct: no pattern description), on each mount.
  for (final (what, size) in [('desk', desk), ('laptop', laptop), ('tablet', tablet), ('phone', phone), ('short phone', const Size(390, 600))]) {
    for (final m in Mount.values) {
      testWidgets('on a $what shown ${m.name}, the board fits inside the canvas at 100 % with nothing to scroll', (tester) async {
        await tester.runAsync(loadFonts);
        final c = await pumpStudio(tester, size: size);
        c.setMount(m);
        await tester.pumpAndSettle();
        expect(c.mount, m);
        expect(key('pattern-description'), findsNothing);
        final board = tester.getRect(find.byType(Board)), canvas = tester.getRect(key('phone-canvas'));
        expect(canvas.contains(board.topLeft) && canvas.contains(board.bottomRight), isTrue, reason: '$board in $canvas');
        final scroll = tester.state<ScrollableState>(find.descendant(of: key('phone-canvas'), matching: find.byType(Scrollable)).first);
        expect(scroll.position.maxScrollExtent, 0, reason: 'nothing to scroll at the fitted scale');
        expect(c.percent, 100);
      });
    }
  }

  testWidgets('on a desk Share opens a sheet 600 wide, centred, with the toast inside the column', (tester) async {
    await pumpStudio(tester, size: desk, delivery: CaptureDelivery());
    await openShare(tester);
    final r = sheetRect(tester);
    expect(r.width, 600);
    expect(r.left, (desk.width - 600) / 2);
    expect(r.bottom, desk.height);
    await closeSheets(tester);
    await save(tester);
    final toast = tester.getRect(key('phone-toast')), column = tester.getRect(find.byType(PhoneStudio));
    expect(toast.left, column.left + 16);
    expect(toast.right, column.right - 16);
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pumpAndSettle();
  });

  testWidgets('a window resized with a sheet open: the sheet follows the column, 600 then 390 then 600', (tester) async {
    await pumpStudio(tester, size: desk);
    await tapAndSettle(tester, key('phone-title'));
    expect(sheetRect(tester).width, 600);
    tester.view.physicalSize = phone;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(sheetRect(tester).width, 390);
    expect(tester.getRect(find.byType(PhoneStudio)).width, 390);
    tester.view.physicalSize = desk;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(sheetRect(tester).width, 600);
    expect(sheetRect(tester).left, (desk.width - 600) / 2);
  });

  testWidgets('checklist: no popup on first launch; the storage toast on the first Save only', (tester) async {
    await pumpStudio(tester, size: phone, kept: true);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(sheet, findsNothing);
    await save(tester);
    expect(find.descendant(of: key('phone-toast'), matching: find.text(savedFirst)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pumpAndSettle();
    expect(find.text(savedFirst), findsNothing);
    await save(tester);
    expect(find.text(savedFirst), findsNothing, reason: 'the second Save says it no more');
  });

  testWidgets('checklist: the dock\'s three tabs, Cloth box, Design and Preview, left to right, each with its panel', (tester) async {
    await pumpStudio(tester, size: phone);
    final xs = [for (final t in ['tab-cloth', 'tab-patterns', 'tab-finish']) tester.getCenter(key(t)).dx];
    expect(xs, [...xs]..sort(), reason: 'Cloth box · Design · Preview (owner, 19 Oct)');
    expect(tester.widget<Pressable>(key('tab-patterns')).selected, isTrue, reason: 'the studio opens on Design');
    for (final (tab, words, panel) in [
      ('tab-cloth', 'Cloth box', 'dock-cloth'),
      ('tab-patterns', 'Design', 'dock-patterns'),
      ('tab-finish', 'Preview', 'dock-finish'),
    ]) {
      expect(find.descendant(of: key(tab), matching: find.text(words)), findsOneWidget, reason: words);
      await tester.tap(key(tab));
      await tester.pumpAndSettle();
      expect(find.descendant(of: key('dock-panel'), matching: key(panel)), findsOneWidget, reason: panel);
    }
  });

  testWidgets('checklist: one Share button, opening one sheet with Save photo and the stitching guide', (tester) async {
    await pumpStudio(tester, size: phone, delivery: CaptureDelivery());
    expect(find.descendant(of: key('phone-topbar'), matching: find.text('Share')), findsOneWidget);
    for (final gone in ['Export', 'DIY']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    await openShare(tester);
    expect(inSheet(find.text('Save photo')), findsOneWidget);
    expect(inSheet(find.text('Kantha stitching guide')), findsOneWidget);
  });

  testWidgets('checklist: ≡ holds Help, Privacy policy, Shop and Back up', (tester) async {
    await pumpStudio(tester, size: phone);
    await tapAndSettle(tester, key('phone-menu'));
    for (final w in ['Help', 'Privacy policy', 'Shop', 'Back up or move to another device']) {
      expect(inMenu(find.text(w)), findsOneWidget, reason: w);
    }
  });

  testWidgets('checklist: the shortfall banner and the dashed squares on a short box; the tooltip on an empty one', (tester) async {
    final c = await pumpPhone(tester);
    await boxWith(tester, c, 10);
    expect(key('shortfall-banner'), findsOneWidget);
    expectDashed(tester);
    await boxWith(tester, c, 0);
    expect(key('shortfall-banner'), findsNothing);
    expectDashed(tester);
    await tapAndSettle(tester, key('tab-cloth'));
    expect(key('start-here'), findsOneWidget);
  });

  testWidgets('checklist: a 0-left swatch is faded with the + badge, and still opens its cloth', (tester) async {
    final c = await pumpStudio(tester, size: phone, photos: FixturePhotos());
    await tapAndSettle(tester, key('tab-cloth'));
    final grid = c.grid!;
    final f = c.members(c.box).firstWhere(grid.contains);
    final cloth = c.cloth[f], used = grid.where((x) => x == f).length;
    await tester.runAsync(() => c.shelf.editCloth(cloth.id, fabric: cloth.fabric, pieces: used));
    await letWork(tester, done: () => c.cloth[f].stock == used);
    final s = key('swatch-${cloth.id}');
    await tester.ensureVisible(s);
    await tester.pumpAndSettle();
    expect(find.descendant(of: s, matching: find.text('0 left')), findsOneWidget);
    expect(find.descendant(of: s, matching: key('swatch-badge')), findsOneWidget);
    final chip = find.descendant(of: s, matching: key('swatch-chip'));
    expect(tester.widget<Opacity>(find.descendant(of: chip, matching: find.byType(Opacity)).first).opacity, lessThan(1));
    await tapThenWork(tester, s, done: () => sheet.evaluate().isNotEmpty);
    expect(inSheet(find.text('Pieces in the box')), findsOneWidget, reason: 'Fix this cloth');
  });

  testWidgets('checklist: Add a piece stays open between adds and says what it added', (tester) async {
    final c = await pumpStudio(tester, size: phone, photos: FixturePhotos(), solver: StockSolver());
    final box = await boxWith(tester, c, 0);
    await tapAndSettle(tester, key('tab-cloth'));
    await tapAndSettle(tester, key('add-pieces'));
    for (var n = 1; n <= 2; n++) {
      await tapThenWork(tester, inSheet(find.text('Photo of the piece')));
      await tapThenWork(tester, inSheet(find.text('Add to box')), done: () => c.piecesIn(box) == n);
      expect(c.piecesIn(box), n);
      expect(sheet, findsOneWidget, reason: 'open after add $n');
      expect(inSheet(key('cloth-added')), findsOneWidget, reason: 'what add $n put in');
    }
  });

  for (final (what, size) in [('phone', phone), ('desk', desk)]) {
    testWidgets('checklist: every target on a $what is at least 44 px, with each sheet open in turn', (tester) async {
      final c = await pumpStudio(tester, size: size, photos: FixturePhotos(), delivery: CaptureDelivery());
      await saveAs(tester, c, 'Areca');
      var screens = 0;
      void check(String what) {
        expect(checkTargets(tester, 44, allowed: phoneSizedItems), greaterThan(0), reason: what);
        screens++;
      }

      for (final tab in ['tab-cloth', 'tab-patterns', 'tab-finish']) {
        await tapAndSettle(tester, key(tab));
        check(tab);
      }
      // Design with stitches on: the thread and the spacing under the switch.
      await tapAndSettle(tester, key('tab-patterns'));
      await tapAndSettle(tester, key('stitch-switch'));
      check('Design, stitches on');

      await tapAndSettle(tester, key('phone-menu'));
      check('Menu');
      await tapAndSettle(tester, inMenu(find.text('Back up or move to another device')));
      check('Back up');
      await closeSheets(tester);

      await tapAndSettle(tester, key('phone-title'));
      check('My designs');
      await tapAndSettle(tester, inSheet(find.bySemanticsLabel('More')).first);
      check('a design\'s ⋯');
      await closeSheets(tester);

      await openShare(tester);
      check('Share');
      await closeSheets(tester);

      await tapAndSettle(tester, key('tab-cloth'));
      await tapAndSettle(tester, key('box-picker'));
      check('Your boxes');
      await closeSheets(tester);

      await tapAndSettle(tester, key('add-pieces'));
      check('Add a piece');
      await tapThenWork(tester, inSheet(find.text('Photo of the piece')));
      check('Add a piece, cropping');
      // Close adds the photo waiting first (DECISIONS 58).
      final before = c.cloth.length;
      await tester.tap(inSheet(find.bySemanticsLabel('Close')).last);
      await letWork(tester, done: () => c.cloth.length > before && sheet.evaluate().isEmpty);
      expect(sheet, findsNothing);
      expect(c.cloth, hasLength(before + 1));

      final id = c.cloth[c.members(c.box).first].id;
      await tapThenWork(tester, key('swatch-$id'), done: () => sheet.evaluate().isNotEmpty);
      check('Fix this cloth');
      await closeSheets(tester);
      expect(screens, 13);
    });
  }

  testWidgets('on a desk Tab goes ≡, the title, Save, Share, the open tab\'s controls, then the three tabs, and round again',
      (tester) async {
    final c = await pumpStudio(tester, size: desk);
    final names = <String>[];
    for (var i = 0; i < 40; i++) {
      await press(tester, LogicalKeyboardKey.tab);
      final n = focusedName();
      if (names.isNotEmpty && n == names.first) break;
      names.add(n);
    }
    final tiles = [for (final k in layoutKeys) tester.widget<Pressable>(key('tile-${k.name}')).label!];
    expect(names, ['Menu', c.name, 'Save', 'Share', ...tiles, 'Show stitches', 'Fewer rows', 'More rows', 'Fewer columns', 'More columns', 'Cloth box', 'Design', 'Preview']);
  });

  testWidgets('on a desk with the empty board zoomed and scrolled, Tab still goes the top bar, the squares, the panel, the tabs',
      (tester) async {
    final c = await pumpStudio(tester, size: desk, solver: StockSolver());
    await boxWith(tester, c, 0);
    c.zoomTo(160);
    await tester.pumpAndSettle();
    final canvas = tester.state<ScrollableState>(find.descendant(of: key('phone-canvas'), matching: find.byType(Scrollable)).first);
    expect(canvas.position.maxScrollExtent, greaterThan(100), reason: 'the squares go up under the top bar');
    canvas.position.jumpTo(canvas.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final names = <String>[];
    for (var i = 0; i < 80; i++) {
      await press(tester, LogicalKeyboardKey.tab);
      final n = focusedName();
      if (names.isNotEmpty && n == names.first) break;
      names.add(n);
    }
    final squares = [for (var r = 1; r <= 7; r++) for (var col = 1; col <= 5; col++) cellLabel(r, col)];
    final tiles = [for (final k in layoutKeys) tester.widget<Pressable>(key('tile-${k.name}')).label!];
    // Share waits for a board. The squares are the canvas's, all 35 between Save and the panel, row by row.
    expect(names.take(3), ['Menu', c.name, 'Save']);
    expect(names.sublist(3, 3 + squares.length), squares);
    expect(names.sublist(3 + squares.length), [...tiles, 'Show stitches', 'Fewer rows', 'More rows', 'Fewer columns', 'More columns', 'Cloth box', 'Design', 'Preview']);
  });

  for (final (what, size) in [('desk', desk), ('phone', phone)]) {
    testWidgets('on a $what an empty box: Tab from the first square goes along its row, as it is read', (tester) async {
      final c = await pumpStudio(tester, size: size, solver: StockSolver());
      await boxWith(tester, c, 0);
      expectDashed(tester);
      // Tabbed to from the top bar: the first square is the first of the canvas's.
      for (var i = 0; i < 10 && focusedName() != cellLabel(1, 1); i++) {
        await press(tester, LogicalKeyboardKey.tab);
      }
      expect(focusedName(), cellLabel(1, 1));
      await press(tester, LogicalKeyboardKey.tab);
      expect(focusedName(), cellLabel(1, 2));
      await press(tester, LogicalKeyboardKey.tab);
      expect(focusedName(), cellLabel(1, 3));
    });
  }

  testWidgets('on a desk Escape closes My designs, and the focus is back on the title', (tester) async {
    await pumpStudio(tester, size: desk);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.tab);
    expect(focused()?.key, const ValueKey('phone-title'));
    await press(tester, LogicalKeyboardKey.enter);
    expect(sheet, findsOneWidget, reason: 'My designs');
    await press(tester, LogicalKeyboardKey.escape);
    expect(sheet, findsNothing);
    expect(focused()?.key, const ValueKey('phone-title'));
  });

  testWidgets('on a desk ≡ under the mouse says Menu, white 13 on the dark ground', (tester) async {
    await pumpStudio(tester, size: desk);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(key('phone-menu')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final words = find.text('Menu');
    expect(words, findsOneWidget);
    final ground = find.ancestor(of: words, matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == PhonePalette.dark));
    expect(ground, findsOneWidget);
    expect(find.ancestor(of: words, matching: find.byWidgetPredicate(
        (w) => w is Padding && w.padding == const EdgeInsets.symmetric(horizontal: 12, vertical: 8))), findsOneWidget);
    final style = DefaultTextStyle.of(tester.element(words)).style.merge(tester.widget<Text>(words).style);
    expect((style.color, style.fontSize), (PhonePalette.white, 13.83));
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(words, findsNothing);
    await mouse.removePointer();
  });

  testWidgets('on a phone ≡ pressed and held opens the menu, and says no Menu over it: the tooltip is for a mouse', (tester) async {
    await pumpStudio(tester, size: phone);
    await tester.longPress(key('phone-menu'));
    await tester.pumpAndSettle();
    expect(key('menu-panel'), findsOneWidget, reason: 'the menu');
    // Nothing says Menu: no title, and nothing on the dark ground.
    expect(find.text('Menu'), findsNothing);
    expect(find.ancestor(of: find.text('Menu'), matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == PhonePalette.dark)),
        findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
