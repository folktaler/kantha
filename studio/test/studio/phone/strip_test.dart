import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/phone/strip.dart';
import '../../support/pump.dart';

/* The dock's two sideways strips with a mouse (2026-10-11 one-screen spec, decision 5): the pattern strip and the
   swatch row scroll by a mouse drag, and a mouse's wheel turned over one moves it along, not what is behind it. */

ScrollPosition positionOf(WidgetTester tester, Finder strip) =>
    tester.state<ScrollableState>(find.descendant(of: strip, matching: find.byType(Scrollable)).first).position;

/* The mouse's wheel turned once over `f`, by `dy`. */
Future<void> wheel(WidgetTester tester, Finder f, double dy) async {
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  mouse.hover(tester.getCenter(f));
  await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, String k) async {
  await tester.tap(key(k));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a desk the wheel turned 120 over the pattern strip moves it 120 along', (tester) async {
    await pumpStudio(tester, size: desk);
    final strip = key('dock-patterns');
    expect(find.ancestor(of: strip, matching: find.byType(Strip)), findsOneWidget);
    expect(positionOf(tester, strip).pixels, 0);
    await wheel(tester, strip, 120);
    expect(positionOf(tester, strip).pixels, 120);
    await wheel(tester, strip, -50);
    expect(positionOf(tester, strip).pixels, 70);
  });

  testWidgets('on a desk a mouse drags the swatch row along', (tester) async {
    await pumpStudio(tester, size: desk);
    await tab(tester, 'tab-cloth');
    final row = key('dock-swatches');
    expect(find.ancestor(of: row, matching: find.byType(Strip)), findsOneWidget);
    expect(positionOf(tester, row).pixels, 0);
    await tester.drag(row, const Offset(-200, 0), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(positionOf(tester, row).pixels, greaterThan(150));
    expect(find.byType(BottomSheet), findsNothing, reason: 'a drag is not a press on the swatch under it');
  });

  testWidgets('the wheel over a strip moves the strip and not the list behind it; at the strip\'s end the list has it',
      (tester) async {
    final list = ScrollController();
    addTearDown(list.dispose);
    await tester.pumpWidget(MaterialApp(home: ListView(controller: list, children: [
      const SizedBox(height: 100, child: Strip(scrollKey: ValueKey('strip'), child: SizedBox(width: 1200, height: 100))),
      const SizedBox(height: 2000),
    ])));
    final strip = key('strip'), at = positionOf(tester, strip);
    await wheel(tester, strip, 300);
    expect((at.pixels, list.offset), (300.0, 0.0));
    // 1200 wide in an 800 window: 400 is the end, and the rest of a turn past it is not the list's.
    await wheel(tester, strip, 300);
    expect((at.pixels, list.offset), (400.0, 0.0));
    await wheel(tester, strip, 300);
    expect((at.pixels, list.offset), (400.0, 300.0));
  });
}
