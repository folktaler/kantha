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

  testWidgets('with reduced motion the ring stands still', (tester) async {
    await pumpNote(tester, const WaitNote(words: 'Arranging the cloth…'), still: true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<CircularProgressIndicator>(ring).value, isNotNull);
    await pumpNote(tester, const WaitNote(words: 'Arranging the cloth…'), still: false);
    expect(tester.widget<CircularProgressIndicator>(ring).value, isNull);
  });

  group('a toast that waits', () {
    Future<Toaster> pumpToast(WidgetTester tester) async {
      final toaster = Toaster();
      addTearDown(toaster.dispose);
      await tester.pumpWidget(MaterialApp(home: ToastHost(toaster: toaster, bottom: 214, child: const SizedBox.expand())));
      return toaster;
    }

    testWidgets('shows past a second, with a ring, and stays until it is answered', (tester) async {
      final toaster = await pumpToast(tester);
      toaster.wait('Saving a backup…');
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Saving a backup…'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Saving a backup…'), findsOneWidget);
      expect(ring, findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Saving a backup…'), findsOneWidget);
      toaster.say('Saved kantha.zip.');
      await tester.pump();
      expect(find.text('Saving a backup…'), findsNothing);
      expect(find.text('Saved kantha.zip.'), findsOneWidget);
      expect(ring, findsNothing);
      toaster.clear();
    });

    testWidgets('answered inside a second, only the answer shows', (tester) async {
      final toaster = await pumpToast(tester);
      toaster.wait('Saving a backup…');
      await tester.pump(const Duration(milliseconds: 500));
      toaster.say('Saved kantha.zip.');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Saving a backup…'), findsNothing);
      expect(find.text('Saved kantha.zip.'), findsOneWidget);
      toaster.clear();
    });

    testWidgets('cleared inside a second, nothing shows', (tester) async {
      final toaster = await pumpToast(tester);
      toaster.wait('Saving a backup…');
      await tester.pump(const Duration(milliseconds: 500));
      toaster.clear();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Saving a backup…'), findsNothing);
      expect(toaster.text, isNull);
    });
  });
}
