import 'compile.dart';
import 'geometry.dart';
import 'layouts.dart';
import 'score.dart';
import 'solve.dart';

class Base {
  const Base(this.pool, this.edge, this.stock);
  final Pool pool;
  final List<double?> edge;
  final List<int> stock;
}

class LayoutSolve {
  const LayoutSolve(this.fills, this.grid, this.rot);
  final bool fills;
  final List<int>? grid, rot;
}

/* One template solved from a pool of cloth: the studio's solver runner and the
   start-page tool both come here, so a visitor sees what she would get. */
LayoutSolve solveLayout(LayoutKey key, Base base, List<int> members, Mount mount, int seed) {
  final m = modelFor(key, ObjectiveInput(pool: base.pool, edge: base.edge, members: members, mount: mount, stock: base.stock));
  final prep = prepare(m.pool, m.obj.distance);
  final solved = solve(m.obj, prep, base.stock, members, SolveOptions(seed: seed));
  return LayoutSolve(m.fills, solved?.grid, solved == null ? null : orient(solved.grid, m.obj, prep).toList());
}
