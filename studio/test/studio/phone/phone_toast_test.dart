import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/phone/phone_toast.dart';
import '../../support/pump.dart';

Future<Toaster> pumpToast(WidgetTester tester, {bool hidden = false}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final toaster = Toaster();
  addTearDown(toaster.dispose);
  await tester.pumpWidget(MaterialApp(home: ToastHost(toaster: toaster, bottom: 214, hidden: hidden,
      child: const SizedBox.expand())));
  return toaster;
}

void main() {
  // sayWhole counts a toast as had only when it ran its whole 2.8 s where she could see it.
  testWidgets('a whole toast in sight is had', (tester) async {
    final toaster = await pumpToast(tester);
    bool? had;
    toaster.sayWhole('a').then((w) => had = w);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2800));
    expect(had, isTrue);
  });

  testWidgets('a toast cleared early (an empty say from Back up) is not had', (tester) async {
    final toaster = await pumpToast(tester);
    bool? had;
    toaster.sayWhole('a').then((w) => had = w);
    await tester.pump(const Duration(milliseconds: 500));
    toaster.clear();
    await tester.pump();
    expect(had, isFalse);
  });

  testWidgets('a toast under the open menu is not had', (tester) async {
    final toaster = await pumpToast(tester, hidden: true);
    bool? had;
    toaster.sayWhole('a').then((w) => had = w);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2800));
    expect(had, isFalse);
  });

  testWidgets('a toast a sheet covers for part of its time is not had', (tester) async {
    final toaster = await pumpToast(tester);
    bool? had;
    toaster.sayWhole('a').then((w) => had = w);
    await tester.pump(const Duration(milliseconds: 500));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => const SizedBox.expand())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    nav.pop();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(had, isFalse);
  });

  testWidgets('a toast shows, then goes after 2.8 s', (tester) async {
    final toaster = await pumpToast(tester);
    toaster.say('a');
    await tester.pump();
    expect(find.text('a'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('a'), findsNothing);
    expect(toaster.text, isNull);
  });

  testWidgets('a second toast replaces the first and starts the 2.8 s again', (tester) async {
    final toaster = await pumpToast(tester);
    toaster.say('a');
    await tester.pump(const Duration(seconds: 2));
    toaster.say('b');
    await tester.pump();
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // 4 s
    expect(find.text('b'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900)); // 4.9 s
    expect(find.text('b'), findsNothing);
  });

  testWidgets('clear takes it away at once', (tester) async {
    final toaster = await pumpToast(tester);
    toaster.say('a');
    await tester.pump();
    toaster.clear();
    await tester.pump();
    expect(find.text('a'), findsNothing);
  });

  testWidgets('the toast sits 16 px from each side and 214 px from the foot, and is announced', (tester) async {
    final semantics = tester.ensureSemantics();
    final toaster = await pumpToast(tester);
    toaster.say('a');
    await tester.pump();
    final r = tester.getRect(find.byKey(const ValueKey('phone-toast')));
    expect(r.left, 16);
    expect(r.right, 374);
    expect(r.bottom, 844 - 214);
    expect(tester.getSemantics(find.text('a')).flagsCollection.isLiveRegion, isTrue);
    toaster.clear();
    semantics.dispose();
  });

  test('a toaster said to, or cleared, after it is disposed does nothing and throws nothing', () {
    final toaster = Toaster()..dispose();
    expect(() => toaster.say('x'), returnsNormally);
    expect(() => toaster.clear(), returnsNormally);
    expect(toaster.text, isNull);
  });
}
