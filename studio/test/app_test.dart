import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/app.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/sample_box.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/platform/links.dart';
import 'package:kantha_studio/studio/phone/phone_studio.dart';
import 'package:kantha_studio/studio/studio_screen.dart';
import 'support/db.dart';
import 'support/pump.dart';
import 'support/studio_fixture.dart';

void main() {
  testWidgets('no popup on launch, whether the browser keeps anything or not', (tester) async {
    await pumpStudio(tester);
    expect(find.text('Got it'), findsNothing);
    expect(find.textContaining('kept in this browser'), findsNothing);
    await pumpStudio(tester, kept: false);
    expect(find.text('Got it'), findsNothing);
    expect(find.textContaining('not keeping what you make here'), findsNothing);
  });

  testWidgets('the app tells the controller whether the browser keeps anything', (tester) async {
    tester.view.physicalSize = desk;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KanthaApp(shelf: Shelf(memoryDb()), makeSolver: QuickSolver.new,
        storageKept: ValueNotifier(false)));
    await letWork(tester, done: () => find.byType(StudioScreen).evaluate().isNotEmpty, turns: 200);
    expect(tester.widget<StudioScreen>(find.byType(StudioScreen)).controller.storageKept, isFalse);
    // Unmounted, the shelf's watches close over drift's next turns.
    await tester.pumpWidget(const SizedBox.shrink());
    await letWork(tester, turns: 3);
  });

  testWidgets('the app feeds its own studio from the shelf: a fresh device opens on the Sample box', (tester) async {
    tester.view.physicalSize = desk;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(KanthaApp(shelf: Shelf(memoryDb()), makeSolver: QuickSolver.new));
    final screen = find.byType(StudioScreen);
    await letWork(tester, done: () => screen.evaluate().isNotEmpty && tester.widget<StudioScreen>(screen).controller.box != null,
        turns: 200);
    final c = tester.widget<StudioScreen>(screen).controller;
    expect(c.isSample(c.box!), isTrue);
    expect(c.piecesIn(c.box!), 70);
    // Unmounted, the shelf's watches close over drift's next turns.
    await tester.pumpWidget(const SizedBox.shrink());
    await letWork(tester, turns: 3);
  });

  /* A device whose Sample box was made before 22 Oct: the eight drawn swatches, 7 pieces each, no swap marker. */
  Future<(Shelf, Set<String>)> oldSampleDevice(WidgetTester tester) async {
    final shelf = Shelf(memoryDb());
    final ids = await tester.runAsync(() async {
      await shelf.addBoxWithCloth(sample: true, cloth: [
        for (final (i, name) in drawnSwatches.indexed)
          (name: name, photo: fixtureJpeg, measured: measuredFor(l: 20.0 + 9 * i, a: 30, b: 10.0 * i), pieces: 7),
      ]);
      await (shelf.db.delete(shelf.db.counters)..where((c) => c.name.equals('sample'))).go();
      return {for (final c in await shelf.db.select(shelf.db.cloths).get()) c.id};
    });
    return (shelf, ids!);
  }

  testWidgets('an old Sample box with no designs gets the real cloth before the studio opens on it', (tester) async {
    tester.view.physicalSize = desk;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (shelf, _) = await oldSampleDevice(tester);
    await tester.pumpWidget(KanthaApp(shelf: shelf, makeSolver: QuickSolver.new));
    final screen = find.byType(StudioScreen);
    await letWork(tester, done: () => screen.evaluate().isNotEmpty && tester.widget<StudioScreen>(screen).controller.box != null,
        turns: 200);
    final c = tester.widget<StudioScreen>(screen).controller;
    expect([for (final m in c.members(c.box)) c.cloth[m].name], [for (final s in sampleCloth) s.name],
        reason: 'the first board is arranged from the real cloth, not the swatches');
    await tester.pumpWidget(const SizedBox.shrink());
    await letWork(tester, turns: 3);
  });

  testWidgets('an old Sample box with a design gets the real cloth once the studio has drawn the design\'s picture',
      (tester) async {
    tester.view.physicalSize = desk;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (shelf, ids) = await oldSampleDevice(tester);
    await tester.runAsync(() => shelf.saveDesign(DesignInput(name: 'Old swatches', layout: 'contrast', mount: 'none',
        box: null, seed: 1, started: null, firstSolve: null,
        grid: [for (var i = 0; i < 35; i++) GridCell(ids.elementAt(i % ids.length), 0)])));
    await tester.pumpWidget(KanthaApp(shelf: shelf, makeSolver: QuickSolver.new));
    final screen = find.byType(StudioScreen);
    await letWork(tester, done: () => screen.evaluate().isNotEmpty && tester.widget<StudioScreen>(screen).controller.box != null,
        turns: 200);
    final c = tester.widget<StudioScreen>(screen).controller;
    await letWork(tester, done: () => c.saved.isEmpty && c.pictures.isNotEmpty, turns: 400);
    expect([for (final m in c.members(c.box)) c.cloth[m].name], [for (final s in sampleCloth) s.name]);
    expect(c.saved, isEmpty);
    expect([for (final p in c.pictures) (p.name, p.design)], [('Old swatches', null)], reason: 'Picture only');
    final png = await tester.runAsync(() => shelf.pictureOf(c.pictures.single.id));
    expect(png!.take(4), [0x89, 0x50, 0x4E, 0x47], reason: 'a real picture, drawn before the swatches went');
    // The studio opened on the swatches; once they have gone the board is dealt again from the real cloth.
    bool dealtFromBox() => !c.solving && c.grid != null && c.grid!.every(c.members(c.box).toSet().contains);
    await letWork(tester, done: dealtFromBox, turns: 400);
    expect(dealtFromBox(), isTrue, reason: 'no square shows a swatch that has gone');
    await tester.pumpWidget(const SizedBox.shrink());
    await letWork(tester, turns: 3);
  });

  for (final malayalam in [true, false]) {
    testWidgets('the Malayalam face loads before the first frame only when a name on the first screen is written in it '
        '(Malayalam: $malayalam)', (tester) async {
      tester.view.physicalSize = desk;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final shelf = Shelf(memoryDb());
      await tester.runAsync(() async {
        await ensureSampleBox(shelf);
        if (malayalam) await shelf.db.customStatement("UPDATE cloths SET name = 'ചുവപ്പ്' WHERE id = 'C-1'");
      });
      final face = Completer<void>();
      final drawnAtAsk = <bool>[];
      await tester.pumpWidget(KanthaApp(shelf: shelf, makeSolver: QuickSolver.new, malayalam: () {
        drawnAtAsk.add(find.byType(StudioScreen).evaluate().isNotEmpty);
        return face.future;
      }));
      await letWork(tester, done: () => drawnAtAsk.isNotEmpty, turns: 200);
      expect(drawnAtAsk.first, !malayalam, reason: malayalam ? 'asked before the studio is drawn' : 'asked after it');
      expect(find.byType(StudioScreen), malayalam ? findsNothing : findsOneWidget,
          reason: malayalam ? 'the studio waits for the face' : 'nothing waits');
      face.complete();
      await letWork(tester, done: () => find.byType(StudioScreen).evaluate().isNotEmpty, turns: 200);
      expect(find.byType(StudioScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await letWork(tester, turns: 3);
    });
  }

  testWidgets('the page\'s loading screen goes after the frame that draws the studio, not the ground before it', (tester) async {
    tester.view.physicalSize = desk;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hidden = <bool>[]; // at each call: was the studio drawn?
    await tester.pumpWidget(KanthaApp(shelf: Shelf(memoryDb()), makeSolver: QuickSolver.new,
        hideLoading: () => hidden.add(find.byType(StudioScreen).evaluate().isNotEmpty)));
    expect(find.byType(StudioScreen), findsNothing, reason: 'the shelf has not answered: only the ground');
    expect(hidden, isEmpty);
    await letWork(tester, done: () => hidden.isNotEmpty, turns: 200);
    await tester.pump();
    expect(hidden, [true], reason: 'once, with the studio on the page');
    await tester.pumpWidget(const SizedBox.shrink());
    await letWork(tester, turns: 3);
  });

  // A query or a fragment on the link still opens the sheet.
  for (final (what, size, route) in [('desk', desk, '/backup'), ('phone', phone, '/backup'), ('desk', desk, '/backup?from=help')]) {
    testWidgets('on a $what a link to $route opens the studio with the Back up sheet up over it', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
      addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(KanthaApp(shelf: Shelf(memoryDb()), makeSolver: QuickSolver.new));
      await letWork(tester, done: () => find.text('Open a backup file').evaluate().isNotEmpty, turns: 200);
      expect(find.byType(PhoneStudio), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Save a backup file'), findsOneWidget);
      expect(find.text('Open a backup file'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(PhoneStudio), findsOneWidget);
      // Unmounted, the shelf's watches close over drift's next turns.
      await tester.pumpWidget(const SizedBox.shrink());
      await letWork(tester, turns: 3);
    });
  }

  testWidgets('the studio itself opens with no sheet up', (tester) async {
    await pumpStudio(tester);
    expect(find.byType(PhoneStudio), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('when her boxes cannot be read, the page says so rather than standing blank', (tester) async {
    await tester.pumpWidget(KanthaApp(shelf: _UnreadableShelf(), makeSolver: QuickSolver.new));
    await letWork(tester, done: () => find.textContaining('could not be read').evaluate().isNotEmpty);
    expect(tester.takeException(), isA<StateError>(), reason: 'reported, as well as said');
    expect(find.text('Your cloth could not be read just now. Nothing is lost — try again in a few minutes.'), findsOneWidget);
    expect(find.byType(StudioScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await letWork(tester, turns: 3);
  });

  testWidgets('when the solver cannot start, the page says so rather than standing blank', (tester) async {
    var hidden = 0;
    await tester.pumpWidget(KanthaApp(shelf: Shelf(memoryDb()),
        makeSolver: () => throw StateError('no worker'), hideLoading: () => hidden++));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Your cloth could not be read just now. Nothing is lost — try again in a few minutes.'), findsOneWidget);
    expect(find.byType(StudioScreen), findsNothing);
    expect(hidden, 1, reason: 'the loading screen goes for this page too');
    await tester.pumpWidget(const SizedBox.shrink());
    await letWork(tester, turns: 3);
  });

  testWidgets('Help and the privacy policy open the site\'s own pages; Shop, the catsofkochi shop in a new tab', (tester) async {
    expect(helpUriFor(web: true, anchor: 'lay').toString(), '/help#lay');
    expect(helpUriFor(web: false, anchor: 'lay').toString(), 'https://kantha.app/help#lay');
    expect(helpUriFor(web: false).toString(), 'https://kantha.app/help');
    expect(shopUri().toString(), 'https://catsofkochi.com/shop/');
    expect(privacyUriFor(web: true).toString(), '/policies/privacy');
    expect(privacyUriFor(web: false).toString(), 'https://kantha.app/policies/privacy');
    // In a browser: the shop in a new tab, Help in the studio's own.
    expect(webWindowFor(shopUri()), '_blank');
    expect(webWindowFor(helpUriFor(web: true, anchor: 'lay')), '_self');
    expect(webWindowFor(privacyUriFor(web: true)), '_self');
  });
}

/* A shelf whose boxes cannot be read, as a damaged database is. */
class _UnreadableShelf extends Shelf {
  _UnreadableShelf() : super(memoryDb());
  @override
  Stream<List<BoxRow>> watchBoxes() => Stream.error(StateError('the boxes cannot be read'));
}
