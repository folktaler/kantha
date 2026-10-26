import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/phone/cloth_sheet.dart' show loadClothSheets, loadClothSheetsWith;
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';
import '../../support/targets.dart';

/* The Cloth box tab (redesign handover, "Dock panel — Cloth box tab"). */
final picker = key('box-picker'), add = key('add-pieces'), swatches = key('dock-swatches');
const startHere = 'Start here: photograph your cloth to fill this box.';

Finder swatch(String id) => key('swatch-$id');
/* Add a piece and Fix this cloth open as sheets on a phone (cloth_sheet_test.dart). */

Future<void> openClothTab(WidgetTester tester) async {
  await tester.tap(key('tab-cloth'));
  await tester.pumpAndSettle();
}

/* Pieces of each cloth on the board, by its index in c.cloth. */
Map<int, int> used(StudioController c) {
  final use = <int, int>{};
  for (final f in c.grid ?? const <int>[]) {
    use[f] = (use[f] ?? 0) + 1;
  }
  return use;
}

void main() {
  testWidgets('on a phone, on the Sample box: the picker reads Sample and its pieces, Add pieces beside it, a swatch for each '
      'cloth with what is left', (tester) async {
    final c = await pumpOnSample(tester, size: phone);
    await openClothTab(tester);
    expect(find.descendant(of: picker, matching: find.text('Sample')), findsOneWidget);
    expect(find.descendant(of: picker, matching: find.text('70 pieces · sample cloth')), findsOneWidget);
    expect(find.bySemanticsLabel('Sample\n70 pieces · sample cloth'), findsOneWidget, reason: 'both lines are its name');
    expect(find.descendant(of: add, matching: find.text('Add pieces')), findsOneWidget);
    expect(find.descendant(of: add, matching: find.byType(tabler.Plus)), findsOneWidget);

    // Row 1: 16 px in from each side, 8 apart, 48 tall; the picker on the canvas ground.
    final p = tester.getRect(picker), a = tester.getRect(add), panel = tester.getRect(key('dock-panel'));
    expect((p.left, p.height, a.height), (16.0, 48.0, 48.0));
    expect(a.right, closeTo(phone.width - 16, 0.5));
    expect(a.left - p.right, closeTo(8, 0.5));
    expect(p.top, closeTo(panel.top + 8, 0.5));
    final name = tester.widget<Text>(find.descendant(of: picker, matching: find.text('Sample')));
    expect((name.style!.fontSize, name.style!.fontWeight), (15.81, FontWeight.w500));
    final note = tester.widget<Text>(find.descendant(of: picker, matching: find.text('70 pieces · sample cloth')));
    expect((note.style!.fontSize, note.style!.color), (13.83, PhonePalette.text2));

    // Row 2: the box's ten cloths, each with what is left of it.
    final members = c.members(c.box);
    expect(members.length, 10);
    final use = used(c);
    for (final m in members) {
      final cloth = c.cloth[m];
      final s = swatch(cloth.id);
      expect(s, findsOneWidget, reason: cloth.name);
      final left = cloth.stock - (use[m] ?? 0);
      expect(find.descendant(of: s, matching: find.text('$left left'), skipOffstage: false), findsOneWidget, reason: cloth.name);
    }
    final first = swatch(c.cloth[members.first].id);
    expect(tester.getSize(find.descendant(of: first, matching: key('swatch-chip'))), const Size(48, 48));
    expect(tester.getRect(first).left, 16);
    // The Sample box's swatches are buttons to fix the cloth, as on the desk; the name says what is left, then Fix this cloth.
    for (final m in members) {
      final cloth = c.cloth[m];
      final button = tester.widget(swatch(cloth.id));
      expect(button, isA<Pressable>(), reason: cloth.name);
      expect((button as Pressable).onPressed, isNotNull, reason: cloth.name);
      expect(button.label, endsWith(' · Fix this cloth'), reason: cloth.name);
    }
    await tester.tap(first);
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    expect(inSheet(find.bySemanticsLabel(c.cloth[members.first].name)), findsOneWidget, reason: 'Fix this cloth, titled with its name');
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Delete box'), findsOneWidget, reason: 'under the swatches, on a box that holds pieces (owner, 20 Oct)');
    expect(find.text(startHere), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone the picker opens Your boxes, and Add pieces asks to add to the box on the board', (tester) async {
    await pumpOnSample(tester, size: phone);
    await openClothTab(tester);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(inSheet(find.bySemanticsLabel('Add a piece')), findsOneWidget, reason: 'Add a piece, as a sheet');
    await tester.tap(inSheet(find.text('Done')));
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('Your boxes'), findsOneWidget, reason: 'the sheet');
  });

  testWidgets('on a phone a cloth whose pieces are all on the board shows 0 left, faded, with the blue + badge, and is still '
      'a button to fix it', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await openClothTab(tester);
    final use = used(c);
    final f = c.members(c.box).firstWhere(use.containsKey);
    final cloth = c.cloth[f];
    await tester.runAsync(() => c.shelf.editCloth(cloth.id, fabric: cloth.fabric, pieces: use[f]!));
    await letWork(tester, done: () => c.cloth[f].stock == use[f]);
    expect(c.grid, isNotNull, reason: 'the board stays as it is');
    final s = swatch(cloth.id);
    await tester.ensureVisible(s);
    await tester.pumpAndSettle();
    expect(find.descendant(of: s, matching: find.text('0 left')), findsOneWidget);
    final chip = find.descendant(of: s, matching: key('swatch-chip'));
    expect(tester.widget<Opacity>(find.descendant(of: chip, matching: find.byType(Opacity)).first).opacity, 0.45);
    final badge = find.descendant(of: s, matching: key('swatch-badge'));
    expect(tester.getSize(badge), const Size(20, 20));
    expect(tester.getRect(badge).bottomRight, tester.getRect(chip).bottomRight);
    expect(find.descendant(of: badge, matching: find.byType(tabler.Plus)), findsOneWidget);
    expect(find.ancestor(of: badge, matching: find.byType(Opacity)), findsNothing, reason: 'the badge at full opacity');
    expect(find.ancestor(of: find.descendant(of: s, matching: find.text('0 left')), matching: find.byType(Opacity)), findsNothing);
    final words = c.words.canvasSwatchAllUsed(cloth.name, '${use[f]}');
    expect(find.bySemanticsLabel(words), findsOneWidget);
    expect(tester.widget<Pressable>(s).onPressed, isNotNull);
    await tester.tap(s);
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    expect(inSheet(find.bySemanticsLabel(cloth.name)), findsOneWidget, reason: 'Fix this cloth, titled with its name');
  });

  testWidgets('on a phone an empty box of hers: Delete box and the tooltip pointing up at Add pieces, no swatches; Delete box '
      'asks first', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await openClothTab(tester);
    final box = (await tester.runAsync(() => c.shelf.makeBox()))!;
    await letWork(tester, done: () => c.ownBoxes.contains(box));
    c.openBox(box);
    await tester.pumpAndSettle();
    expect(find.descendant(of: picker, matching: find.text('Box 2')), findsOneWidget);
    expect(find.descendant(of: picker, matching: find.text('0 pieces')), findsOneWidget);
    expect(swatches, findsNothing);
    final delete = find.text('Delete box');
    expect(delete, findsOneWidget);
    expect(tester.widget<Text>(delete).style!.color, PhonePalette.red);
    expect(find.text(startHere), findsOneWidget);
    final tip = key('start-here'), caret = key('start-here-caret');
    expect(tester.getSize(tip).width, lessThanOrEqualTo(190));
    final words = tester.widget<Text>(find.text(startHere));
    expect((words.style!.fontSize, words.style!.color, words.style!.height), (14.83, PhonePalette.white, 1.417));
    final a = tester.getRect(add), k = tester.getRect(caret), t = tester.getRect(tip);
    expect(k.width, 12);
    expect(t.right - k.right, closeTo(24, 0.5), reason: 'the caret 24 px in from the tooltip\'s right');
    expect(k.center.dx, inInclusiveRange(a.left, a.right), reason: 'under Add pieces');
    expect(k.top, greaterThan(a.bottom));
    expect(tester.getRect(delete).left, lessThan(t.left), reason: 'Delete box at the left');
    expect(tester.takeException(), isNull);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text(c.words.boxesDeleteAsk('2')), findsOneWidget, reason: 'the existing question');
    await tester.tap(find.text('Delete'));
    await letWork(tester, done: () => !c.ownBoxes.contains(box));
    expect(c.ownBoxes.contains(box), isFalse);
  });

  testWidgets('at a desk the Delete box question is paper with 2 px corners, its answers 48 tall and in Geist', (tester) async {
    final c = await pumpStudio(tester);
    await openClothTab(tester);
    final box = (await tester.runAsync(() => c.shelf.makeBox()))!;
    await letWork(tester, done: () => c.ownBoxes.contains(box));
    c.openBox(box);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete box'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final ground = tester.widget<Material>(find.descendant(of: dialog, matching: find.byType(Material)).first);
    expect(ground.color, PhonePalette.white);
    expect(ground.shape, isA<RoundedRectangleBorder>().having((s) => s.borderRadius, 'corners', kControlRadius));
    final question = find.descendant(of: dialog, matching: find.text(c.words.boxesDeleteAsk('2')));
    expect(tester.widget<RichText>(find.descendant(of: question, matching: find.byType(RichText))).text.style!.fontFamily, 'Geist');
    final answers = find.descendant(of: dialog, matching: find.byType(TextButton));
    expect(answers, findsNWidgets(2));
    for (final a in answers.evaluate()) {
      final b = find.byWidget(a.widget);
      expect(tester.getSize(b).height, 48);
      final words = tester.widget<RichText>(find.descendant(of: b, matching: find.byType(RichText)));
      expect(words.text.style!.fontFamily, 'Geist');
    }
  });

  testWidgets('on a phone with no box at all: the picker reads Your boxes, the tooltip alone, Add pieces adds to a new box',
      (tester) async {
    final c = await pumpStudio(tester, size: phone, seeded: false);
    await openClothTab(tester);
    expect(c.ownBoxes, isEmpty);
    expect(find.descendant(of: picker, matching: find.text('Your boxes')), findsOneWidget);
    expect(find.text(startHere), findsOneWidget);
    expect(find.text('Delete box'), findsNothing);
    expect(swatches, findsNothing);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(inSheet(find.bySemanticsLabel('Add a piece')), findsOneWidget, reason: 'Add a piece, as a sheet');
  });

  group('when the sheets\' code does not load', () {
    tearDown(() => loadClothSheetsWith = loadClothSheets);

    testWidgets('Add pieces asks for it once more, and the sheet opens when the second load works', (tester) async {
      var asked = 0;
      loadClothSheetsWith = () async {
        if (++asked == 1) throw Exception('offline');
        await loadClothSheets();
      };
      await pumpStudio(tester, size: phone, seeded: false);
      await openClothTab(tester);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(asked, 2);
      expect(inSheet(find.bySemanticsLabel('Add a piece')), findsOneWidget);
      expect(inSheet(find.text('That did not work. Try again in a moment.')), findsNothing);
    });

    testWidgets('Add pieces, failing twice, opens the sheet with the words that it did not work', (tester) async {
      var asked = 0;
      loadClothSheetsWith = () async {
        asked++;
        throw Exception('offline');
      };
      await pumpStudio(tester, size: phone, seeded: false);
      await openClothTab(tester);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(asked, 2);
      expect(tester.takeException(), isA<Exception>(), reason: 'the second failure is reported');
      expect(inSheet(find.bySemanticsLabel('Add a piece')), findsOneWidget);
      expect(inSheet(find.text('That did not work. Try again in a moment.')), findsOneWidget);
    });
  });

  testWidgets('on a phone the dock follows the controller: the last cloth gone behind a sheet, the empty box shows', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await openClothTab(tester);
    final id = (await tester.runAsync(() => c.shelf.addClothForTest(boxPieces: 10)))!;
    await letWork(tester, done: () => swatch(id).evaluate().isNotEmpty);
    expect(swatch(id), findsOneWidget);
    await tester.tap(key('phone-menu'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => c.shelf.removeCloth(id));
    await letWork(tester, done: () => find.byKey(const ValueKey('start-here'), skipOffstage: false).evaluate().isNotEmpty);
    expect(find.text('Delete box', skipOffstage: false), findsOneWidget);
    expect(swatch(id).evaluate(), isEmpty);
  });

  testWidgets('on a phone every button in the Cloth box tab is at least 44 px, its swatches among them', (tester) async {
    final c = await pumpOnSample(tester, size: phone);
    await openClothTab(tester);
    final members = c.members(c.box);
    expect(members, hasLength(10));
    for (final m in members) {
      final s = tester.getSize(swatch(c.cloth[m].id));
      expect(s.width >= 48 && s.height >= 48, isTrue, reason: '${c.cloth[m].name} is $s');
    }
    final before = checkTargets(tester, 44);
    // The same screen less its swatches: the top bar, the tabs, the picker and Add pieces.
    await tester.runAsync(() async {
      for (final m in members) {
        await c.shelf.removeCloth(c.cloth[m].id);
      }
    });
    await letWork(tester, done: () => c.members(c.box).isEmpty);
    // The emptied box's board is 35 dashed squares, each a button (decision 14), held to the same 44.
    expect(before - checkTargets(tester, 44), 10 - 35,
        reason: 'the ten swatches counted; Delete box stays; and the board\'s 35 empty squares');
  });
}
