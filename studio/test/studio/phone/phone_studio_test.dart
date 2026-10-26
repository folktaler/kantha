import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/board.dart';
import 'package:kantha_studio/studio/phone/menu_panel.dart' show MenuIcon;
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:kantha_studio/studio/studio_screen.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/fonts.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';
import '../../support/targets.dart';


/* The phone studio (redesign handover, Screen: Studio): the top bar, the canvas, the dock panel and its tabs. */
final topbar = key('phone-topbar'), canvas = key('phone-canvas'), panel = key('dock-panel'), tabs = key('dock-tabs');
const savedFirst = 'Saved on this device. Back up from the menu to keep a copy.';
const nothingToSave = 'Add 35 pieces to your box before saving.';

/* The words inside a finder, and their style. */
TextStyle styleOf(WidgetTester tester, Finder inside, String words) =>
    tester.widget<Text>(find.descendant(of: inside, matching: find.text(words))).style!;

/* Whether a tab wears the selected tab's 2 px blue top edge. */
bool edged(WidgetTester tester, String tab) => find
    .descendant(of: key(tab), matching: find.byWidgetPredicate((w) {
      final d = w is Container ? w.decoration : null;
      return d is BoxDecoration && d.border is Border && (d.border! as Border).top == const BorderSide(width: 2, color: PhonePalette.blue);
    }))
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('on a phone the top bar sits under the status inset, 48 tall: ≡, the title, Save, Share, left to right', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 34, bottom: 14);
    tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 14);
    final c = await pumpStudio(tester, size: phone);
    final bar = tester.getRect(topbar);
    expect((bar.top, bar.height), (34.0, 48.0));
    final menu = tester.getRect(key('phone-menu')), title = tester.getRect(key('phone-title'));
    final save = tester.getRect(key('phone-save')), export = tester.getRect(key('phone-export'));
    expect((menu.left, menu.width, menu.height), (0.0, 48.0, 48.0));
    expect(find.bySemanticsLabel('Menu'), findsOneWidget);
    expect(find.descendant(of: key('phone-menu'), matching: find.byType(MenuIcon)), findsOneWidget);
    expect(tester.widget<MenuIcon>(find.byType(MenuIcon)).open, isFalse, reason: '≡, not ×');
    expect(title.left, greaterThanOrEqualTo(menu.right - 0.5));
    expect(save.left, greaterThanOrEqualTo(title.right - 0.5));
    expect(export.left, greaterThanOrEqualTo(save.right - 0.5));
    expect(export.right, closeTo(phone.width, 0.5));
    for (final (name, r) in [('title', title), ('Save', save), ('Share', export)]) {
      expect((r.top, r.height), (bar.top, 48.0), reason: name);
    }

    // The title: the design's name in Newsreader, the section-title role, one line ending in an ellipsis, and the
    // chevron; not a field.
    final name = styleOf(tester, key('phone-title'), c.name);
    expect((name.fontFamily, name.fontSize, name.fontWeight, name.color), ('Newsreader', 25.13, FontWeight.w400, PhonePalette.text));
    final text = tester.widget<Text>(find.descendant(of: key('phone-title'), matching: find.text(c.name)));
    expect((text.maxLines, text.overflow), (1, TextOverflow.ellipsis));
    expect(find.descendant(of: key('phone-title'), matching: find.byType(tabler.ChevronDown)), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Save in blue words on no ground; Share white on blue.
    expect(styleOf(tester, key('phone-save'), 'Save').color, PhonePalette.blue);
    expect(styleOf(tester, key('phone-export'), 'Share').color, PhonePalette.white);
    final ground = find.descendant(of: key('phone-export'), matching: find.byWidgetPredicate((w) =>
        w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == PhonePalette.blue));
    expect(ground, findsOneWidget);

    // The canvas between the bar and the dock; the dock panel 180 over the tabs, 48 and the home indicator.
    final area = tester.getRect(canvas), dock = tester.getRect(panel), foot = tester.getRect(tabs);
    expect(area.top, closeTo(bar.bottom, 0.5));
    expect(area.bottom, closeTo(dock.top, 0.5));
    expect(tester.widget<ColoredBox>(canvas).color, PhonePalette.canvas);
    expect(dock.height, 180.0);
    expect(foot.top, closeTo(dock.bottom, 0.5));
    expect((foot.height, foot.bottom), (48.0 + 14, phone.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone the dock tabs are a third each; Design is selected, and a tap on Cloth box selects it', (tester) async {
    await pumpStudio(tester, size: phone);
    for (final t in ['tab-cloth', 'tab-patterns', 'tab-finish']) {
      final r = tester.getRect(key(t));
      expect((r.width, r.height), (phone.width / 3, 48.0), reason: t);
    }
    void selected(String tab, String words) {
      for (final (t, w) in [('tab-cloth', 'Cloth box'), ('tab-patterns', 'Design'), ('tab-finish', 'Preview')]) {
        final on = t == tab, s = styleOf(tester, key(t), w);
        expect((s.fontSize, s.fontWeight, s.color), (14.83, FontWeight.w500, on ? PhonePalette.text : PhonePalette.text2),
            reason: '$w when $words is selected');
        expect(edged(tester, t), on, reason: '$w: the blue edge');
      }
    }
    selected('tab-patterns', 'Design');
    await tester.tap(key('tab-cloth'));
    await tester.pumpAndSettle();
    selected('tab-cloth', 'Cloth box');
  });

  for (final (what, sample) in [('her Box 1', false), ('the Sample box', true)]) {
    testWidgets('on a phone, on $what, the board at 100 % fits the canvas, across its width; every button at least 44 px', (tester) async {
      final c = sample ? await pumpOnSample(tester, size: phone) : await pumpStudio(tester, size: phone);
      final board = tester.getRect(find.byType(Board)), area = tester.getRect(canvas);
      expect(area.contains(board.topLeft) && area.contains(board.bottomRight), isTrue, reason: '$board in $area');
      expect(board.width, lessThanOrEqualTo(phone.width - 32));
      expect(c.percent, 100);
      expect(checkTargets(tester, 44), greaterThanOrEqualTo(7));
    });
  }

  // Moved from layout_test.dart's "every control" loop: the phone's own screens.
  testWidgets('on a phone every control is at least 44 px: the studio, the Menu, My designs with a design\'s ⋯ sheet open', (tester) async {
    await pumpStudio(tester, size: phone);
    expect(checkTargets(tester, 44), greaterThanOrEqualTo(7), reason: 'the studio');
    await tester.tap(key('phone-menu'));
    await tester.pumpAndSettle();
    expect(checkTargets(tester, 44), greaterThanOrEqualTo(3), reason: 'the Menu');
    await tester.tap(key('phone-menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('phone-save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    await tester.tap(key('phone-title'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    expect(checkTargets(tester, 44), greaterThan(5), reason: 'My designs');
  });

  testWidgets('on a phone a long name ends in an ellipsis in the title, and nothing overflows', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    c.setName('Marigold and indigo with a border of madder red');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final title = tester.getRect(key('phone-title')), save = tester.getRect(key('phone-save'));
    expect(title.right, lessThanOrEqualTo(save.left + 0.5));
    final words = tester.renderObject<RenderParagraph>(find.descendant(of: key('phone-title'), matching: find.byType(RichText)).first);
    expect(words.didExceedMaxLines, isTrue, reason: 'cut, with its ellipsis');
  });

  testWidgets('on a phone the first Save toasts where things are kept', (tester) async {
    await pumpStudio(tester, size: phone);
    await tester.tap(key('phone-save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text(savedFirst), findsOneWidget);
    expect(find.descendant(of: key('phone-toast'), matching: find.text(savedFirst)), findsOneWidget);
  });

  // On an empty box: a box of 10 pieces is still arranged today (the test solver deals any pieces it is given).
  testWidgets('on a phone Save on an empty box toasts that there is nothing to save, then the toast goes', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    late int made;
    await tester.runAsync(() async {
      made = await c.shelf.makeBox();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    c.openBox(made);
    await tester.pumpAndSettle();
    expect(c.grid, isNull);
    await tester.tap(key('phone-save'));
    await tester.pump();
    expect(find.text(nothingToSave), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text(nothingToSave), findsNothing);
  });

  // Review fix 1: no grid is not the same as fewer than 35 pieces.
  testWidgets('on a phone, on a full box, Save while the board is being arranged says nothing and saves nothing', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    c.grid = null;
    c.solving = true;
    await tester.tap(key('phone-save'));
    await tester.pump();
    expect(find.text(nothingToSave), findsNothing);
    expect(key('phone-toast'), findsNothing);
    expect(c.busy, isFalse, reason: 'no save was started');
  });

  testWidgets('on a phone, on a full box that could not be arranged, Save says why again, not that it needs 35 pieces', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    c.grid = null;
    c.solving = false;
    c.note = 'This pattern could not be made from this box.';
    await tester.tap(key('phone-save'));
    await tester.pump();
    expect(find.text(nothingToSave), findsNothing);
    expect(find.descendant(of: key('phone-toast'), matching: find.text('This pattern could not be made from this box.')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
  });

  testWidgets('on a phone, on a box of 10 pieces with nothing on the board, Save says it needs 35 pieces', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await tester.runAsync(() => c.shelf.addClothForTest(boxPieces: 10));
    await tester.pumpAndSettle();
    c.grid = null;
    c.solving = false;
    await tester.tap(key('phone-save'));
    await tester.pump();
    expect(find.text(nothingToSave), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
  });

  testWidgets('on a phone what the studio says is a toast, and the same words said again are a new one', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    c.note = 'The cloth could not be read.';
    // ignore: invalid_use_of_protected_member
    c.notifyListeners();
    await tester.pump();
    expect(find.descendant(of: key('phone-toast'), matching: find.text('The cloth could not be read.')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('The cloth could not be read.'), findsNothing);
    c.note = 'The cloth could not be read.';
    // ignore: invalid_use_of_protected_member
    c.notifyListeners();
    await tester.pump();
    expect(find.text('The cloth could not be read.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
  });

  // 548: an iPhone SE's window in Safari, its bars showing. The dock's panel is 180 tall (owner, 21 Oct).
  testWidgets('on a short phone (390 × 548) the board still fits, at 6 px a cm with no description over it', (tester) async {
    await tester.runAsync(loadFonts);
    final c = await pumpStudio(tester, size: const Size(390, 548));
    expect(tester.takeException(), isNull);
    final board = tester.getRect(find.byType(Board)), area = tester.getRect(canvas);
    expect(area.contains(board.topLeft) && area.contains(board.bottomRight), isTrue, reason: '$board in $area');
    expect(c.ppc, 6);
  });

  testWidgets('on a phone too short to fit the board (390 × 440) the canvas scrolls to the whole of it', (tester) async {
    await pumpStudio(tester, size: const Size(390, 440));
    expect(tester.takeException(), isNull);
    expect(find.byType(Board), findsOneWidget);
    final scroll = find.descendant(of: canvas, matching: find.byType(Scrollable)).first;
    expect(tester.state<ScrollableState>(scroll).position.maxScrollExtent, greaterThan(0));
    expect(tester.getRect(find.byType(Board)).bottom, greaterThan(tester.getRect(canvas).bottom));
  });

  // One screen at every width (2026-10-11 one-screen spec, decision 1).
  testWidgets('a phone that turns wide keeps the one screen, widened to its 600 px column, on the same controller', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    tester.view.physicalSize = tablet;
    await tester.pumpAndSettle();
    expect(topbar, findsOneWidget);
    expect(tester.getRect(topbar).width, 600);
    expect(tester.widget<StudioScreen>(find.byType(StudioScreen)).controller, same(c));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tablet turned to a phone and back is fitted to the tablet again', (tester) async {
    final c = await pumpStudio(tester, size: tablet);
    final desk = c.ppc;
    tester.view.physicalSize = phone;
    await tester.pumpAndSettle();
    expect(c.ppc, isNot(desk), reason: 'fitted to the phone');
    tester.view.physicalSize = tablet;
    await tester.pumpAndSettle();
    expect(c.ppc, desk);
  });

  testWidgets('on a phone ≡ opens the Menu: Help, Privacy policy, Shop and Back up, with their notes', (tester) async {
    await pumpStudio(tester, size: phone);
    await tester.tap(key('phone-menu'));
    await tester.pumpAndSettle();
    for (final w in ['Help', 'Privacy policy', 'Shop', 'catsofkochi shop', 'Back up or move to another device',
        'Your work is kept on this device only']) {
      expect(find.text(w), findsOneWidget, reason: w);
    }
    checkTargets(tester, 44);
  });

  testWidgets('on a phone Help opens the help page, Privacy policy the policy, Shop the shop, and the title My designs', (tester) async {
    final went = Went();
    await pumpWith(tester, went, size: phone);
    for (final row in ['Help', 'Privacy policy', 'Shop']) {
      await tester.tap(key('phone-menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      expect(find.text('catsofkochi shop'), findsNothing, reason: 'the sheet closed');
    }
    await tester.tap(key('phone-title'));
    await tester.pumpAndSettle();
    expect(went.log, ['link https://kantha.app/help', 'link https://kantha.app/policies/privacy',
        'link https://catsofkochi.com/shop/', 'designs']);
  });

  testWidgets('a tablet turned to a short phone toasts the first thing the studio says after it turns', (tester) async {
    final c = await pumpStudio(tester, size: tablet);
    // A phone too short to fit the board, so fitting it says nothing: the note is the first thing the phone hears.
    tester.view.physicalSize = const Size(390, 300);
    await tester.pumpAndSettle();
    expect(topbar, findsOneWidget);
    c.note = 'The cloth could not be read.';
    // ignore: invalid_use_of_protected_member
    c.notifyListeners();
    await tester.pump();
    expect(find.descendant(of: key('phone-toast'), matching: find.text('The cloth could not be read.')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
  });

  for (final (what, sample) in [('her Box 1', false), ('the Sample box', true)]) {
    testWidgets('on a phone, on $what, the 4 cm line is the only thing over the board, inside the canvas', (tester) async {
      sample ? await pumpOnSample(tester, size: phone) : await pumpStudio(tester, size: phone);
      expect(key('pattern-description'), findsNothing, reason: 'no description line (owner, 19 Oct)');
      final line = tester.getRect(find.descendant(of: find.byType(Board), matching: find.text('4 cm')));
      final area = tester.getRect(canvas);
      expect(line.top, greaterThanOrEqualTo(area.top + 24), reason: '$line under the canvas\'s 24 px');
    });
  }

  testWidgets('on a phone with a 34 px home indicator the toast stands 14 px over the dock', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    final c = await pumpStudio(tester, size: phone);
    c.note = 'The cloth could not be read.';
    // ignore: invalid_use_of_protected_member
    c.notifyListeners();
    await tester.pump();
    final toast = tester.getRect(key('phone-toast')), dock = tester.getRect(panel);
    expect(phone.height - toast.bottom, 180.0 + 48 + 34 + 14);
    expect(dock.top - toast.bottom, 14.0);
    await tester.pump(const Duration(milliseconds: 2800));
  });
}
