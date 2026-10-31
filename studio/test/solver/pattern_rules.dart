/* Does each pattern look like its name? (plan: pattern checks, owner 31 October 2026.) One rule or a few per pattern,
   each read from what the pattern's own objective asks for (layouts.dart, compile.dart), with its threshold written
   here before any run. Plus, for every pattern: no two edge-adjacent squares of one cloth, when the box holds at least
   [apartFrom] cloths. A random arrangement of the same pieces is scored by the same rules, as the baseline.

   No Flutter here: test/solver/pattern_checks_test.dart (the quick subset, every run) and tool/pattern_sweep.dart (every
   size, every box, the table) both use it. */
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:kantha_studio/data/numbers.dart' show busyOf, edgeOf;
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/hue.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/solve.dart';
import 'package:kantha_studio/solver/spec.dart';

// ---- The thresholds, fixed on 31 October 2026 before the first run. ----

/* A Spearman rank correlation this strong or stronger is "strong" by the usual convention (|ρ| ≥ 0.7). The patterns
   that set each square a lightness target (Gradient, Centre, Wave, Border, Cross, Ripple, Stripes, Zigzag, Chain,
   Diamond) need ρ(the square's lightness, its target) ≥ this; Spectrum needs it of hue against its hue target. Each ρ
   is taken as a share of the most a board could reach on that target ([relativeRho]). */
const double strongRho = 0.7;

/* The same patterns' second rule: the squares the target puts in its lightest third are lighter on average than the
   squares it puts in its darkest third, by at least this share of the gap the target itself asks for there, or of the
   most the box's pieces can give those squares if that is less (its lightest pieces in the one, its darkest in the
   other), as Chess and Mixed have from the start. (The piece cap was added after the first run of 31 October 2026:
   boxes with one or two pieces at each extreme failed on stock, not on the pattern.) */
const double separationShare = 0.5;

/* Chess and Mixed ask every seam for a lightness gap of the objective's lTarget (25 L*). A box that cannot give it
   everywhere is not the pattern's fault, so the median seam must reach the lesser of 25 and half of [splitContrast]
   (the most a board can get from its box: its lightest half of pieces against its darkest half). */
const double seamShare = 0.5;

/* Chess: the light and the dark squares keep to their own colour of the chessboard: of all seams, |light-on-even minus
   light-on-odd| / seams at least this. A true chessboard is 1; a random board is near 0. */
const double checkerConsistency = 0.8;

/* Blocks: the share of squares whose cloth is nearer (CIEDE2000 chroma distance) to its own block's colour than to any
   other block's. */
const double blockShare = 0.7;

/* Heart: the share of the heart's squares within the objective's deTarget (20) of the heart's colour, at least
   [heartShare]; the share of the ground's squares that close, at most [groundShare]; and the ground lighter than the
   heart on average by at least half the gap between the box's lightest cloth (the ground's target) and the heart's
   colour cloth. */
const double heartShare = 0.8, groundShare = 0.2, heartContrastShare = 0.5;

/* The no-same-neighbour rule applies when the box holds at least this many cloths. */
const int apartFrom = 6;

/* Ripple needs some spread of busy cloth to rank: at least this many distinct edge values among the box's cloth. */
const int rippleKinds = 3;

/* Spectrum ranks only coloured squares (chroma ≥ hueMinChroma); fewer than this and it says nothing. */
const int spectrumMinSquares = 6;

// ---- Statistics. ----

List<double> ranks(List<double> x) {
  final idx = [for (var i = 0; i < x.length; i++) i]..sort((a, b) => x[a].compareTo(x[b]));
  final r = List<double>.filled(x.length, 0);
  var i = 0;
  while (i < idx.length) {
    var j = i;
    while (j + 1 < idx.length && x[idx[j + 1]] == x[idx[i]]) { j++; }
    final avg = (i + j) / 2 + 1;
    for (var k = i; k <= j; k++) { r[idx[k]] = avg; }
    i = j + 1;
  }
  return r;
}

double pearson(List<double> x, List<double> y) {
  final n = x.length;
  final mx = x.reduce((a, b) => a + b) / n, my = y.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) * (x[i] - mx); syy += (y[i] - my) * (y[i] - my); }
  return sxx == 0 || syy == 0 ? double.nan : sxy / math.sqrt(sxx * syy);
}

/* Spearman's ρ with average ranks for ties; NaN when either side is constant. */
double spearman(List<double> x, List<double> y) => x.length < 3 ? double.nan : pearson(ranks(x), ranks(y));

/* The highest ρ any board could reach against target y: a lightness that follows y exactly, its ties broken. Below 1
   when y has ties (Border on 3 × 3: 8 ring squares tied, 1 middle, at most 0.55). */
double ceilingRho(List<double> y) {
  final order = [for (var i = 0; i < y.length; i++) i]..sort((a, b) { final c = y[a].compareTo(y[b]); return c != 0 ? c : a.compareTo(b); });
  final perfect = List<double>.filled(y.length, 0);
  for (var k = 0; k < order.length; k++) { perfect[order[k]] = k.toDouble(); }
  return spearman(perfect, y);
}

/* ρ as a share of [ceilingRho]: 1 is the best a board can do on that map. (Added after the first run of 31 October
   2026 showed raw ρ could not reach [strongRho] on tied maps even for a perfect board; the threshold is unchanged.) */
double relativeRho(List<double> x, List<double> y) => spearman(x, y) / ceilingRho(y);

double _mean(Iterable<double> v) => v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
double _median(List<double> v) { final s = List.of(v)..sort(); final n = s.length; return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2; }

/* Hue on Spectrum's own axis: its targets run 200° (cool) to 20° (warm); a hue is unwrapped about 290°, the angle
   opposite the middle of that run, so blues past 200 stay cool and magentas past 360 count as warmer than red. */
double spectrumAxis(double h) { final x = ((h % 360) + 360) % 360; return x > 290 ? x - 360 : x; }

// ---- The verdict on one board. ----

class Verdict {
  Verdict(this.applies, this.passes, this.stat, this.detail);
  /* False when the box gives the rule nothing to judge (Ripple with no busy spread, Spectrum with no colour). */
  final bool applies, passes;
  /* The rule's main statistic, for the margin over random (ρ, a share, a consistency). */
  final double stat;
  final String detail;
}

class Judged {
  Judged(this.rule, this.repeats, this.apartApplies);
  final Verdict rule;
  final int repeats;
  final bool apartApplies;
  bool get apart => repeats == 0;
}

/* The most a board of n squares can get from its pieces on Chess and Mixed: the mean lightness of the n/2 lightest
   pieces minus that of the n/2 darkest. */
double splitContrast(List<double> l, List<int> stock, List<int> members, int n) {
  final pieces = <double>[for (final i in members) for (var k = 0; k < stock[i]; k++) l[i]]..sort();
  final half = math.min(n ~/ 2, pieces.length ~/ 2);
  if (half == 0) return 0;
  return _mean(pieces.sublist(pieces.length - half)) - _mean(pieces.sublist(0, half));
}

Verdict _map(Compiled m, List<int> grid, List<int> stock, List<int> members) {
  final t = m.obj.targetL!, w = m.obj.wL!, l = m.pool.lightness;
  final idx = [for (var i = 0; i < grid.length; i++) if (w[i] > 0) i];
  final lt = [for (final i in idx) t[i]], ll = [for (final i in idx) l[grid[i]]];
  final rho = relativeRho(ll, lt);
  if (rho.isNaN) return Verdict(false, false, double.nan, 'no spread to rank');
  final lo = lt.reduce(math.min), hi = lt.reduce(math.max), span = hi - lo;
  final top = [for (var k = 0; k < idx.length; k++) if (lt[k] >= lo + 2 * span / 3 - 1e-9) k];
  final bottom = [for (var k = 0; k < idx.length; k++) if (lt[k] <= lo + span / 3 + 1e-9) k];
  final pieces = <double>[for (final i in members) for (var k = 0; k < stock[i]; k++) l[i]]..sort();
  final can = top.length + bottom.length > pieces.length ? double.infinity
      : _mean(pieces.sublist(pieces.length - top.length)) - _mean(pieces.sublist(0, bottom.length));
  final want = math.min(_mean(top.map((k) => lt[k])) - _mean(bottom.map((k) => lt[k])), can);
  final got = _mean(top.map((k) => ll[k])) - _mean(bottom.map((k) => ll[k]));
  final ok = rho >= strongRho && got >= separationShare * want;
  return Verdict(true, ok, rho, 'ρ ${rho.toStringAsFixed(2)}, separation ${got.toStringAsFixed(1)} of ${want.toStringAsFixed(1)}');
}

({double median, double checker}) _seams(Compiled m, List<int> grid) {
  final l = m.pool.lightness, cols = m.obj.cols;
  final gaps = <double>[];
  var pos = 0, neg = 0;
  for (final (a, b) in m.obj.pairs) {
    gaps.add((l[grid[a]] - l[grid[b]]).abs());
    final even = ((a ~/ cols) + (a % cols)).isEven ? a : b, odd = even == a ? b : a;
    final d = l[grid[even]] - l[grid[odd]];
    if (d > 0) { pos++; } else if (d < 0) { neg++; }
  }
  return (median: _median(gaps), checker: (pos - neg).abs() / m.obj.pairs.length);
}

Verdict _seamRule(Compiled m, List<int> grid, List<int> stock, List<int> members, {required bool chess}) {
  final s = _seams(m, grid);
  final need = math.min(m.obj.weights.lTarget, seamShare * splitContrast(m.pool.lightness, stock, members, grid.length));
  final seamOk = s.median >= need;
  final detail = 'median seam ${s.median.toStringAsFixed(1)} (needs ${need.toStringAsFixed(1)}), checker ${s.checker.toStringAsFixed(2)}';
  return chess
      ? Verdict(true, seamOk && s.checker >= checkerConsistency, s.checker, detail)
      : Verdict(true, seamOk, s.median - need, detail);
}

Verdict _spectrum(Compiled m, List<int> grid) {
  final t = m.obj.targetHue!, lab = m.pool.lab;
  final idx = [for (var i = 0; i < grid.length; i++) if (chroma(lab[grid[i]]) >= hueMinChroma) i];
  if (idx.length < spectrumMinSquares) return Verdict(false, false, double.nan, '${idx.length} coloured squares');
  final rho = relativeRho([for (final i in idx) spectrumAxis(hueOf(lab[grid[i]]))], [for (final i in idx) t[i]]);
  if (rho.isNaN) return Verdict(false, false, double.nan, 'no hue spread');
  return Verdict(true, rho >= strongRho, rho, 'ρ ${rho.toStringAsFixed(2)} over ${idx.length} coloured squares');
}

Verdict _blocks(Compiled m, List<int> grid) {
  final t = m.obj.targetColour!, lab = m.pool.lab;
  final targets = t.toSet().toList();
  var near = 0;
  for (var i = 0; i < grid.length; i++) {
    final own = chromaDistance(lab[grid[i]], lab[t[i]]);
    if (targets.every((q) => q == t[i] || own <= chromaDistance(lab[grid[i]], lab[q]))) near++;
  }
  final share = near / grid.length;
  return Verdict(true, share >= blockShare, share, '${(100 * share).round()}% nearest their own block’s colour');
}

Verdict _heart(Compiled m, List<int> grid, List<int> members, BoardSize g) {
  final zones = layouts[LayoutKey.heart]!.zonesOn(g), anchor = m.anchors[1]!, lab = m.pool.lab, l = m.pool.lightness;
  final heart = [for (var i = 0; i < grid.length; i++) if (zones[i] == 1) i];
  final ground = [for (var i = 0; i < grid.length; i++) if (zones[i] != 1) i];
  bool near(int i) => chromaDistance(lab[grid[i]], lab[anchor]) <= m.obj.weights.deTarget;
  final inHeart = heart.where(near).length / heart.length, inGround = ground.isEmpty ? 0.0 : ground.where(near).length / ground.length;
  final lmax = members.map((i) => l[i]).reduce(math.max);
  final contrast = _mean(ground.map((i) => l[grid[i]])) - _mean(heart.map((i) => l[grid[i]]));
  final want = heartContrastShare * (lmax - l[anchor]);
  final ok = inHeart >= heartShare && inGround <= groundShare && contrast >= want;
  return Verdict(true, ok, inHeart, 'heart ${(100 * inHeart).round()}% its colour, ground ${(100 * inGround).round()}%, '
      'ground lighter by ${contrast.toStringAsFixed(1)} (needs ${want.toStringAsFixed(1)})');
}

Verdict ruleFor(LayoutKey key, Compiled m, List<int> grid, List<int> stock, List<int> members, BoardSize g) {
  switch (key) {
    case LayoutKey.contrast: return _seamRule(m, grid, stock, members, chess: true);
    case LayoutKey.boro: return _seamRule(m, grid, stock, members, chess: false);
    case LayoutKey.spectrum: return _spectrum(m, grid);
    case LayoutKey.blocks: return _blocks(m, grid);
    case LayoutKey.heart: return _heart(m, grid, members, g);
    case LayoutKey.medallionPrint:
      final kinds = {for (final i in members) m.pool.lightness[i]}.length;
      if (kinds < rippleKinds) return Verdict(false, false, double.nan, '$kinds kinds of busy');
      return _map(m, grid, stock, members);
    default: return _map(m, grid, stock, members);
  }
}

int repeatsOf(List<int> grid, Objective obj) => obj.pairs.where((p) => grid[p.$1] == grid[p.$2]).length;

Judged judge(LayoutKey key, Compiled m, List<int> grid, List<int> stock, List<int> members, BoardSize g) =>
    Judged(ruleFor(key, m, grid, stock, members, g), repeatsOf(grid, m.obj), members.length >= apartFrom);

// ---- Boxes. ----

class Box {
  const Box(this.name, this.fabrics);
  final String name;
  final List<Fabric> fabrics;
  int get pieces => fabrics.fold(0, (a, f) => a + f.stock);

  /* The box with enough pieces for a board of n squares: each cloth's count times the least whole k that gives at least
     1.25 n pieces (k = 1 when the box already has them), so its proportions stay as they were. */
  ({Pool pool, List<double?> edge, List<int> stock, List<int> members}) forBoard(int n) {
    final k = math.max(1, (1.25 * n / pieces).ceil());
    final p = poolOf([for (final f in fabrics) Fabric(id: f.id, name: f.name, lab: f.lab, busy: f.busy, edge: f.edge,
        grain: f.grain, stock: f.stock * k)]);
    return (pool: p.pool, edge: p.edge, stock: p.stock, members: [for (var i = 0; i < fabrics.length; i++) i]);
  }
}

double _d(Object? v) => (v as num).toDouble();

/* The Sample box as a fresh install makes it: the ten photos in assets/sample/, measured by the studio's own measure,
   7 pieces each (lib/data/sample_box.dart). Run in studio/. */
Box sampleBox() {
  const files = ['red', 'navy', 'purple', 'turmeric', 'orange', 'dark-green', 'white', 'red-bandhani',
    'red-and-blue-block-print', 'teal-flower-print'];
  return Box('Sample', [
    for (final f in files)
      () {
        final m = measureBytes(File('assets/sample/$f.jpg').readAsBytesSync());
        return Fabric(id: f, name: f, lab: m.lab, busy: busyOf(m.spread), edge: edgeOf(m.spread), grain: null, stock: 7);
      }(),
  ]);
}

/* The 47 factory cloths of tool/start_cloth.json, as measured from their photos on 26 October 2026. */
List<Fabric> startCloth() {
  final cloth = ((jsonDecode(File('tool/start_cloth.json').readAsStringSync()) as Map<String, dynamic>)['cloth'] as List)
      .cast<Map<String, dynamic>>();
  return [
    for (final c in cloth)
      Fabric(id: c['id'] as String, name: c['name'] as String, lab: (l: _d(c['lab'][0]), a: _d(c['lab'][1]), b: _d(c['lab'][2])),
          busy: c['busy'] as bool?, edge: c['edge'] == null ? null : _d(c['edge']), grain: null, stock: math.max(1, c['pieces'] as int)),
  ];
}

/* The tuning pool of 11 September 2026 (test/fixtures/solver/pool-2026-09-11.json), with its own counts. */
Box tuningBox() {
  final m = jsonDecode(File('test/fixtures/solver/pool-2026-09-11.json').readAsStringSync()) as Map<String, dynamic>;
  final lab = m['lab'] as List;
  return Box('Tuning pool', [
    for (var i = 0; i < lab.length; i++)
      Fabric(id: '${m['ids'][i]}', name: '${m['ids'][i]}', lab: (l: _d(lab[i][0]), a: _d(lab[i][1]), b: _d(lab[i][2])),
          busy: (m['busy'] as List)[i] as bool, edge: (m['edge'] as List)[i] == null ? null : _d((m['edge'] as List)[i]),
          grain: null, stock: (m['stock'] as List)[i] as int),
  ]);
}

/* Boxes drawn from the 47 factory cloths, each with 2–8 pieces of a cloth, seeded so every run draws the same:
   any colour (6, 12 and 20 cloths), a narrow lightness spread (8 cloths, L* 40–65) and warm hues only (10 cloths,
   hue −60° to 90°). */
List<Box> drawnBoxes() {
  final all = startCloth();
  final r = math.Random(20261031);
  List<Fabric> draw(List<Fabric> from, int n) {
    final pick = List.of(from)..shuffle(r);
    return [for (final f in pick.take(n)) Fabric(id: f.id, name: f.name, lab: f.lab, busy: f.busy, edge: f.edge, grain: null,
        stock: 2 + r.nextInt(7))];
  }
  double h(Fabric f) { final x = hueOf(f.lab) % 360; return x > 180 ? x - 360 : x; }
  return [
    Box('Any 6', draw(all, 6)),
    Box('Any 12', draw(all, 12)),
    Box('Any 20', draw(all, 20)),
    Box('Narrow 8', draw([for (final f in all) if (f.lab.l >= 40 && f.lab.l <= 65) f], 8)),
    Box('Warm 10', draw([for (final f in all) if (chroma(f.lab) >= hueMinChroma && h(f) >= -60 && h(f) <= 90) f], 10)),
  ];
}

List<Box> allBoxes() => [sampleBox(), tuningBox(), Box('All 47', startCloth()), ...drawnBoxes()];

// ---- One case: a pattern, a box, a board, a seed. ----

class Case {
  Case(this.key, this.box, this.size, this.seed, this.fills, this.solved, this.random, this.grid, this.colours);
  final LayoutKey key;
  final String box;
  final BoardSize size;
  final int seed;
  /* False when the box cannot fill the pattern (the studio fades its tile); then nothing is judged. */
  final bool fills;
  final Judged? solved, random;
  final List<int>? grid;
  final List<Lab>? colours;
}

/* A random arrangement of the same pieces: n drawn without replacement from the box's pieces, in a random order. */
List<int> randomGrid(List<int> stock, List<int> members, int n, int seed) {
  final pieces = <int>[for (final i in members) for (var k = 0; k < stock[i]; k++) i]..shuffle(math.Random(seed));
  return pieces.take(n).toList();
}

Case runCase(LayoutKey key, Box box, BoardSize g, int seed) {
  final n = g.rows * g.cols, b = box.forBoard(n);
  final m = modelFor(key, ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock, size: g));
  if (!m.fills) return Case(key, box.name, g, seed, false, null, null, null, null);
  final prep = prepare(m.pool, m.obj.distance);
  final s = solve(m.obj, prep, b.stock, b.members, SolveOptions(seed: seed));
  if (s == null) return Case(key, box.name, g, seed, false, null, null, null, null);
  final rand = randomGrid(b.stock, b.members, n, seed * 7919 + n);
  return Case(key, box.name, g, seed, true, judge(key, m, s.grid, b.stock, b.members, g),
      judge(key, m, rand, b.stock, b.members, g), s.grid, b.pool.lab);
}

/* The studio's pattern names, for the table (messages/en.json's titles). */
const Map<LayoutKey, String> patternName = {
  LayoutKey.contrast: 'Chess', LayoutKey.gradient: 'Gradient', LayoutKey.medallion: 'Centre', LayoutKey.wave: 'Wave',
  LayoutKey.framed: 'Border', LayoutKey.cross: 'Cross', LayoutKey.spectrum: 'Spectrum', LayoutKey.boro: 'Mixed',
  LayoutKey.blocks: 'Blocks', LayoutKey.medallionPrint: 'Ripple', LayoutKey.heart: 'Heart', LayoutKey.stripes: 'Stripes',
  LayoutKey.zigzag: 'Zigzag', LayoutKey.chain: 'Chain', LayoutKey.diamond: 'Diamond',
};

/* A plain pattern's lightness target map (its LFromT) on a board, 0 the darkest. */
Float64List targetMap(LayoutKey key, BoardSize g) => fieldCells((layouts[key]!.rules[0]!.l! as LFromT).t, g);
