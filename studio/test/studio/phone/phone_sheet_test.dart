import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/studio/phone/phone_sheet.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/fonts.dart';
import '../../support/pump.dart';
import '../../support/targets.dart';

/* A phone with one thing on it that opens a sheet: a plain tap area, not a button, so every button
   on the screen is the sheet's own. */
Future<void> pumpSheet(WidgetTester tester, {String? intro, required WidgetBuilder body}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(loadFonts);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: Builder(builder: (context) => Scaffold(
      body: GestureDetector(
        onTap: () => showPhoneSheet<void>(context, title: 'Your boxes', intro: intro, builder: body),
        child: const SizedBox.expand(child: Center(child: Text('open'))),
      ),
    )),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Widget rows(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetRow(name: 'Box 1', note: '12 pieces', end: RowEnd.check, selected: true, onPressed: () {}),
      SheetRow(name: 'Box 2', note: '40 pieces', onPressed: () {}),
      SheetRow(name: 'Add a box', end: RowEnd.action, action: 'Open', onPressed: () {}),
      Row(children: [
        Expanded(child: PhoneButton(text: 'Cancel', kind: PhoneButtonKind.dark, onPressed: () {})),
        Expanded(child: PhoneButton(text: 'Delete', kind: PhoneButtonKind.red, onPressed: () {})),
      ]),
    ]);

Widget many(BuildContext context) => Column(children: [
      for (var i = 0; i < 40; i++) SheetRow(name: 'Row $i', onPressed: () {}),
    ]);

void main() {
  final sheet = find.ancestor(of: find.text('Your boxes'), matching: find.byType(Material)).first;

  testWidgets('the sheet shows its title, its intro and a close button named Close', (tester) async {
    await pumpSheet(tester, intro: 'Where your cloth is kept.', body: rows);
    expect(find.text('Your boxes'), findsOneWidget);
    expect(find.text('Where your cloth is kept.'), findsOneWidget);
    expect(find.byType(tabler.X), findsOneWidget);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(tester.getSize(find.ancestor(of: find.byType(tabler.X), matching: find.byType(SizedBox)).first),
        const Size(48, 48));
  });

  testWidgets('the sheet is paper with 2 px top corners', (tester) async {
    await pumpSheet(tester, body: rows);
    final m = tester.widget<Material>(sheet);
    expect(m.color, PhonePalette.white);
    expect(m.shape == const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(2))), isTrue,
        reason: '${m.shape}');
  });

  testWidgets('a long sheet stops at 76 % of the screen and scrolls', (tester) async {
    await pumpSheet(tester, body: many);
    expect(tester.getSize(sheet).height, lessThanOrEqualTo(0.76 * 844 + 0.5));
    expect(tester.getRect(sheet).bottom, 844);
    expect(tester.getRect(find.text('Row 39')).top, greaterThan(844));
    await tester.drag(find.text('Row 5'), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Row 39')).bottom, lessThan(844));
    expect(tester.getRect(find.text('Your boxes')).top, greaterThanOrEqualTo(tester.getRect(sheet).top),
        reason: 'the header stays as the rows scroll');
  });

  testWidgets('the close button closes it', (tester) async {
    await pumpSheet(tester, body: rows);
    await tester.tap(find.byType(tabler.X));
    await tester.pumpAndSettle();
    expect(find.text('Your boxes'), findsNothing);
  });

  testWidgets('a tap on the scrim closes it', (tester) async {
    await pumpSheet(tester, body: rows);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.text('Your boxes'), findsNothing);
  });

  testWidgets('a row ends in a blue action, a check or a chevron', (tester) async {
    await pumpSheet(tester, body: rows);
    expect(tester.widget<Text>(find.text('Open')).style!.color, PhonePalette.blue);
    expect(find.byType(tabler.Check), findsOneWidget);
    expect(find.byType(tabler.ChevronRight), findsOneWidget);
  });

  testWidgets('a selected row is tinted; the others are not', (tester) async {
    await pumpSheet(tester, body: rows);
    Finder tint(String name) => find.descendant(of: find.widgetWithText(SheetRow, name),
        matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == PhonePalette.tint));
    expect(tint('Box 1'), findsOneWidget);
    expect(tint('Box 2'), findsNothing);
  });

  testWidgets('a row is one button, named by its name and note, and says whether it is chosen', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSheet(tester, body: rows);
    expect(tester.getSemantics(find.bySemanticsLabel('Box 1\n12 pieces')),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true));
    expect(find.bySemanticsLabel('Box 1'), findsNothing, reason: 'its words are not read a second time');
    semantics.dispose();
  });

  testWidgets('rows are at least 56 tall, and every button at least 44', (tester) async {
    await pumpSheet(tester, body: rows);
    for (final r in find.byType(SheetRow).evaluate()) {
      expect(tester.getSize(find.byWidget(r.widget)).height, greaterThanOrEqualTo(56));
    }
    for (final b in find.byType(PhoneButton).evaluate()) {
      expect(tester.getSize(find.byWidget(b.widget)).height, 48);
    }
    expect(checkTargets(tester, 44), 6);
  });

  /* A text button whose words sit on a 16 px line is set out phoneTextInset before it by its caller (Delete box, Add a
     piece's quiet buttons): its ground and ring clear its words by 12 px on each side, and it is drawn, laid out and
     tapped from that edge, in either reading direction. */
  for (final dir in TextDirection.values) {
    testWidgets('a text button set out before its line keeps its words on it and takes a tap 2 px inside its drawn '
        'start edge ($dir)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: dir, child: Scaffold(body: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16 - phoneTextInset, end: 16),
        child: Align(alignment: AlignmentDirectional.centerStart,
            child: PhoneButton(text: 'Delete box', kind: PhoneButtonKind.redText, onPressed: () => taps++)),
      )))));
      final button = find.byType(PhoneButton);
      final drawn = tester.getRect(find.descendant(of: button, matching: find.byType(Container)));
      final words = tester.getRect(find.text('Delete box'));
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(drawn, tester.getRect(button), reason: 'what it draws is what it lays out');
      final rtl = dir == TextDirection.rtl, start = rtl ? drawn.right : drawn.left;
      expect(rtl ? words.right : words.left, rtl ? width - 16 : 16, reason: 'its words on the 16 px line');
      expect(start, rtl ? width - 16 + phoneTextInset : 16 - phoneTextInset, reason: 'its ground and ring 12 px before them');
      expect(rtl ? drawn.left - words.left : words.right - drawn.right, -phoneTextInset, reason: 'and 12 px after them');
      await tester.tapAt(Offset(start + (rtl ? -2 : 2), drawn.center.dy));
      expect(taps, 1);
      await tester.tapAt(Offset(start + (rtl ? 2 : -2), drawn.center.dy));
      expect(taps, 1, reason: 'nothing outside it');
    });
  }
}
