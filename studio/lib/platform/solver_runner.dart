import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import 'solver_runner_io.dart' if (dart.library.js_interop) 'solver_runner_web.dart' as impl;

/* The solver off the screen's thread: an isolate on a phone, a Web Worker in a browser, so the studio keeps answering
   while it works. It says how far a solve has got, each of the solver's starts as it ends, and can stop the solves it
   holds; a solve stopped answers no arrangement. A wait past 10 s shows a bar and Stop (owner, 1 November 2026). */
abstract interface class SolverRunner {
  void setPool(Base base);
  /* `size` null is Level 1's 5 × 7. */
  Future<LayoutSolve> solve(BoardSize? size, LayoutKey layout, List<int> members, Mount mount, int seed,
      {void Function(int done, int of)? onStep});
  void stop();
  void dispose();
}

SolverRunner createSolverRunner() => impl.create();
