import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import 'solver_runner_io.dart' if (dart.library.js_interop) 'solver_runner_web.dart' as impl;

/* The solver off the screen's thread: an isolate on a phone, a Web Worker in a
   browser, so the studio keeps answering while it works. */
abstract interface class SolverRunner {
  void setPool(Base base);
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed);
  void dispose();
}

/* A runner that also solves boards of other sizes (Level 2). Its own interface, so a runner made for
   Level 1 alone still is one. */
abstract interface class SizedSolverRunner implements SolverRunner {
  Future<LayoutSolve> solveOn(BoardSize size, LayoutKey layout, List<int> members, Mount mount, int seed);
}

SolverRunner createSolverRunner() => impl.create();
