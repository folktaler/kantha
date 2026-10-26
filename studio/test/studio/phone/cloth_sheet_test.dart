import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/cloth/fix_cloth.dart';
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/phone/phone_sheet.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/pump.dart';
import '../../support/studio_fixture.dart';

/* Add a piece and Fix this cloth as phone sheets (redesign handover, "Add a piece sheet (batch entry)" and the "Fix this
   cloth" row of Bottom sheets; decision 3: the real photo flow in the handover's layout, no colour chips). */

/* The sheet's title: its header's words. */
Finder title(String text) => inSheet(find.bySemanticsLabel(text));

Future<void> openClothTab(WidgetTester tester) async {
  await tester.tap(key('tab-cloth'));
  await tester.pumpAndSettle();
}

/* A new, empty box of hers, on the board, the Cloth box tab open. */
Future<(StudioController, int)> emptyBox(WidgetTester tester) async {
  final c = await pumpStudio(tester, size: phone, photos: FixturePhotos());
  final box = (await tester.runAsync(() => c.shelf.makeBox()))!;
  await letWork(tester, done: () => c.ownBoxes.contains(box));
  c.openBox(box);
  await tester.pumpAndSettle();
  await openClothTab(tester);
  return (c, box);
}

/* The 48 px button carrying `text`, in the sheet. */
Finder button(String text) => inSheet(find.ancestor(of: find.text(text), matching: find.byType(PhoneButton)));

/* The pieces of each cloth on the board, by its index in c.cloth. */
int usedOf(StudioController c, int index) => (c.grid ?? const <int>[]).where((f) => f == index).length;

void main() {
  testWidgets('on a phone Add pieces opens Add a piece as a sheet; a photo and Add to box add the piece, the sheet stays '
      'open and says what it added, the count starts at 1 again, the dock behind shows the swatch; Done closes it', (tester) async {
    final (c, box) = await emptyBox(tester);
    await tester.tap(key('add-pieces'));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(title('Add a piece'), findsOneWidget);
    expect(inSheet(find.text('1 piece')), findsOneWidget);
    expect(inSheet(find.text('How many of this piece')), findsOneWidget);
    expect(inSheet(find.text('Cotton or linen works best.')), findsOneWidget);
    expect(inSheet(find.text('Done')), findsOneWidget);
    expect(inSheet(find.text('Add to box')), findsOneWidget);

    // The photo field is 140 tall on the phone.
    expect(tester.getSize(inSheet(key('photo-field'))).height, 140);

    // The count row: the question in the card-label role over the recommendation in fine print, text2, at the left,
    // the counter at the right.
    final ask = tester.widget<Text>(inSheet(find.text('How many of this piece')));
    expect((ask.style!.fontSize, ask.style!.fontWeight), (15.81, FontWeight.w500));
    final tip = tester.widget<Text>(inSheet(find.text('Cotton or linen works best.')));
    expect((tip.style!.fontSize, tip.style!.color), (13.83, PhonePalette.text2));
    expect(tester.getRect(inSheet(find.text('1 piece'))).left,
        greaterThan(tester.getRect(inSheet(find.text('How many of this piece'))).right));
    final count = tester.widget<Text>(inSheet(find.text('1 piece')));
    expect((count.style!.fontSize, count.style!.fontWeight), (15.81, FontWeight.w600));
    expect(count.style!.fontFeatures, contains(const FontFeature.tabularFigures()));

    // Two equal 48 px buttons, Done dark, Add blue; the counter's buttons 48 square.
    final done = button('Done'), add = button('Add to box');
    expect(tester.widget<PhoneButton>(done).kind, PhoneButtonKind.dark);
    expect(tester.widget<PhoneButton>(add).kind, PhoneButtonKind.blue);
    expect(tester.getSize(done).height, 48);
    expect(tester.getSize(add).height, 48);
    expect(tester.getSize(done).width, closeTo(tester.getSize(add).width, 0.5));
    for (final label in ['One fewer piece', 'One more piece']) {
      final step = inSheet(find.ancestor(of: find.bySemanticsLabel(label), matching: find.byType(IconButton)));
      expect(tester.getSize(step), const Size(48, 48), reason: label);
    }

    await tester.tap(inSheet(find.text('Photo of the piece')));
    // The cropper reads the picture in an isolate, off the fake clock.
    await letWork(tester, turns: 10);
    expect(inSheet(find.text('fill the square with the piece')), findsOneWidget);
    await tapShown(tester, inSheet(find.text('Add to box')));
    await letWork(tester, done: () => c.cloth.any((x) => x.box == box));
    final added = c.cloth.singleWhere((x) => x.box == box);
    expect(added.stock, 1);
    final said = '1 piece of ${added.name} added. Photograph the next one.';
    expect(inSheet(find.text(said)), findsOneWidget, reason: 'the sheet is still open and says what it added');
    expect(title('Add a piece'), findsOneWidget);
    expect(inSheet(find.text('1 piece')), findsOneWidget, reason: 'the count starts at 1 again');
    expect(inSheet(find.text('Photo of the piece')), findsOneWidget, reason: 'ready for the next photo');

    // The banner: at the top, at least 48 tall, the note ground with a 3 px ink left edge and a 16 px ink check.
    final banner = inSheet(key('cloth-added'));
    expect(tester.getSize(banner).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(banner).top, lessThan(tester.getRect(inSheet(key('photo-field'))).top));
    final box2 = tester.widget<Container>(find.descendant(of: banner, matching: find.byType(Container)).first);
    final deco = box2.decoration! as BoxDecoration;
    expect(deco.color, PhonePalette.note);
    expect(((deco.border! as Border).left.width, (deco.border! as Border).left.color), (3.0, PhonePalette.text));
    expect(iconLook(tester, find.descendant(of: banner, matching: find.byType(tabler.Check))), (size: 16.0, color: PhonePalette.text));
    expect(tester.widget<Text>(find.text(said)).style!.fontSize, 15.81);

    // The dock behind the sheet shows the new swatch.
    expect(find.byKey(ValueKey('swatch-${added.id}'), skipOffstage: false), findsOneWidget);

    await tapShown(tester, inSheet(find.text('Done')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('on a phone with no box, Add pieces opens Add a piece as a sheet too', (tester) async {
    final c = await pumpStudio(tester, size: phone, seeded: false, photos: FixturePhotos());
    await openClothTab(tester);
    expect(c.ownBoxes, isEmpty);
    await tester.tap(key('add-pieces'));
    await tester.pumpAndSettle();
    expect(title('Add a piece'), findsOneWidget);
  });

  testWidgets('on a phone a stroke down the sheet leaves Add a piece open with its photo; a tap on the scrim adds it '
      'and closes the sheet', (tester) async {
    final (c, box) = await emptyBox(tester);
    await tester.tap(key('add-pieces'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Photo of the piece')));
    await letWork(tester, turns: 10);
    await tester.fling(title('Add a piece'), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget, reason: 'not dragged closed');
    expect(inSheet(find.text('fill the square with the piece')), findsOneWidget, reason: 'the photo is kept');
    await tester.tapAt(const Offset(20, 20));
    await letWork(tester, done: () => c.cloth.any((x) => x.box == box) && sheet.evaluate().isEmpty);
    expect(sheet, findsNothing);
    expect(c.cloth.where((x) => x.box == box), hasLength(1), reason: 'the photo went in (DECISIONS 58)');
  });

  testWidgets('on a phone a swatch opens Fix this cloth as a sheet titled with the cloth\'s name: Pieces in the box with its '
      'counter, Save changes waits for a change, + then Save changes grows the stock and closes the sheet', (tester) async {
    final c = await pumpStudio(tester, size: phone, photos: FixturePhotos());
    await openClothTab(tester);
    // A cloth with pieces left over: no All used intro.
    final f = c.members(c.box).firstWhere((m) => c.cloth[m].stock > usedOf(c, m));
    final cloth = c.cloth[f], id = cloth.id, stock = cloth.stock;
    await tester.ensureVisible(key('swatch-$id'));
    await tester.pumpAndSettle();
    await tester.tap(key('swatch-$id'));
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    expect(title(cloth.name), findsOneWidget);
    expect(inSheet(find.text('Fix this cloth')), findsNothing, reason: 'the title is the cloth\'s name');
    final pieces = tester.widget<Text>(inSheet(find.text('Pieces in the box')));
    expect((pieces.style!.fontSize, pieces.style!.fontWeight), (15.81, FontWeight.w500));
    expect(inSheet(find.text('$stock')), findsOneWidget);
    expect(inSheet(find.textContaining('pieces are currently in use')), findsNothing, reason: 'some are left');

    final save = button('Save changes'), remove = button('Remove this piece');
    expect(tester.widget<PhoneButton>(save).kind, PhoneButtonKind.blue);
    expect(tester.widget<PhoneButton>(remove).kind, PhoneButtonKind.outlinedRed);
    expect(tester.getSize(save).height, 48);
    expect(tester.getSize(remove).height, 48);
    expect(tester.widget<PhoneButton>(save).onPressed, isNull, reason: 'nothing has changed yet');
    for (final label in ['One fewer piece', 'One more piece']) {
      final step = inSheet(find.ancestor(of: find.bySemanticsLabel(label), matching: find.byType(IconButton)));
      expect(tester.getSize(step), const Size(48, 48), reason: label);
    }

    await tapShown(tester, inSheet(find.bySemanticsLabel('One more piece')));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('${stock + 1}')), findsOneWidget);
    expect(tester.widget<PhoneButton>(save).onPressed, isNotNull);
    await tapShown(tester, inSheet(find.text('Save changes')));
    await letWork(tester, done: () => c.cloth.singleWhere((x) => x.id == id).stock == stock + 1 && sheet.evaluate().isEmpty);
    expect(c.cloth.singleWhere((x) => x.id == id).stock, stock + 1);
    expect(sheet, findsNothing);
  });

  testWidgets('on a phone a cloth whose pieces are all on the board opens with All n pieces are currently in use', (tester) async {
    final c = await pumpStudio(tester, size: phone, photos: FixturePhotos());
    await openClothTab(tester);
    final f = c.members(c.box).firstWhere((m) => usedOf(c, m) > 0);
    final cloth = c.cloth[f], used = usedOf(c, f);
    await tester.runAsync(() => c.shelf.editCloth(cloth.id, fabric: cloth.fabric, pieces: used));
    await letWork(tester, done: () => c.cloth[f].stock == used);
    await tester.ensureVisible(key('swatch-${cloth.id}'));
    await tester.pumpAndSettle();
    await tester.tap(key('swatch-${cloth.id}'));
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    expect(title(cloth.name), findsOneWidget);
    expect(inSheet(find.text('All $used pieces are currently in use. Add more to give the pattern solver more options.')),
        findsOneWidget);
  });

  testWidgets('on a phone Remove this piece asks first, then takes the cloth out of the box and closes the sheet', (tester) async {
    final c = await pumpStudio(tester, size: phone, photos: FixturePhotos());
    await openClothTab(tester);
    final id = (await tester.runAsync(() => c.shelf.addClothForTest(boxPieces: 3)))!;
    await letWork(tester, done: () => key('swatch-$id').evaluate().isNotEmpty);
    await tester.ensureVisible(key('swatch-$id'));
    await tester.pumpAndSettle();
    await tester.tap(key('swatch-$id'));
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    await tapShown(tester, inSheet(find.text('Remove this piece')));
    await tester.pumpAndSettle();
    expect(find.text(c.words.clothRemoveSure), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove this piece')));
    await letWork(tester, done: () => c.cloth.firstWhere((x) => x.id == id).box == null && sheet.evaluate().isEmpty);
    expect(c.cloth.firstWhere((x) => x.id == id).box, isNull, reason: 'out of the box');
    expect(sheet, findsNothing);
  });

  testWidgets('on a phone every button in the two sheets is at least 44 px', (tester) async {
    final (c, box) = await emptyBox(tester);
    await tester.tap(key('add-pieces'));
    await tester.pumpAndSettle();
    Future<void> check(String what) async {
      expect(sheet, findsOneWidget, reason: what);
      final buttons = find.byWidgetPredicate((w) => w is Pressable || w is ButtonStyleButton || w is IconButton);
      for (final e in inSheet(buttons).evaluate()) {
        final words = find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate();
        final name = words.isEmpty ? '${e.widget}' : (words.first.widget as Text).data;
        final s = tester.getSize(find.byWidget(e.widget));
        expect(s.width >= 44 && s.height >= 44, isTrue, reason: '$what: "$name" is $s');
      }
    }
    await check('Add a piece');
    await tester.tap(inSheet(find.text('How to get it right')));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Photo of the piece')));
    await letWork(tester, turns: 10);
    await check('Add a piece, cropping');
    await tester.tap(inSheet(find.bySemanticsLabel('Close')).last); // it adds the photo first (DECISIONS 58)
    await letWork(tester, done: () => c.cloth.any((x) => x.box == box) && sheet.evaluate().isEmpty);
    expect(c.cloth.where((x) => x.box == box), hasLength(1));

    // Fix this cloth, on a cloth of Box 1.
    c.openBox(c.ownBoxes.firstWhere((b) => c.members(b).isNotEmpty));
    await letWork(tester, done: () => !c.solving);
    final id = c.cloth[c.members(c.box).first].id;
    await tester.ensureVisible(key('swatch-$id'));
    await tester.pumpAndSettle();
    await tester.tap(key('swatch-$id'));
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    await check('Fix this cloth');
  });

  // Fix round 1: a second tap while the cloth is still being read opens no second, stale sheet.
  testWidgets('on a phone two taps on a swatch open one Fix this cloth sheet', (tester) async {
    final c = await pumpStudio(tester, size: phone, photos: FixturePhotos());
    await openClothTab(tester);
    final id = c.cloth[c.members(c.box).first].id;
    await tester.ensureVisible(key('swatch-$id'));
    await tester.pumpAndSettle();
    // Two presses in the same moment, before the cloth has been read (a tap that waited a frame would land on the scrim).
    final swatch = tester.widget<Pressable>(key('swatch-$id'));
    swatch.onPressed!();
    swatch.onPressed!();
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    await letWork(tester, turns: 5);
    expect(sheet, findsOneWidget);
    expect(find.byType(FixCloth), findsOneWidget);
    // Closed, the swatch opens it again.
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    await tester.tap(key('swatch-$id'));
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    expect(find.byType(FixCloth), findsOneWidget);
  });

  // Fix round 1 (ruling on the crop and the sheet's scrolling): a finger on the crop moves the crop, not the sheet.
  testWidgets('on a phone a stroke up the crop moves the square and leaves the sheet where it is; a stroke up the count '
      'row scrolls the sheet', (tester) async {
    await emptyBox(tester);
    await tester.tap(key('add-pieces'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Photo of the piece')));
    await letWork(tester, turns: 10);
    final scroll = tester.state<ScrollableState>(inSheet(find.byType(Scrollable)).first).position;
    expect(scroll.maxScrollExtent, greaterThan(0), reason: 'the sheet scrolls with a photo in the cropper');
    final square = find.byKey(const ValueKey('crop-square'));
    final before = tester.getRect(square);
    final g = await tester.startGesture(before.center);
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, -10));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(scroll.pixels, 0, reason: 'the sheet did not scroll');
    expect(tester.getRect(square).top, lessThan(before.top), reason: 'the square moved up');

    await tester.drag(inSheet(find.text('How many of this piece')), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(inSheet(find.byType(Scrollable)).first).position.pixels, greaterThan(0),
        reason: 'the sheet scrolls again once the finger is off the crop');
  });

  // The sweep (Task 12): inside the add and fix sheets, the photo field, How to, the hints, the error and the crop's stage
  // are the sheet's own: Geist, the phone's colours, square corners. The desk's cards keep theirs (cloth/*_test.dart).
  testWidgets('on a phone the add and fix sheets\' inner parts are Geist in the phone\'s colours, with square corners', (tester) async {
    final (c, box) = await emptyBox(tester);
    await tester.tap(key('add-pieces'));
    await tester.pumpAndSettle();
    void inter(String words, double size, Color color, {FontWeight weight = FontWeight.w400}) {
      final s = tester.widget<Text>(inSheet(find.text(words))).style!;
      expect((s.fontFamily, s.fontSize, s.fontWeight, s.color), (kPhoneFont, size, weight, color), reason: words);
    }
    BoxDecoration decoration(Finder f) => tester.widget<Container>(f).decoration! as BoxDecoration;

    inter('Photo of the piece', 15.81, PhonePalette.text, weight: FontWeight.w500);
    inter('Tap to take one, or choose a picture', 13.83, PhonePalette.text2);
    final field = decoration(inSheet(key('photo-field')));
    expect((field.borderRadius, field.color, (field.border! as Border).top.color),
        (null, PhonePalette.canvas, PhonePalette.border));

    inter('How to get it right', 15.81, PhonePalette.text, weight: FontWeight.w500);
    await tester.tap(inSheet(find.text('How to get it right')));
    await tester.pumpAndSettle();
    for (final line in ['1.', 'Cut each piece 6 cm by 6 cm.', 'For best results, photograph it in daylight.']) {
      inter(line, 15.81, PhonePalette.text2);
    }

    // Add with no photo: the error, in the body-small role, in the phone's red.
    await tapShown(tester, inSheet(find.text('Add to box')));
    await tester.pumpAndSettle();
    inter('A photograph of the piece is needed.', 15.81, PhonePalette.red);

    await tapShown(tester, inSheet(find.text('Photo of the piece')));
    await letWork(tester, turns: 10);
    inter('fill the square with the piece', 13.83, PhonePalette.text2);
    final stage = decoration(inSheet(key('crop-stage')));
    expect((stage.borderRadius, stage.color, (stage.border! as Border).top.color), (null, PhonePalette.canvas, PhonePalette.border));
    await tester.tap(inSheet(find.bySemanticsLabel('Close')).last); // it adds the photo first (DECISIONS 58)
    await letWork(tester, done: () => c.cloth.any((x) => x.box == box) && sheet.evaluate().isEmpty);
    expect(c.cloth.where((x) => x.box == box), hasLength(1));

    // Fix this cloth: the crop's stage and its hint.
    c.openBox(c.ownBoxes.firstWhere((b) => c.members(b).isNotEmpty));
    await letWork(tester, done: () => !c.solving);
    final id = c.cloth[c.members(c.box).first].id;
    await tester.ensureVisible(key('swatch-$id'));
    await tester.pumpAndSettle();
    await tester.tap(key('swatch-$id'));
    await letWork(tester, done: () => sheet.evaluate().isNotEmpty, turns: 10);
    expect(decoration(inSheet(key('crop-stage'))).borderRadius, isNull);
    inter(c.words.clothFixWiden, 13.83, PhonePalette.text2);
  });
}
