import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/downloads/caption.dart';
import 'package:kantha_studio/downloads/photo_png.dart';
import 'package:kantha_studio/platform/solver_runner.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/studio/controller.dart';
import '../downloads/photo_png_test.dart' show loadFonts;
import '../support/db.dart';
import '../support/fonts.dart' as faces;
import '../support/pump.dart';
import '../support/studio_fixture.dart';

/* QuickSolver on a board of any size: each seed deals the members in a different turn. */
class SizedQuickSolver extends QuickSolver implements SizedSolverRunner {
  final asked = <BoardSize>[];
  @override
  Future<LayoutSolve> solveOn(BoardSize size, LayoutKey layout, List<int> members, Mount mount, int seed) async {
    asked.add(size);
    final n = size.rows * size.cols;
    return LayoutSolve(true, [for (var i = 0; i < n; i++) members[(i + seed) % members.length]],
        [for (var i = 0; i < n; i++) (i + seed) % 4]);
  }
}

/* One board, its size from Rows and Columns on the Design tab, 5 × 7 to start (owner, 31 Oct 2026: no levels). 5 × 7 is
   the A4 board, as before; any other size is a picture only. */
void main() {
  fitsAtIphone13();

  Future<void> press(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  for (final (what, size) in [('phone', phone), ('desk', desk)]) {
    testWidgets('on a $what the board starts 5 × 7 with the mounts, and Rows and Columns are on the Design tab', (tester) async {
      final c = await pumpStudio(tester, size: size, solver: SizedQuickSolver());
      expect((c.size, c.onA4), (level1, true));
      expect(c.grid, hasLength(35));
      expect(key('cell-34'), findsOneWidget);
      expect(key('cell-35'), findsNothing);
      expect(find.descendant(of: key('dock-design'), matching: key('board-size')), findsOneWidget);
      expect(tester.widget<Text>(key('rows-count')).data, '7');
      expect(tester.widget<Text>(key('columns-count')).data, '5');
      expect(find.text('Size'), findsNothing, reason: 'no Size line and no levels');
      expect(key('level-beginner'), findsNothing);
      await tester.tap(key('tab-finish'));
      await tester.pumpAndSettle();
      expect(key('mount-frame'), findsOneWidget);
      expect(key('mount-tote'), findsOneWidget);
      await tester.tap(key('phone-menu'));
      await tester.pumpAndSettle();
      expect(key('menu-panel'), findsOneWidget);
      expect(find.text('I AM A…'), findsNothing, reason: 'the Menu has no level');
    });

    testWidgets('on a $what she changes the size, and back to 5 × 7 her arrangement on it comes back', (tester) async {
      final solver = SizedQuickSolver();
      final c = await pumpStudio(tester, size: size, solver: solver);
      final first = c.grid;
      await press(tester, 'rows-more');
      await press(tester, 'columns-more');
      expect(c.size, (rows: 8, cols: 6));
      expect(solver.asked.last, (rows: 8, cols: 6));
      expect(c.grid, hasLength(48));
      expect(key('cell-47'), findsOneWidget);
      expect(key('cell-48'), findsNothing);
      await tester.tap(key('tab-finish'));
      await tester.pumpAndSettle();
      expect(key('mount-frame'), findsNothing, reason: 'the frame and the tote stay with 5 × 7');
      expect(key('mount-tote'), findsNothing);
      expect(await tester.runAsync(() => c.shelf.setting(StudioController.sizeKey)), '8x6');
      expect(await tester.runAsync(() => c.shelf.setting(StudioController.levelKey)), StudioController.levelSize);

      await tester.tap(key('tab-patterns'));
      await tester.pumpAndSettle();
      await press(tester, 'rows-fewer');
      await press(tester, 'columns-fewer');
      expect(c.size, level1);
      expect(c.grid, first, reason: 'the 5 × 7 arrangement she left comes back');
      await tester.tap(key('tab-finish'));
      await tester.pumpAndSettle();
      expect(key('mount-frame'), findsOneWidget);
    });
  }

  test('the board she chose is remembered on the device, and a setting that does not read is 5 × 7', () async {
    final s = await studio(solver: SizedQuickSolver());
    s.c.setBoardSize((rows: 4, cols: 9));
    await settle();
    final again = StudioController(shelf: s.shelf, solver: SizedQuickSolver(), words: s.c.words);
    await again.loadBoard();
    expect(again.size, (rows: 4, cols: 9));
    await s.shelf.setSetting(StudioController.sizeKey, '40x2');
    final odd = StudioController(shelf: s.shelf, solver: SizedQuickSolver(), words: s.c.words);
    await odd.loadBoard();
    expect(odd.size, level1, reason: 'a size outside $boardMin to $boardMax is not taken');
  });

  // From 30 to 31 Oct 2026 there were two levels; a device keeps what it had.
  test('a device that had chosen the second level (stored \'patchworker\') keeps its size', () async {
    final s = await studio(solver: SizedQuickSolver());
    await s.shelf.setSetting(StudioController.levelKey, 'patchworker');
    await s.shelf.setSetting(StudioController.sizeKey, '6x8');
    final again = StudioController(shelf: s.shelf, solver: SizedQuickSolver(), words: s.c.words);
    await again.loadBoard();
    expect(again.size, (rows: 6, cols: 8));
  });

  test('a device at Beginner stays 5 × 7, whatever size it last held, until she changes it', () async {
    final s = await studio(solver: SizedQuickSolver());
    await s.shelf.setSetting(StudioController.levelKey, 'beginner');
    await s.shelf.setSetting(StudioController.sizeKey, '6x8');
    final again = StudioController(shelf: s.shelf, solver: SizedQuickSolver(), words: s.c.words);
    await again.loadBoard();
    expect(again.size, level1);
    again.setBoardSize((rows: 9, cols: 4));
    await settle();
    final later = StudioController(shelf: s.shelf, solver: SizedQuickSolver(), words: s.c.words);
    await later.loadBoard();
    expect(later.size, (rows: 9, cols: 4), reason: 'her own change is kept from then on');
  });

  test('Rows and Columns stay between $boardMin and $boardMax', () async {
    final s = await studio(solver: SizedQuickSolver());
    s.c.setBoardSize((rows: 1, cols: 40));
    expect(s.c.size, (rows: boardMin, cols: boardMax));
  });

  test('a design of another size saves its size, opens again on it, and makes its picture', () async {
    final s = await studio(solver: SizedQuickSolver());
    s.c.setBoardSize((rows: 6, cols: 8));
    await settle();
    final id = await s.c.save();
    await settle();
    final d = s.c.designFor(id!)!;
    expect((d.size, d.onA4, d.grid.length), ((rows: 6, cols: 8), false, 48));
    expect((await s.shelf.watchDesigns().first).single.cols, 8);
    expect(wordsFor(s.c.words, d).caption[2], 'Upcycled from 48 cloth pieces');

    s.c.setBoardSize(level1);
    expect(s.c.size, level1);
    expect(s.c.openSaved(s.c.saved.single), isTrue);
    expect((s.c.size, s.c.grid?.length), ((rows: 6, cols: 8), 48), reason: 'opening it makes the board its size again');
  });

  testWidgets('a design of another size makes its 1080 × 1350 picture', (tester) async {
    await tester.runAsync(loadFonts);
    final s = (await tester.runAsync(() => studio(solver: SizedQuickSolver())))!;
    s.c.setBoardSize((rows: 3, cols: 11));
    await tester.runAsync(settle);
    final id = await tester.runAsync(() => s.c.save());
    final d = s.c.designFor(id!)!;
    final made = (await tester.runAsync(() => photoPng(d, const {}, wordsFor(s.c.words, d).caption)))!;
    final image = img.decodePng(made.png)!;
    expect((image.width, image.height), (photoWidth, photoHeight));
  });

  testWidgets('a design of another size is a picture only: Save photo and Share…, no print sheet, frame or tote',
      (tester) async {
    final delivery = CaptureDelivery();
    final c = await pumpStudio(tester, size: phone, delivery: delivery, solver: SizedQuickSolver());
    await press(tester, 'rows-fewer');
    expect(c.size, (rows: 6, cols: 5));
    c.setMount(Mount.frame);
    expect(c.mount, Mount.none, reason: 'no frame off A4');
    await tester.tap(key('phone-export'));
    await letWork(tester, done: () => find.text('Share…').evaluate().isNotEmpty, turns: 300);
    expect(c.saved.single.size, (rows: 6, cols: 5));
    expect(find.text('Save photo'), findsOneWidget);
    expect(find.text('Share…'), findsOneWidget);
    expect(find.text('Print pattern PDF'), findsNothing);
    expect(find.text('Kantha stitching guide'), findsNothing);
  });

  test('the shelf takes a design of any allowed size, and still refuses one whose squares do not fill its rows', () async {
    final shelf = Shelf(memoryDb());
    DesignInput of(int n, int cols) => DesignInput(name: 'x', layout: 'contrast', mount: 'none', box: 1, seed: 1,
        started: null, firstSolve: null, grid: List.generate(n, (_) => GridCell('KF-1', 0)), cols: cols);
    expect((await shelf.saveDesign(of(36, 12))).design.cols, 12);
    for (final (n, cols) in [(34, 5), (30, 2), (26, 13), (4, 2)]) {
      expect(() => shelf.saveDesign(of(n, cols)), throwsA(isA<ShelfError>()), reason: '$n squares over $cols');
    }
  });
}

/* The board whole above the dock at a phone 390 × 664 (Playwright's iPhone 13), at every size, in Safari under its
   banner too (owner, 31 Oct 2026). */
void fitsAtIphone13() {
  const iphone13 = Size(390, 664);
  // The studio's own faces, so the banners wrap as the browser wraps them.
  setUpAll(faces.loadFonts);
  for (final safari in [false, true]) {
    for (final g in [null, (rows: 8, cols: 8), (rows: 12, cols: 12), (rows: 3, cols: 12), (rows: 12, cols: 3)]) {
      testWidgets('at 390 × 664${safari ? ' in Safari, under its banner,' : ''} the '
          '${g == null ? '5 × 7' : '${g.rows} × ${g.cols}'} board is whole above the dock', (tester) async {
        final c = await pumpStudio(tester, size: iphone13, solver: SizedQuickSolver(), safariOnIphone: safari);
        if (g != null) {
          c.setBoardSize(g);
          await tester.pumpAndSettle();
        }
        final board = tester.getRect(key('phone-board')), dock = tester.getRect(key('dock-panel')),
            bar = tester.getRect(key('phone-topbar'));
        expect(board.top, greaterThanOrEqualTo(bar.bottom), reason: '$board under the top bar $bar');
        expect(board.bottom, lessThanOrEqualTo(dock.top), reason: '$board over the dock $dock');
        expect((board.left >= 0, board.right <= iphone13.width), (true, true), reason: '$board');
      });
    }
  }
}
