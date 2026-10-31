import 'dart:isolate';
import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import 'solver_runner.dart';

SolverRunner create() => _IsolateRunner();

class _IsolateRunner implements SizedSolverRunner {
  Base? _base;
  @override
  void setPool(Base base) => _base = base;
  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) {
    final base = _base!;
    return Isolate.run(() => solveLayout(layout, base, members, mount, seed));
  }
  @override
  Future<LayoutSolve> solveOn(BoardSize size, LayoutKey layout, List<int> members, Mount mount, int seed) {
    final base = _base!;
    return Isolate.run(() => solveLayout(layout, base, members, mount, seed, size: size));
  }
  @override
  void dispose() {}
}
