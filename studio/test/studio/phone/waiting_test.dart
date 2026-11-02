import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/phone/phone_toast.dart';
import 'package:kantha_studio/studio/phone/waiting.dart';

/* Waiting by Nielsen's limits (waiting.dart): nothing for a quick wait, the ring and the words past a second, the bar,
   the step and Stop past 10 s; the ring stands still with reduced motion. */
void main() {
  Future<void> pumpNote(WidgetTester tester, Widget note, {bool still = false}) => tester.pumpWidget(MaterialApp(
      home: MediaQuery(data: MediaQueryData(disableAnimations: still), child: Scaffold(body: Center(child: note)))));

  final ring = find.byType(CircularProgressIndicator), bar = find.byType(LinearProgressIndicator);

  testWidgets('a wait shows nothing for its first second, then the ring and its words', (tester) async {
    await pumpNote(tester, const WaitNote(words: 'Arranging the cloth…'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Arranging the cloth…'), findsNothing);
    expect(ring, findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Arranging the cloth…'), findsOneWidget);
    expect(ring, findsOneWidget);
    expect(bar, findsNothing);
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('a wait that ends inside its first second never shows anything', (tester) async {
    await pumpNote(tester, const WaitNote(words: 'Arranging the cloth…'));
    await tester.pump(const Duration(milliseconds: 600));
    await pumpNote(tester, const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Arranging the cloth…'), findsNothing);
    expect(ring, findsNothing);
  });

  testWidgets('past 10 s: the bar, the step and Stop, and Stop stops it', (tester) async {
    var stopped = 0;
    Widget note(({int done, int of})? step) => WaitNote(key: const ValueKey('w'), words: 'Arranging the cloth…', step: step,
        stepWords: (d, of) => 'Tried $d of $of arrangements', onStop: () => stopped++, stopWords: 'Stop');
    await pumpNote(tester, note(null));
    await tester.pump(const Duration(seconds: 9));
    expect(bar, findsNothing);
    await pumpNote(tester, note((done: 3, of: 8)));
    await tester.pump(const Duration(seconds: 1));
    expect(bar, findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(bar).value, 3 / 8);
    expect(find.text('Tried 3 of 8 arrangements'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    expect(stopped, 1);
  });

  testWidgets('a wait whose steps say it will pass 10 s shows the bar and Stop as soon as that is known', (tester) async {
    Widget note(({int done, int of})? step) => WaitNote(key: const ValueKey('w'), words: 'Arranging the cloth…', step: step,
        stepWords: (d, of) => 'Tried $d of $of arrangements', onStop: () {}, stopWords: 'Stop');
    await pumpNote(tester, note(null));
    await tester.pump(const Duration(seconds: 2));
    expect(bar, findsNothing);
    expect(ring, findsOneWidget);
    // 1 of 8 in 2 s: 16 s in all.
    await pumpNote(tester, note((done: 1, of: 8)));
    expect(bar, findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(ring, findsNothing);
  });

  testWidgets('a wait whose steps say it ends inside 10 s keeps the ring', (tester) async {
    Widget note(({int done, int of})? step) => WaitNote(key: const ValueKey('w'), words: 'Arranging the cloth…', step: step,
        onStop: () {}, stopWords: 'Stop');
    await pumpNote(tester, note(null));
    await tester.pump(const Duration(seconds: 2));
    await pumpNote(tester, note((done: 4, of: 8))); // 4 s in all
    expect(ring, findsOneWidget);
    expect(bar, findsNothing);
  });

  testWidgets('the ring turns an eighth each 125 ms and draws nothing between; with reduced motion it stands still',
      (tester) async {
    final turning = find.ancestor(of: ring, matching: find.byType(Transform));
    Matrix4 turn() => tester.widget<Transform>(turning.first).transform;
    await pumpNote(tester, const WaitNote(words: 'Arranging the cloth…'));
    await tester.pump(const Duration(seconds: 1));
    final first = turn();
    await tester.pump(const Duration(milliseconds: 100));
    expect(turn(), first);
    expect(tester.binding.hasScheduledFrame, isFalse); // no frame between turns
    await tester.pump(const Duration(milliseconds: 25));
    expect(turn(), isNot(first));

    await pumpNote(tester, const WaitNote(key: ValueKey('still'), words: 'Arranging the cloth…'), still: true);
    await tester.pump(const Duration(seconds: 1));
    expect(ring, findsOneWidget);
    expect(turning, findsNothing);
    await tester.pump(WaitRing.turnEvery);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('with tickers off (a route under another, offstage) the ring stands still and draws nothing; on again, '
      'it turns', (tester) async {
    final turning = find.ancestor(of: ring, matching: find.byType(Transform));
    Matrix4 turn() => tester.widget<Transform>(turning.first).transform;
    Widget note(bool on) => TickerMode(enabled: on, child: const WaitNote(key: ValueKey('w'), words: 'Arranging the cloth…'));
    await pumpNote(tester, note(true));
    await tester.pump(waitShows);
    await pumpNote(tester, note(false));
    final still = turn();
    await tester.pump(WaitRing.turnEvery * 3);
    expect(turn(), still);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await pumpNote(tester, note(true));
    await tester.pump(WaitRing.turnEvery);
    expect(turn(), isNot(still));
  });

  test('after a slow frame the ring waits 3 times its cost, never under 125 ms nor over 500 ms (a tab hidden a minute)',
      () {
    expect(nextTurnAfter(const Duration(milliseconds: 5)), WaitRing.turnEvery);
    expect(nextTurnAfter(const Duration(milliseconds: 100)), const Duration(milliseconds: 300));
    expect(nextTurnAfter(const Duration(minutes: 1)), const Duration(milliseconds: 500));
  });

  group('a toast that waits', () {
    Future<Toaster> pumpToast(WidgetTester tester) async {
      final toaster = Toaster();
      addTearDown(toaster.dispose);
      await tester.pumpWidget(MaterialApp(home: ToastHost(toaster: toaster, bottom: 214, child: const SizedBox.expand())));
      return toaster;
    }

    testWidgets('shows past a second, with a ring, and stays until its work ends; then what it said', (tester) async {
      final toaster = await pumpToast(tester);
      final end = toaster.wait('Saving a backup…');
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Saving a backup…'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Saving a backup…'), findsOneWidget);
      expect(ring, findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Saving a backup…'), findsOneWidget);
      toaster.say('Saved kantha.zip.');
      await tester.pump();
      expect(find.text('Saving a backup…'), findsOneWidget, reason: 'said while it works: after');
      end();
      await tester.pump();
      expect(find.text('Saving a backup…'), findsNothing);
      expect(find.text('Saved kantha.zip.'), findsOneWidget);
      expect(ring, findsNothing);
      toaster.clear();
    });

    testWidgets('something else said while it works does not end it: it is said after, and then the answer',
        (tester) async {
      final toaster = await pumpToast(tester);
      final end = toaster.wait('Opening the backup…');
      await tester.pump(waitShows);
      toaster.say('Saved to My designs.');
      toaster.clear(); // as a flow with nothing to say clears: what was said still comes
      toaster.say('Saved to My designs.'); // said again: a second toast
      await tester.pump();
      expect(find.text('Opening the backup…'), findsOneWidget);
      toaster.say('This device now holds kantha.zip.');
      end();
      await tester.pump();
      expect(find.text('Saved to My designs.'), findsOneWidget);
      await tester.pump(Toaster.showFor);
      expect(find.text('Saved to My designs.'), findsOneWidget, reason: 'the second time it was said');
      await tester.pump(Toaster.showFor);
      expect(find.text('This device now holds kantha.zip.'), findsOneWidget);
      await tester.pump(Toaster.showFor);
      expect(toaster.text, isNull);
    });

    testWidgets('ended inside a second, only what it said shows', (tester) async {
      final toaster = await pumpToast(tester);
      final end = toaster.wait('Saving a backup…');
      await tester.pump(const Duration(milliseconds: 500));
      toaster.say('Saved kantha.zip.');
      end();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Saving a backup…'), findsNothing);
      expect(find.text('Saved kantha.zip.'), findsOneWidget);
      toaster.clear();
    });

    testWidgets('ended inside a second with nothing said, nothing shows', (tester) async {
      final toaster = await pumpToast(tester);
      final end = toaster.wait('Saving a backup…');
      await tester.pump(const Duration(milliseconds: 500));
      end();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Saving a backup…'), findsNothing);
      expect(toaster.text, isNull);
    });
  });
}
