import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'package:kantha_studio/studio/phone/phone_toast.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/db.dart';
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';
import '../../support/targets.dart';

/* `words` in the studio's toast. */
Finder toast(String words) => find.descendant(of: find.byKey(const ValueKey('phone-toast')), matching: find.text(words));

final panel = find.byKey(const ValueKey('menu-panel')), menu = find.byKey(const ValueKey('phone-menu'));

/* The ground the top bar is drawn on. */
Color? topBarGround(WidgetTester tester) => (tester.widget<AnimatedContainer>(
    find.ancestor(of: find.byKey(const ValueKey('phone-topbar')), matching: find.byType(AnimatedContainer)).first)
    .decoration as BoxDecoration?)?.color;

/* The Menu, then its Back up or move sheet (redesign handover, Bottom sheets; decision 13). */
Future<void> openBackupSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('phone-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Back up or move to another device'));
  await tester.pumpAndSettle();
}

void main() {

  // The Menu behaves as remarkable.com's below 1024 px (measured 19 Oct 2026, menu_panel.dart).
  for (final (what, size) in [('phone', phone), ('desk', desk)]) {
    testWidgets('on a $what ≡ opens the Menu over everything under the top bar, on paper 3, and turns into ×', (tester) async {
      await pumpStudio(tester, size: size);
      expect(panel, findsNothing);
      expect(tester.widget<Pressable>(menu).expanded, isFalse);
      expect(topBarGround(tester), PhonePalette.white);
      await tester.tap(menu);
      await tester.pump();
      expect(panel, findsOneWidget, reason: 'at once, with no sheet');
      expect(find.byType(BottomSheet), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.widget<Pressable>(menu).expanded, isTrue, reason: '× now: the menu is open');
      expect(topBarGround(tester), PhonePalette.canvas, reason: 'the top bar turns paper 3 with the menu');
      final bar = tester.getRect(find.byKey(const ValueKey('phone-topbar'))), p = tester.getRect(panel);
      final column = tester.getRect(find.byKey(const ValueKey('phone-canvas')));
      expect(p.top, bar.bottom, reason: 'straight under the top bar');
      expect((p.left, p.width), (column.left, column.width), reason: 'the column\'s whole width');
      expect(p.bottom, size.height, reason: 'down to the foot, over the dock');
      // Rows: each its Tabler icon 16 px in, its words after it, left-aligned, no chevrons; Shop carries ↗ as it leaves
      // for another site.
      for (final (w, icon) in [('Help', tabler.HelpCircle), ('Privacy policy', tabler.ShieldLock),
          ('Shop', tabler.BuildingStore), ('Back up or move to another device', tabler.DatabaseExport)]) {
        final i = tester.getRect(inMenu(find.byType(icon))), t = tester.getRect(inMenu(find.text(w)));
        expect(i.left, closeTo(p.left + 16, 0.5), reason: w);
        expect(t.left, greaterThan(i.right), reason: w);
        expect(i.center.dy, closeTo(t.top + 15.81 * 1.417 / 2, 1), reason: '$w: the icon on the name\'s first line');
      }
      expect(inMenu(find.byType(tabler.ArrowUpRight)), findsOneWidget, reason: 'only Shop leaves');
      expect(tester.getCenter(inMenu(find.byType(tabler.ArrowUpRight))).dy,
          closeTo(tester.getCenter(inMenu(find.text('Shop'))).dy, 1));
      checkTargets(tester, 44);
    });
  }

  testWidgets('on a phone × shuts the Menu, focus stays on ≡, and the top bar is paper 1 again', (tester) async {
    await pumpStudio(tester, size: phone);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pump();
    expect(panel, findsNothing, reason: 'shut at once');
    await tester.pumpAndSettle();
    expect(tester.widget<Pressable>(menu).expanded, isFalse);
    expect(topBarGround(tester), PhonePalette.white);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>()?.key, const ValueKey('phone-menu'));
  });

  testWidgets('on a desk Escape shuts the Menu and puts focus back on ≡', (tester) async {
    await pumpStudio(tester, size: desk);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>()?.key, const ValueKey('phone-menu'));
  });

  testWidgets('on a desk Tab goes round the top bar and the Menu\'s rows only, while it is open', (tester) async {
    final c = await pumpStudio(tester, size: desk);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    // From ≡, which the tap focused: the four rows and the two "I am a…" choices straight after it, then the title, Save,
    // Share, then ≡ again. Save
    // and Share name themselves by their words, so they have no label here.
    final names = <String>[];
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final p = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>();
      final n = p?.label ?? '(its words)';
      names.add(n);
      if (n == 'Close') break;
    }
    expect(names, ['Help', 'Privacy policy', 'Shop\ncatsofkochi shop',
        'Back up or move to another device\nYour work is kept on this device only', 'Beginner (5 × 7)', 'Advanced (any size)',
        c.name, '(its words)', '(its words)', 'Close']);
  });

  testWidgets('≡ is named Menu while the menu is shut and Close while it is open, to a mouse and a screen reader',
      (tester) async {
    await pumpStudio(tester, size: desk);
    final button = tester.widget<Pressable>(menu);
    expect((button.label, button.tooltip), ('Menu', 'Menu'));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final open = tester.widget<Pressable>(menu);
    expect((open.label, open.tooltip, open.expanded), ('Close', 'Close', true));
  });

  testWidgets('on a desk Enter on Save while the menu is open shuts it and leaves focus on Save', (tester) async {
    final c = await pumpStudio(tester, size: desk);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    // ≡, the four rows, the two "I am a…" choices, the title, then Save.
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    Key? focused() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<KeyedSubtree>()?.key;
    expect(focused(), const ValueKey('phone-save'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Saving writes to the database, off the fake clock.
    await letWork(tester, done: () => c.saved.isNotEmpty);
    expect(panel, findsNothing);
    expect(focused(), const ValueKey('phone-save'), reason: 'focus stays where she pressed');
  });

  testWidgets('Escape shuts the open menu wherever focus is', (tester) async {
    await pumpStudio(tester, size: desk);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>(), isNull,
        reason: 'focus is on nothing in the studio');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Pressable>()?.key, const ValueKey('phone-menu'));
  });

  testWidgets('while the menu is open a tap on it below its rows reaches nothing under it', (tester) async {
    await pumpStudio(tester, size: phone);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.ancestor(of: find.byKey(const ValueKey('dock-panel')), matching: find.byType(IgnorePointer)).evaluate()
        .any((e) => (e.widget as IgnorePointer).ignoring), isTrue, reason: 'the studio under it ignores taps');
    // Over the dock's tabs: Cloth box would open there if the tap went through.
    await tester.tapAt(Offset(phone.width / 6, phone.height - 24));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget, reason: 'the menu is still open');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-cloth')), findsNothing, reason: 'the tab under the menu was not pressed');
  });

  testWidgets('with the menu shut, Escape is left for others to handle', (tester) async {
    await pumpStudio(tester, size: desk);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isFalse, reason: 'not consumed');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isTrue, reason: 'it shuts the open menu');
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('a toast said while the menu is open is under the menu, out of the screen reader\'s way', (tester) async {
    final c = await pumpStudio(tester, size: phone);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    c.note = 'A note while the menu is open';
    c.notifyListeners();
    await tester.pump();
    final words = find.text('A note while the menu is open');
    expect(words, findsOneWidget, reason: 'said, under the menu');
    expect(find.descendant(of: find.byType(ExcludeSemantics), matching: find.byKey(const ValueKey('phone-toast'))).evaluate()
        .any((e) => (e.findAncestorWidgetOfExactType<ExcludeSemantics>()?.excluding ?? false)), isTrue);
    expect(find.bySemanticsLabel('A note while the menu is open'), findsNothing);
    // The menu is drawn after the studio, so it is on top: a tap there lands on the menu, not the toast.
    expect(tester.hitTestOnBinding(tester.getCenter(words)).path.any((h) => h.target is RenderBox &&
        find.descendant(of: panel, matching: find.byWidgetPredicate((_) => true)).evaluate()
            .any((e) => e.renderObject == h.target)), isTrue);
    await tester.pump(Toaster.showFor);
  });

  testWidgets('on a phone Back shuts the Menu and leaves the studio where it was', (tester) async {
    await pumpStudio(tester, size: phone);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(find.byKey(const ValueKey('phone-topbar')), findsOneWidget);
  });

  testWidgets('on a phone the title, Save or Share shut the Menu before they act', (tester) async {
    await pumpStudio(tester, size: phone);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('phone-title')));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget, reason: 'My designs');
  });

  testWidgets('where she asked for less motion the Menu is there in the first frame, at full strength', (tester) async {
    await pumpStudio(tester, size: phone);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    await tester.tap(menu);
    await tester.pump();
    final fade = tester.widget<FadeTransition>(find.descendant(of: panel, matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1);
    expect(topBarGround(tester), PhonePalette.canvas);
  });

  testWidgets('on a phone the Menu\'s Back up row opens the Back up sheet: its intro, then Save and Open a backup file', (tester) async {
    await pumpStudio(tester, size: phone, files: FixtureFiles(null));
    await openBackupSheet(tester);
    expect(find.text('Back up or move to another device'), findsOneWidget, reason: 'the sheet\'s title');
    expect(find.textContaining('Save everything you have made'), findsOneWidget);
    expect(find.text('Save a backup file'), findsOneWidget);
    expect(find.text('Open a backup file'), findsOneWidget);
    expect(find.text('Replaces everything on this device'), findsOneWidget);
    checkTargets(tester, 44);
  });

  testWidgets('on a phone Save a backup file hands over one file named for today, and toasts it', (tester) async {
    final d = CaptureDelivery();
    await pumpStudio(tester, size: phone, delivery: d, files: FixtureFiles(null));
    await openBackupSheet(tester);
    await tester.tap(find.text('Save a backup file'));
    await letWork(tester, done: () => d.backups.isNotEmpty);
    expect(d.backups.keys, [today]);
    expect(d.origin, isNotNull, reason: "an iPad's share sheet points at the row");
    expect(find.descendant(of: find.byKey(const ValueKey('phone-toast')), matching: find.text('Saved $today.')), findsOneWidget);
    expect(find.text('Save a backup file'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('on a phone Open a backup file asks first', (tester) async {
    final files = FixtureFiles.withBackupOf(await tester.runAsync(emptyDeviceBackup));
    await pumpStudio(tester, size: phone, files: files);
    await openBackupSheet(tester);
    await tester.tap(find.text('Open a backup file'));
    await tester.pumpAndSettle();
    expect(files.picked, 1);
    expect(find.textContaining('overwrites all designs and boxes currently on this device'), findsOneWidget);
    expect(find.text('Save a backup of this device first'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('overwrites all designs and boxes currently on this device'), findsNothing);
  });

  // The Back up screen's flows, which went with it (2026-10-11 one-screen spec, decision 6), run from the sheet.
  testWidgets('Replace with the file: this device holds what the file held, the toast says so, and the studio opens on its box',
      (tester) async {
    final files = FixtureFiles.withBackupOf(await tester.runAsync(oneBoxBackup));
    final c = await pumpStudio(tester, files: files, seeded: false);
    await tester.runAsync(() async {
      await c.shelf.addClothForTest(boxPieces: 2);
      final photo = img.encodeJpg(img.Image(width: 64, height: 64)..clear(img.ColorRgb8(20, 90, 60)), quality: 90);
      await c.shelf.addCloth(box: 1, photo: photo, measured: measureBytes(photo), fabric: 'Cotton', pieces: 3);
    });
    await letWork(tester);
    expect(c.cloth.where((x) => x.box == 1).map((x) => x.id), ['C-1', 'C-2'], reason: "this device's own cloth, before");

    await openBackupSheet(tester);
    await tester.tap(find.text('Open a backup file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace with the file'));
    await letWork(tester, done: () => find.textContaining('now holds').evaluate().isNotEmpty);
    expect(toast('This device now holds what was in kantha-backup-2026-10-06.kantha.'), findsOneWidget);
    await letWork(tester, done: () => c.grid != null);

    expect(c.ownBoxes, [1]);
    expect(c.box, 1, reason: 'her box from the file can fill a template, so the studio opens on it');
    final hers = c.cloth.where((x) => x.box != null).toList();
    expect(hers.map((x) => (x.id, x.fabric, x.stock)), [('C-1', 'Linen', 40)],
        reason: "the device's own C-1 and C-2 are not kept beside the file's as gone");
    expect(c.cloth.where((x) => x.box == null), isEmpty);
    expect(c.grid, isNotNull);
    expect(c.solving, isFalse);
    await tester.pump(Toaster.showFor);
  });

  testWidgets('Save a backup of this device first: the file is handed over, then she is asked again', (tester) async {
    final d = CaptureDelivery();
    final files = FixtureFiles.withBackupOf(await tester.runAsync(emptyDeviceBackup));
    await pumpStudio(tester, delivery: d, files: files);
    await openBackupSheet(tester);
    await tester.tap(find.text('Open a backup file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a backup of this device first'));
    await letWork(tester, done: () => d.backups.isNotEmpty && find.text('Replace with the file').evaluate().isNotEmpty);
    expect(d.backups.keys, [today]);
    expect(find.textContaining('overwrites all designs and boxes currently on this device'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('overwrites all designs and boxes currently on this device'), findsNothing);
    expect(toast('Saved $today.'), findsOneWidget);
    await tester.pump(Toaster.showFor);
  });

  testWidgets('Save first, and she dismisses the share sheet: no "Saved", and the same question again', (tester) async {
    final d = CaptureDelivery(kept: false);
    final files = FixtureFiles.withBackupOf(await tester.runAsync(emptyDeviceBackup));
    await pumpStudio(tester, delivery: d, files: files);
    await openBackupSheet(tester);
    await tester.tap(find.text('Open a backup file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a backup of this device first'));
    await letWork(tester, done: () => d.backups.isNotEmpty && find.text('Replace with the file').evaluate().isNotEmpty);
    expect(find.textContaining('Saved'), findsNothing);
    expect(find.text('Save a backup of this device first'), findsOneWidget, reason: 'all three answers, as before');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved'), findsNothing);

    await openBackupSheet(tester);
    await tester.tap(find.text('Save a backup file'));
    await letWork(tester, done: () => d.handed == 2);
    expect(find.textContaining('Saved'), findsNothing, reason: 'the row on its own does not claim it either');
  });

  testWidgets('a file that is not a backup is refused in plain words, and nothing changes', (tester) async {
    final files = FixtureFiles.withBackupOf(Uint8List.fromList(utf8.encode('hello')), name: 'notes.txt');
    final c = await pumpStudio(tester, files: files, seeded: false);
    await tester.runAsync(() => c.shelf.makeBox());
    await letWork(tester);
    await openBackupSheet(tester);
    await tester.tap(find.text('Open a backup file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Opening notes.txt overwrites all designs and boxes'), findsOneWidget);
    await tester.tap(find.text('Replace with the file'));
    await letWork(tester, done: () => find.textContaining('not a Kantha backup').evaluate().isNotEmpty);
    expect(toast('That file is not a Kantha backup. Nothing was changed.'), findsOneWidget);
    expect(c.ownBoxes, [1]);
    await tester.pump(Toaster.showFor);
  });

  testWidgets('cancelling the file picker asks nothing', (tester) async {
    final files = FixtureFiles(null);
    await pumpStudio(tester, files: files);
    await openBackupSheet(tester);
    await tester.tap(find.text('Open a backup file'));
    await tester.pumpAndSettle();
    expect(files.picked, 1);
    expect(find.textContaining('overwrites all designs and boxes'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing, reason: 'the sheet closed as the row was pressed');
  });

  testWidgets('an import that is in stays reported as in, even if the studio then fails to re-read', (tester) async {
    final files = FixtureFiles.withBackupOf(await tester.runAsync(oneBoxBackup));
    final shelf = BrokenAfterImport(memoryDb());
    final c = await pumpStudio(tester, files: files, on: shelf);
    await openBackupSheet(tester);
    await tester.tap(find.text('Open a backup file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace with the file'));
    await letWork(tester, done: () => find.textContaining('now holds').evaluate().isNotEmpty);
    expect(tester.takeException(), isA<StateError>(), reason: 'reported');
    expect(toast('This device now holds what was in kantha-backup-2026-10-06.kantha.'), findsOneWidget);
    expect(find.textContaining('Could not save'), findsNothing);
    expect(c.memory, isEmpty);
    await tester.pump(Toaster.showFor);
  });
}
