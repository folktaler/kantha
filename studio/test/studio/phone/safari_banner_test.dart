import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/browser.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/pump.dart';

/* On an iPhone in Safari the studio says, under its top bar, that Safari clears the browser's data after 7 days away,
   until she dismisses it (owner, 11 Oct). */
final banner = key('safari-banner'), close = key('safari-banner-close'), topbar = key('phone-topbar');
const line = "Safari clears this browser's data after 7 days away. Add Kantha to your Home Screen to keep your work.";
const seenKey = 'safariBannerSeen';

const iphoneSafari = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Version/18.5 Mobile/15E148 Safari/604.1';
const iphoneChrome = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'CriOS/138.0.7204.156 Mobile/15E148 Safari/604.1';
const ipadSafari = 'Mozilla/5.0 (iPad; CPU OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) '
    'Version/18.5 Mobile/15E148 Safari/604.1';

void main() {
  testWidgets('on an iPhone in Safari the line sits directly under the top bar, full width, with a 48 × 48 Close', (tester) async {
    await pumpStudio(tester, size: phone, safariOnIphone: true);
    await letWork(tester, done: () => banner.evaluate().isNotEmpty);
    expect(find.descendant(of: banner, matching: find.text(line)), findsOneWidget);
    final b = tester.getRect(banner), bar = tester.getRect(topbar);
    expect(b.top, closeTo(bar.bottom, 0.5));
    expect((b.left, b.width), (0.0, phone.width));
    expect(tester.getRect(key('phone-canvas')).top, closeTo(b.bottom, 0.5));
    expect(tester.getSize(close), const Size(48, 48));
    expect(find.descendant(of: close, matching: find.byType(tabler.X)), findsOneWidget);
    expect(find.descendant(of: banner, matching: find.bySemanticsLabel('Close')), findsOneWidget);
    expect(find.bySemanticsLabel(line), findsOneWidget);
    final style = tester.widget<Text>(find.text(line)).style!;
    expect((style.fontSize, style.height), (14.83, 1.417), reason: 'the metadata role');
    expect(tester.widget<Container>(banner).color, PhonePalette.tint);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Close takes it away and remembers it for this browser: the next visit has none', (tester) async {
    final c = await pumpStudio(tester, size: phone, safariOnIphone: true);
    await letWork(tester, done: () => banner.evaluate().isNotEmpty);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    await letWork(tester, turns: 10);
    expect(await tester.runAsync(() => c.shelf.setting(seenKey)), isNotNull);

    await pumpStudio(tester, size: phone, sameDatabase: true, safariOnIphone: true);
    await letWork(tester, turns: 20);
    expect(banner, findsNothing);
  });

  testWidgets('anywhere but Safari on an iPhone there is no banner', (tester) async {
    await pumpStudio(tester, size: phone);
    await letWork(tester, turns: 20);
    expect(banner, findsNothing);
  });

  // One screen at every width (2026-10-11 one-screen spec, decision 2): the banner is the column's, at any size.
  testWidgets('on a tablet-sized window in Safari on an iPhone the banner is there too, across the column', (tester) async {
    await pumpStudio(tester, size: tablet, safariOnIphone: true);
    await letWork(tester, done: () => banner.evaluate().isNotEmpty);
    expect(banner, findsOneWidget);
    expect(tester.getRect(banner).width, 600);
  });

  testWidgets('with the banner up the board still fits at 100 %', (tester) async {
    final c = await pumpStudio(tester, size: phone, safariOnIphone: true);
    await letWork(tester, done: () => banner.evaluate().isNotEmpty);
    expect(c.percent, 100);
    final board = tester.getRect(key('phone-board'));
    expect(board.top, greaterThanOrEqualTo(tester.getRect(banner).bottom));
    expect(tester.takeException(), isNull);
  });

  group('isSafariOnIphone', () {
    test('Safari on an iPhone, not on the Home Screen', () => expect(isSafariOnIphone(iphoneSafari, false), isTrue));
    test('Chrome on an iPhone', () => expect(isSafariOnIphone(iphoneChrome, false), isFalse));
    test('Safari on an iPad', () => expect(isSafariOnIphone(ipadSafari, false), isFalse));
    test('Kantha added to the Home Screen', () => expect(isSafariOnIphone(iphoneSafari, true), isFalse));
  });
}
