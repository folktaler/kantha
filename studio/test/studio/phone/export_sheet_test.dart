import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/platform/fonts.dart' show fetchPublicSans, forgetPublicSans, loadPublicSans;
import 'package:kantha_studio/platform/links.dart' show helpUri;
import 'package:kantha_studio/studio/studio_screen.dart' show StudioScreen;
import 'package:kantha_studio/studio/phone/phone_sheet.dart';
import 'package:kantha_studio/studio/shelf_feed.dart' show ClothPhoto;
import 'package:kantha_studio/studio/take_menus.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';
import '../../support/targets.dart';

/* The Share sheet (redesign handover, Bottom sheets; the owner's markup of 19 Oct). */
const missing = 'That design uses cloth that is no longer in the box.';

void main() {
  testWidgets('on a phone Share saves the design first, then shows its three rows with no headings', (tester) async {
    final c = await pumpStudio(tester, size: phone, delivery: CaptureDelivery());
    expect(c.saved, isEmpty);
    await openShare(tester);
    await letWork(tester, done: () => c.saved.isNotEmpty);
    expect(c.saved, hasLength(1), reason: 'saved as it is first');
    expect(find.text('Share'), findsNWidgets(2), reason: 'the top bar\'s button and the sheet\'s title');
    expect(find.text('Export'), findsNothing);
    for (final gone in ['DIGITAL', 'PHYSICAL CRAFT', '1080 × 1350, made with kantha.app']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.text('Save photo'), findsOneWidget);
    expect(tester.widget<SheetRow>(find.widgetWithText(SheetRow, 'Save photo')).note, isNull, reason: 'no note');
    expect(find.text('Print pattern PDF'), findsOneWidget, reason: 'the owner brought the printed sheet back on 19 Oct');
    expect(find.text('A4 — print at 100%'), findsOneWidget);
    expect(find.text('Kantha stitching guide'), findsOneWidget);
    expect(find.text('How to lay out and stitch the panel'), findsOneWidget);
    expect(find.text('Share design'), findsNothing, reason: 'the owner took the row out on 19 Oct');
    expect(find.byType(SheetRow), findsNWidgets(3));
    // Each row's Tabler icon before its words.
    for (final (t, icon) in [('Save photo', tabler.PhotoDown), ('Print pattern PDF', tabler.Printer),
        ('Kantha stitching guide', tabler.Book)]) {
      final row = find.widgetWithText(SheetRow, t);
      expect(find.descendant(of: row, matching: find.byType(icon)), findsOneWidget, reason: t);
      expect(tester.getRect(find.descendant(of: row, matching: find.byType(icon))).right,
          lessThan(tester.getRect(find.text(t)).left), reason: t);
    }
    // Top to bottom: Save photo, Print pattern PDF, Kantha stitching guide.
    final ys = [for (final t in ['Save photo', 'Print pattern PDF', 'Kantha stitching guide']) tester.getTopLeft(find.text(t)).dy];
    expect(ys, [...ys]..sort());
    expect(find.text(missing), findsNothing);
  });

  testWidgets('opening Share makes the photo; Save photo hands it over inside the press', (tester) async {
    final d = CaptureDelivery();
    final c = await pumpStudio(tester, size: phone, delivery: d);
    final id = await tester.runAsync(() => c.takeAwayNow());
    final t = TakeAway(delivery: d);
    unawaited(showExportSheet(tester.element(find.byType(StudioScreen)), designId: id!, c: c, takeAway: t, openLink: (_) {}));
    await letWork(tester, done: () => t.photoMade(c, c.designFor(id)!) != null, turns: 300);
    expect(d.saved, isEmpty, reason: 'made as the sheet opens, not handed over');
    await tester.tap(find.text('Save photo'));
    await tester.pump();
    expect(d.saved, ['chess.png'], reason: 'nothing left to make: handed over with no work after the press');
  });

  testWidgets("the photo is kept by each cloth's picture (its id, its photo's number, its version and when it was "
      'added) and by the imports since the studio opened', (tester) async {
    final c = await pumpStudio(tester, size: phone, delivery: CaptureDelivery());
    final id = await tester.runAsync(() => c.takeAwayNow());
    final d = c.designFor(id!)!, t = TakeAway(delivery: CaptureDelivery());
    final before = t.versionOf(c, d);
    final pictures = (jsonDecode(before) as Map)['pictures'] as List;
    final photos = [for (final x in c.cloth) if (d.grid.contains(x.id) && x.box != null) x.image].whereType<ClothPhoto>();
    expect(photos, isNotEmpty);
    for (final p in photos) {
      expect(pictures, contains(equals([p.id, p.photo, p.version, p.added.microsecondsSinceEpoch])), reason: p.id);
    }
    c.imports++;
    expect(t.versionOf(c, d), isNot(before), reason: 'a photo made before an import is not handed out after it');
  });

  testWidgets('once the studio has opened, Print pattern PDF and Save photo still work with the network gone: '
      "Public Sans's files were fetched just after the first frame", (tester) async {
    forgetPublicSans(); // as on a page opened afresh: no Public Sans fetched or made yet
    final d = CaptureDelivery();
    await pumpStudio(tester, size: phone, delivery: d);
    // The network goes: every asset asked for from now on fails.
    final asked = <String>[];
    final assets = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    assets.setMockMessageHandler('flutter/assets', (m) async {
      asked.add(Uri.decodeFull(utf8.decode(m!.buffer.asUint8List(m.offsetInBytes, m.lengthInBytes))));
      return null;
    });
    addTearDown(() async {
      assets.setMockMessageHandler('flutter/assets', null);
      // Fetched and made on this test's fake clock, Public Sans would hold every later test that waits for it
      // (flutter_test_config.dart): fetched and made again on the real one.
      forgetPublicSans();
      await tester.runAsync(loadPublicSans);
    });
    // The fetch the app began just after its first frame, done (were it not begun, this one would fail).
    var fetched = false;
    unawaited(fetchPublicSans().then((_) => fetched = true, onError: (_) {}));
    await letWork(tester, done: () => fetched, turns: 300);
    expect(fetched, isTrue, reason: 'the app asked for the files before the network went');
    await openShare(tester);
    await tester.tap(find.text('Print pattern PDF'));
    await letWork(tester, done: () => d.pdfs.isNotEmpty, turns: 300);
    expect(d.pdfs, ['chess.pdf']);
    await openShare(tester);
    await tester.tap(find.text('Save photo'));
    await letWork(tester, done: () => d.saved.isNotEmpty, turns: 300);
    expect(d.saved, ['chess.png']);
    expect(asked.where((a) => a.contains('PublicSans')), isEmpty, reason: 'the face was made from the files held');
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone Save photo hands over one PNG and the sheet closes', (tester) async {
    final d = CaptureDelivery();
    await pumpStudio(tester, size: phone, delivery: d);
    await openShare(tester);
    await tester.tap(find.text('Save photo'));
    await letWork(tester, done: () => d.saved.isNotEmpty, turns: 300);
    expect(d.saved, ['chess.png']);
    expect(find.text('Save photo'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('on a phone Print pattern PDF hands over one PDF', (tester) async {
    final d = CaptureDelivery();
    await pumpStudio(tester, size: phone, delivery: d);
    await openShare(tester);
    await tester.tap(find.text('Print pattern PDF'));
    await letWork(tester, done: () => d.pdfs.isNotEmpty, turns: 300);
    expect(d.pdfs, ['chess.pdf']);
    expect(find.text('Print pattern PDF'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('on a phone a PDF that cannot be made leaves the row saying so, to try again', (tester) async {
    final d = CaptureDelivery()..fail = true;
    await pumpStudio(tester, size: phone, delivery: d);
    await openShare(tester);
    await tester.tap(find.text('Print pattern PDF'));
    const failed = 'The file could not be made. Try again in a minute.';
    await letWork(tester, done: () => find.text(failed).evaluate().isNotEmpty, turns: 300);
    expect(tester.takeException(), isA<StateError>(), reason: 'reported, not thrown');
    expect(find.text('Kantha stitching guide'), findsOneWidget, reason: 'the sheet is still open');
    d.fail = false;
    await tester.tap(find.text(failed));
    await letWork(tester, done: () => d.pdfs.isNotEmpty, turns: 300);
    expect(d.pdfs, ['chess.pdf']);
    expect(find.text(failed), findsNothing, reason: 'made, the sheet closes');
  });

  testWidgets('on a phone a photo that cannot be saved leaves the row saying so, to try again', (tester) async {
    final d = CaptureDelivery()..fail = true;
    await pumpStudio(tester, size: phone, delivery: d);
    await openShare(tester);
    await tester.tap(find.text('Save photo'));
    // The photo was made; its handing over failed, so the row does not say it could not be prepared.
    const failed = 'The file could not be made. Try again in a minute.';
    await letWork(tester, done: () => find.text(failed).evaluate().isNotEmpty, turns: 300);
    expect(tester.takeException(), isA<StateError>(), reason: 'reported, not thrown');
    expect(find.text('Kantha stitching guide'), findsOneWidget, reason: 'the sheet is still open');
    d.fail = false;
    await tester.tap(find.text(failed));
    await letWork(tester, done: () => d.saved.isNotEmpty, turns: 300);
    expect(d.saved, ['chess.png']);
    expect(find.text(failed), findsNothing, reason: 'saved, the sheet closes');
  });

  testWidgets('on a phone Kantha stitching guide opens the guide and closes the sheet', (tester) async {
    final links = <Uri>[];
    await pumpStudio(tester, size: phone, delivery: CaptureDelivery(), openLink: links.add);
    await openShare(tester);
    await tester.tap(find.text('Kantha stitching guide'));
    await tester.pumpAndSettle();
    expect(links, [helpUri('lay')]);
    expect(find.text('Kantha stitching guide'), findsNothing);
  });

  testWidgets('on a phone a design using cloth that has gone says so first, in red', (tester) async {
    final d = CaptureDelivery();
    final c = await pumpStudio(tester, size: phone, delivery: d);
    final id = await tester.runAsync(() => c.shelf.addClothForTest(boxPieces: 40));
    await tester.pumpAndSettle();
    c.openBox(2);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    await tester.runAsync(() => c.save());
    // Box 2 keeps another cloth: a box emptied outright is the empty sheet (2026-10-07 sample-box spec, decision 13).
    await tester.runAsync(() => c.shelf.addPiecesForTest(2, 3));
    await tester.runAsync(() => c.shelf.removeClothLeavingDesigns(id!));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    await openShare(tester);
    expect(find.text(missing), findsOneWidget);
    expect(tester.widget<Text>(find.text(missing)).style?.color, const Color(0xFFDA0810));
    expect(tester.getTopLeft(find.text(missing)).dy, lessThan(tester.getTopLeft(find.text('Save photo')).dy));
    await tester.tap(find.text('Save photo'));
    await letWork(tester, done: () => d.saved.isNotEmpty, turns: 300);
    expect(d.saved, ['chess.png'], reason: 'it still saves');
  });

  testWidgets('on a phone every Share row is at least 56 tall and every button at least 44', (tester) async {
    await pumpStudio(tester, size: phone, delivery: CaptureDelivery());
    await openShare(tester);
    final rows = find.byType(SheetRow).evaluate().toList();
    expect(rows, hasLength(3));
    for (final r in rows) {
      expect(tester.getSize(find.byWidget(r.widget)).height, greaterThanOrEqualTo(56), reason: (r.widget as SheetRow).name);
    }
    checkTargets(tester, 44);
  });

  // What TakeAway makes and hands over, as the desk's Share and DIY menus proved it before they went (2026-10-11
  // one-screen spec): run from the sheet, at a desk.
  testWidgets('the files handed over are a one-page PDF and a 1080 × 1350 PNG', (tester) async {
    final d = CaptureDelivery();
    await pumpStudio(tester, delivery: d);
    await openShare(tester);
    await tester.tap(find.text('Print pattern PDF'));
    await letWork(tester, done: () => d.pdfs.isNotEmpty, turns: 300);
    final pdf = latin1.decode(d.bytes['chess.pdf']!);
    expect(pdf.startsWith('%PDF-'), isTrue);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(pdf).length, 1);
    await openShare(tester);
    await tester.tap(find.text('Save photo'));
    await letWork(tester, done: () => d.saved.isNotEmpty, turns: 300);
    final png = img.decodePng(d.bytes['chess.png']!)!;
    expect((png.width, png.height), (1080, 1350));
  });

  testWidgets('Save photo is busy while it works, and a second tap makes no second download', (tester) async {
    final d = CaptureDelivery()..gate = Completer<void>();
    await pumpStudio(tester, delivery: d);
    await openShare(tester);
    await tester.tap(find.text('Save photo'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(idle(tester), isFalse, reason: 'busy');
    expect(tester.widget<SheetRow>(find.widgetWithText(SheetRow, 'Save photo')).onPressed, isNull);
    await tester.tap(find.text('Save photo'), warnIfMissed: false);
    d.gate!.complete();
    await letWork(tester, done: () => d.saved.isNotEmpty, turns: 300);
    await letWork(tester, turns: 5);
    expect(d.saved, ['chess.png']);
    expect(find.text('Save photo'), findsNothing, reason: 'saved, the sheet closes');
  });

  testWidgets('Save photo right after a rename makes the file under the new name, not the watch’s old one', (tester) async {
    final d = CaptureDelivery();
    final c = await pumpStudio(tester, delivery: d);
    await tester.runAsync(() => c.save());
    c.setName('Zinnia');
    final id = await tester.runAsync(() => c.takeAwayNow());
    expect(c.designFor(id!)!.name, 'Zinnia');
    await openShare(tester);
    await tester.tap(find.text('Save photo'));
    await letWork(tester, done: () => d.saved.isNotEmpty, turns: 300);
    expect(d.saved, ['zinnia.png']);
  });
}
