/* Simulated annealing, then a polish to a local minimum. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'js_math.dart';
import 'score.dart';

export 'js_math.dart' show rng;

class SolveOptions {
  const SolveOptions({required this.seed, this.restarts = 4, this.steps = 20000, this.acceptStart = 0.8, this.tEnd = 1});
  final int seed, restarts, steps;
  final double acceptStart, tEnd;
}

class Solved {
  const Solved(this.grid, this.total, this.seed);
  final List<int> grid;
  final double total;
  final int seed;
}

double _total(List<int> g, Objective obj, Prepared prep) => score(g, obj, prep).total;

Int32List _counts(List<int> grid, int n) {
  final c = Int32List(n);
  for (final f in grid) { if (f >= 0 && f < n) c[f]++; } // an Int32Array ignores a write out of range
  return c;
}

List<int>? _generate(Objective obj, Prepared prep, List<int> stock, List<int> pool, double Function() rand) {
  final n = obj.rows * obj.cols;
  var have = 0;
  for (final f in pool) { have += stock[f]; }
  if (have < n) return null;
  final grid = List<int>.filled(n, -1);
  final used = Int32List(prep.n);
  final before = <int, List<int>>{};
  for (final (a, b) in obj.pairs) {
    final lo = a < b ? a : b, hi = a < b ? b : a;
    (before[hi] ??= <int>[]).add(lo);
  }
  for (var i = 0; i < n; i++) {
    final nbrs = [for (final j in before[i] ?? const <int>[]) grid[j]];
    var best = -1;
    var bestCost = double.infinity;
    for (final f in pool) {
      if (used[f] >= stock[f]) continue;
      var cost = rand() * 6;
      if (nbrs.contains(f)) cost += 1000;
      if (obj.targetL != null && obj.wL![i] > 0) {
        cost += (prep.l[f] - obj.targetL![i]).abs();
      } else {
        cost += rand() * 40;
      }
      for (final nb in nbrs) { cost += math.max(0.0, obj.weights.lTarget - prep.dl[f * prep.n + nb]); }
      if (cost < bestCost) { bestCost = cost; best = f; }
    }
    grid[i] = best;
    if (best >= 0) used[best]++; // as the TypeScript's Int32Array ignores used[-1]++
  }
  return grid;
}

List<int>? _propose(List<int> grid, Int32List used, List<int> stock, List<int> pool, double Function() rand) {
  final n = grid.length, next = List.of(grid);
  if (rand() < 0.6) {
    final a = (rand() * n).toInt(), b = (rand() * n).toInt();
    if (next[a] == next[b]) return null;
    final t = next[a]; next[a] = next[b]; next[b] = t;
  } else {
    final i = (rand() * n).toInt(), f = pool[(rand() * pool.length).toInt()];
    if (f == next[i] || used[f] >= stock[f]) return null;
    next[i] = f;
  }
  return next;
}

List<int> _anneal(List<int> start, Objective obj, Prepared prep, List<int> stock, List<int> pool,
    double Function() rand, int steps, double acceptStart, double tEnd) {
  var cur = List.of(start);
  var curScore = _total(cur, obj, prep);
  final used = _counts(cur, prep.n);

  var rise = 0.0;
  var seen = 0;
  for (var k = 0; k < 200; k++) {
    final p = _propose(cur, used, stock, pool, rand);
    if (p == null) continue;
    final d = _total(p, obj, prep) - curScore;
    if (d > 0) { rise += d; seen++; }
  }
  final t0 = math.max(tEnd, seen != 0 ? (rise / seen) / -math.log(acceptStart) : tEnd);

  var best = List.of(cur);
  var bestScore = curScore;
  for (var step = 0; step < steps; step++) {
    final t = t0 * math.pow(tEnd / t0, step / steps).toDouble();
    final next = _propose(cur, used, stock, pool, rand);
    if (next == null) continue;
    final s = _total(next, obj, prep);
    if (s <= curScore || rand() < math.exp((curScore - s) / t)) {
      for (var i = 0; i < cur.length; i++) { if (cur[i] != next[i]) { used[cur[i]]--; used[next[i]]++; } }
      cur = next;
      curScore = s;
      if (s < bestScore) { best = List.of(next); bestScore = s; }
    }
  }
  return best;
}

List<int> _polish(List<int> start, Objective obj, Prepared prep, List<int> stock, List<int> pool) {
  final grid = List.of(start), used = _counts(grid, prep.n);
  var cur = _total(grid, obj, prep);
  var improved = true;
  while (improved) {
    improved = false;
    for (var i = 0; i < grid.length; i++) {
      for (final f in pool) {
        final old = grid[i];
        if (f == old || used[f] >= stock[f]) continue;
        grid[i] = f;
        final s = _total(grid, obj, prep);
        if (s < cur - 1e-9) { cur = s; used[old]--; used[f]++; improved = true; } else { grid[i] = old; }
      }
    }
    for (var a = 0; a < grid.length; a++) {
      for (var b = a + 1; b < grid.length; b++) {
        if (grid[a] == grid[b]) continue;
        var t = grid[a]; grid[a] = grid[b]; grid[b] = t;
        final s = _total(grid, obj, prep);
        if (s < cur - 1e-9) { cur = s; improved = true; } else { t = grid[a]; grid[a] = grid[b]; grid[b] = t; }
      }
    }
  }
  return grid;
}

bool isLocalMinimum(List<int> grid, Objective obj, Prepared prep, List<int> stock, List<int> pool) {
  final before = _total(grid, obj, prep);
  return _total(_polish(grid, obj, prep, stock, pool), obj, prep) >= before - 1e-9;
}

bool withinStock(List<int> grid, List<int> stock) {
  final c = _counts(grid, stock.length);
  for (var f = 0; f < c.length; f++) { if (c[f] > stock[f]) return false; }
  return true;
}

Solved? solve(Objective obj, Prepared prep, List<int> stock, List<int> pool, SolveOptions opts) {
  final rand = rng(opts.seed);
  Solved? best;
  for (var k = 0; k < opts.restarts; k++) {
    final start = _generate(obj, prep, stock, pool, rand);
    if (start == null) return null;
    final grid = _polish(_anneal(start, obj, prep, stock, pool, rand, opts.steps, opts.acceptStart, opts.tEnd), obj, prep, stock, pool);
    final t = _total(grid, obj, prep);
    if (best == null || t < best.total) best = Solved(grid, t, opts.seed);
  }
  return best;
}

Uint8List orient(List<int> grid, Objective obj, Prepared prep) {
  final rot = Uint8List(grid.length);
  if (obj.targetOrient == null) return rot;
  for (var i = 0; i < grid.length; i++) {
    final f = grid[i];
    if (obj.wOrient![i] <= 0 || prep.coherence[f] <= 0) continue;
    final t = obj.targetOrient![i];
    if (orientGap(prep.grain[f] + 90, t) < orientGap(prep.grain[f], t)) rot[i] = 1;
  }
  return rot;
}
