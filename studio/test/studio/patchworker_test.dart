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

/* "I am a…" (owner, 30 Oct 2026): Beginner is the 5 × 7 A4 board, as before; Patchworker any size, a picture only. */
void main() {
  Future<void> choose(WidgetTester tester, String level) async {
    await tester.tap(key('phone-menu'));
    await tester.pumpAndSettle();
    await tester.tap(key('level-$level'));
    await tester.pumpAndSettle();
  }

  for (final (what, size) in [('phone', phone), ('desk', desk)]) {
    testWidgets('on a $what a Beginner has the 5 × 7 board, the mounts and no Rows or Columns, as before', (tester) async {
      final c = await pumpStudio(tester, size: size, solver: SizedQuickSolver());
      expect((c.patchworker, c.size, c.onA4), (false, level1, true));
      expect(c.grid, hasLength(35));
      expect(key('cell-34'), findsOneWidget);
      expect(key('cell-35'), findsNothing);
      expect(key('board-size'), findsNothing);
      await tester.tap(key('tab-finish'));
      await tester.pumpAndSettle();
      expect(key('mount-frame'), findsOneWidget);
      expect(key('mount-tote'), findsOneWidget);
      await tester.tap(key('phone-menu'));
      await tester.pumpAndSettle();
      expect(find.text('I AM A…'), findsOneWidget);
      expect(find.text('Beginner (5 × 7)'), findsOneWidget);
      expect(find.text('Patchworker (any size)'), findsOneWidget);
    });

    testWidgets('on a $what she becomes a Patchworker, changes the size, and goes back to Beginner', (tester) async {
      final solver = SizedQuickSolver();
      final c = await pumpStudio(tester, size: size, solver: solver);
      final beginners = c.grid;
      await choose(tester, 'patchworker');
      expect(c.patchworker, isTrue);
      expect(c.size, level1, reason: 'a Patchworker starts on the board she had');
      expect(key('board-size'), findsOneWidget);
      expect(tester.widget<Text>(key('rows-count')).data, '7');
      expect(tester.widget<Text>(key('columns-count')).data, '5');
      await tester.ensureVisible(key('rows-more'));
      await tester.tap(key('rows-more'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(key('columns-more'));
      await tester.tap(key('columns-more'));
      await tester.pumpAndSettle();
      expect(c.size, (rows: 8, cols: 6));
      expect(solver.asked.last, (rows: 8, cols: 6));
      expect(c.grid, hasLength(48));
      expect(key('cell-47'), findsOneWidget);
      expect(key('cell-48'), findsNothing);
      await tester.tap(key('tab-finish'));
      await tester.pumpAndSettle();
      expect(key('mount-frame'), findsNothing, reason: 'the frame and the tote stay with 5 × 7');
      expect(key('mount-tote'), findsNothing);
      expect(await tester.runAsync(() => c.shelf.setting(StudioController.levelKey)), 'patchworker');
      expect(await tester.runAsync(() => c.shelf.setting(StudioController.sizeKey)), '8x6');

      await choose(tester, 'beginner');
      expect((c.patchworker, c.size), (false, level1));
      expect(c.grid, beginners, reason: 'the 5 × 7 arrangement she left comes back');
      expect(key('board-size'), findsNothing);
      expect(await tester.runAsync(() => c.shelf.setting(StudioController.levelKey)), 'beginner');
    });
  }

  test('the board she chose is remembered on the device, and a setting that does not read is a Beginner\'s', () async {
    final s = await studio(solver: SizedQuickSolver());
    s.c.setPatchworker(true);
    s.c.setBoardSize((rows: 4, cols: 9));
    await settle();
    final again = StudioController(shelf: s.shelf, solver: SizedQuickSolver(), words: s.c.words);
    await again.loadBoard();
    expect((again.patchworker, again.size), (true, (rows: 4, cols: 9)));
    await s.shelf.setSetting(StudioController.sizeKey, '40x2');
    final odd = StudioController(shelf: s.shelf, solver: SizedQuickSolver(), words: s.c.words);
    await odd.loadBoard();
    expect(odd.size, level1, reason: 'a size outside $boardMin to $boardMax is not taken');
  });

  test('Rows and Columns stay between $boardMin and $boardMax, and only a Patchworker has them', () async {
    final s = await studio(solver: SizedQuickSolver());
    s.c.setBoardSize((rows: 9, cols: 9));
    expect(s.c.size, level1, reason: 'a Beginner has no size to change');
    s.c.setPatchworker(true);
    s.c.setBoardSize((rows: 1, cols: 40));
    expect(s.c.size, (rows: boardMin, cols: boardMax));
  });

  test('a Patchworker design saves its size, opens again on it, and makes its picture', () async {
    final s = await studio(solver: SizedQuickSolver());
    s.c.setPatchworker(true);
    s.c.setBoardSize((rows: 6, cols: 8));
    await settle();
    final id = await s.c.save();
    await settle();
    final d = s.c.designFor(id!)!;
    expect((d.size, d.onA4, d.grid.length), ((rows: 6, cols: 8), false, 48));
    expect((await s.shelf.watchDesigns().first).single.cols, 8);
    expect(wordsFor(s.c.words, d).caption[2], 'Upcycled from 48 cloth pieces');

    s.c.setPatchworker(false);
    expect(s.c.size, level1);
    expect(s.c.openSaved(s.c.saved.single), isTrue);
    expect((s.c.patchworker, s.c.size, s.c.grid?.length), (true, (rows: 6, cols: 8), 48),
        reason: 'opening it makes the board its size again');
  });

  testWidgets('a Patchworker design makes its 1080 × 1350 picture', (tester) async {
    await tester.runAsync(loadFonts);
    final s = (await tester.runAsync(() => studio(solver: SizedQuickSolver())))!;
    s.c.setPatchworker(true);
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
    await choose(tester, 'patchworker');
    await tester.ensureVisible(key('rows-fewer'));
    await tester.tap(key('rows-fewer'));
    await tester.pumpAndSettle();
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
