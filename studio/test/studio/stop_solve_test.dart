import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/studio/phone/waiting.dart';
import '../support/pump.dart';
import '../support/studio_fixture.dart';

/* A solver that says its steps and can be stopped, and holds every solve while `hold` is set, until the test answers
   it or Stop stops it. Without `hold` it answers at once, as QuickSolver does, at any size. */
class HeldSolver extends QuickSolver {
  bool hold = false;
  int stops = 0;
  final held = <({Completer<LayoutSolve> done, void Function(int, int) onStep, LayoutSolve answer})>[];

  @override
  Future<LayoutSolve> solve(BoardSize? size, LayoutKey layout, List<int> members, Mount mount, int seed,
      {void Function(int done, int of)? onStep}) {
    final answer = deal(size, members, seed);
    if (!hold) return Future.value(answer);
    final done = Completer<LayoutSolve>();
    held.add((done: done, onStep: onStep ?? (_, _) {}, answer: answer));
    return done.future;
  }

  void answerLast() {
    final h = held.removeLast();
    h.done.complete(h.answer);
  }

  @override
  void stop() {
    stops++;
    for (final h in held) {
      if (!h.done.isCompleted) h.done.complete(const LayoutSolve(false, null, null));
    }
    held.clear();
  }
}

void main() {
  test('Stop after a pattern press: the board, its pattern and its name are as they were, and the solve is stopped', () async {
    final solver = HeldSolver();
    final c = (await studio(solver: solver)).c;
    final grid = c.grid, layout = c.layout, name = c.name, seed = c.seed;
    expect(grid, isNotNull);
    solver.hold = true;
    final next = layoutKeys.firstWhere((k) => k != layout && c.feasible[k]!.fills);
    c.loadLayout(next);
    await pumpEventQueue();
    expect(c.solving, isTrue);
    expect(c.canStop, isTrue);
    c.stopSolve();
    await pumpEventQueue();
    expect(solver.stops, 1);
    expect(c.solving, isFalse);
    expect(c.canStop, isFalse);
    expect(c.layout, layout);
    expect(c.name, name);
    expect(c.grid, grid);
    expect(c.seed, seed);
    expect(c.note, isEmpty);
  });

  test('Stop after Rows +: the board is its old size again, with its old arrangement', () async {
    final solver = HeldSolver();
    final c = (await studio(solver: solver)).c;
    final grid = c.grid, size = c.size;
    solver.hold = true;
    c.setBoardSize((rows: size.rows + 1, cols: size.cols));
    await pumpEventQueue();
    expect(c.grid, isNull);
    expect(c.canStop, isTrue);
    c.stopSolve();
    await pumpEventQueue();
    expect(c.size, size);
    expect(c.grid, grid);
    expect(c.solving, isFalse);
  });

  test('a solve the press did not ask for (the first one) cannot be stopped', () async {
    final solver = HeldSolver()..hold = true;
    final c = (await studio(solver: solver)).c;
    expect(c.solving, isTrue);
    expect(c.canStop, isFalse); // nothing to go back to
    c.stopSolve();
    expect(solver.stops, 0);
  });

  test('two pattern presses while it solves, then Stop: the board from before the first, exactly, not half of each',
      () async {
    final solver = HeldSolver();
    final c = (await studio(solver: solver)).c;
    final grid = c.grid, rot = c.rot, layout = c.layout, name = c.name, seed = c.seed, mount = c.mount;
    solver.hold = true;
    final others = layoutKeys.where((k) => k != layout && c.feasible[k]!.fills).toList();
    c.loadLayout(others[0]);
    c.loadLayout(others[1]);
    expect(c.canStop, isTrue);
    c.stopSolve();
    await pumpEventQueue();
    expect((c.layout, c.name, c.grid, c.rot, c.seed, c.mount), (layout, name, grid, rot, seed, mount));
    expect(c.solving, isFalse);
  });

  test('a box opened, then another, while it solves, then Stop: the first box\'s board, exactly', () async {
    final solver = HeldSolver();
    final s = await studio(solver: solver);
    final c = s.c;
    final two = await s.shelf.makeBox(), three = await s.shelf.makeBox();
    for (final b in [two, three]) {
      for (var i = 0; i < 5; i++) {
        await s.shelf.addPiecesForTest(b, 7);
      }
    }
    await pumpEventQueue();
    final box = c.box, grid = c.grid, rot = c.rot, layout = c.layout, name = c.name, feasible = c.feasible;
    solver.hold = true;
    c.openBox(two);
    c.openBox(three);
    expect(c.canStop, isTrue);
    c.stopSolve();
    await pumpEventQueue();
    expect((c.box, c.grid, c.rot, c.layout, c.name), (box, grid, rot, layout, name));
    expect(c.feasible, feasible);
  });

  test('Stop puts back the note the board had, as it was, and says it no second time', () async {
    final solver = HeldSolver();
    final c = (await studio(solver: solver)).c;
    c.note = 'Could not save this design.';
    c.warn = true;
    final notes = c.notes;
    solver.hold = true;
    c.newDesign(); // clears the note while it solves
    expect(c.note, isEmpty);
    c.stopSolve();
    expect((c.note, c.warn, c.notes), ('Could not save this design.', true, notes));
  });

  test('the steps are the solve on the board\'s; a later press starts again from none', () async {
    final solver = HeldSolver();
    final c = (await studio(solver: solver)).c;
    solver.hold = true;
    final others = layoutKeys.where((k) => k != c.layout && c.feasible[k]!.fills).toList();
    c.loadLayout(others[0]);
    final first = solver.held.last;
    first.onStep(1, 8);
    expect(c.solveStep, (done: 1, of: 8));
    c.loadLayout(others[1]);
    expect(c.solveStep, isNull);
    first.onStep(2, 8); // the solve she left
    expect(c.solveStep, isNull);
    solver.held.last.onStep(1, 8);
    expect(c.solveStep, (done: 1, of: 8));
    solver.answerLast();
    await pumpEventQueue();
    expect(c.solving, isFalse);
    expect(c.solveStep, isNull);
    expect(c.layout, others[1]);
  });

  testWidgets('on the board: nothing for a quick solve; past a second the words; past 10 s the bar and Stop, which puts the '
      'board back', (tester) async {
    final solver = HeldSolver();
    final c = await pumpPhone(tester, solver: solver);
    final grid = c.grid, layout = c.layout;
    final note = find.byKey(const ValueKey('wait-note'));

    // Quick: answered inside the second.
    solver.hold = true;
    final others = layoutKeys.where((k) => k != layout && c.feasible[k]!.fills).toList();
    c.loadLayout(others[0]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(note, findsNothing);
    solver.answerLast();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(note, findsNothing);
    expect(c.layout, others[0]);

    // Slow: the words past a second, then, its first step at 2 s of 8, the bar and Stop.
    final before = c.grid;
    c.loadLayout(others[1]);
    await tester.pump(); // the note is built, and its clock starts
    await tester.pump(const Duration(milliseconds: 1000));
    expect(note, findsOneWidget);
    expect(find.text('Arranging the cloth…'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    solver.held.last.onStep(1, 8);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Tried 1 of 8 arrangements'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(note, findsNothing);
    expect(c.layout, others[0]);
    expect(c.grid, before);
    expect(c.solving, isFalse);
    expect(solver.stops, 1);
    expect(grid, isNot(before));
    await tester.pump(waitIsLong);
    expect(note, findsNothing);
  });
}
