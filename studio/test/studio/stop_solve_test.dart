import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/solver_runner.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/studio/phone/waiting.dart';
import '../support/pump.dart';
import '../support/studio_fixture.dart';

/* A solver that says its steps and can be stopped, and holds every solve while `hold` is set, until the test answers
   it or Stop stops it. Without `hold` it answers at once, as QuickSolver does, at any size. */
class HeldSolver extends QuickSolver implements SteppedSolverRunner {
  bool hold = false;
  int stops = 0;
  final held = <({Completer<LayoutSolve> done, void Function(int, int) onStep, LayoutSolve answer})>[];

  @override
  Future<LayoutSolve> solveOn(BoardSize size, LayoutKey layout, List<int> members, Mount mount, int seed) async =>
      _deal(size, members, seed);

  LayoutSolve _deal(BoardSize? size, List<int> members, int seed) {
    final n = size == null ? cells : size.rows * size.cols;
    calls++;
    return LayoutSolve(true, [for (var i = 0; i < n; i++) members[(i + seed) % members.length]],
        [for (var i = 0; i < n; i++) (i + seed) % 4]);
  }

  @override
  Future<LayoutSolve> solveStepped(BoardSize? size, LayoutKey layout, List<int> members, Mount mount, int seed,
      void Function(int done, int of) onStep) {
    final answer = _deal(size, members, seed);
    if (!hold) return Future.value(answer);
    final done = Completer<LayoutSolve>();
    held.add((done: done, onStep: onStep, answer: answer));
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

  test('a solve the press did not ask for (the first one) cannot be stopped; nor can one on a runner that cannot stop', () async {
    final solver = HeldSolver()..hold = true;
    final c = (await studio(solver: solver)).c;
    expect(c.solving, isTrue);
    expect(c.canStop, isFalse); // nothing to go back to
    c.stopSolve();
    expect(solver.stops, 0);

    final quick = (await studio()).c;
    quick.loadLayout(layoutKeys.firstWhere((k) => k != quick.layout && quick.feasible[k]!.fills));
    expect(quick.canStop, isFalse);
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
