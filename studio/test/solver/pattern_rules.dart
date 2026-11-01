/* Does each pattern look like its name? (plan: pattern checks, owner 31 October 2026; rewritten 1 November 2026 after an
   independent audit of the statistics.) One rule or a few per pattern, read from what the pattern is meant to look
   like, each threshold fixed here before any run. Plus, for every pattern: no two edge-adjacent squares of one cloth,
   when the box holds at least [apartFrom] cloths.

   Each case has one of three outcomes: it passes, it fails, or the box cannot make the pattern at all (the studio
   refuses to fill it, or no arrangement of the box's pieces could meet the rule: a bound from the pieces alone, worked
   out below rule by rule). The bar is never lowered to what a box can give.

   Two baselines are judged by the same rules: a random arrangement of the same pieces, and a sorted one (the pieces
   sorted by lightness, or hue, dealt in the pattern's target order, no search). The solver must beat both.

   No Flutter here: test/solver/pattern_checks_test.dart (the quick subset, every run) and tool/pattern_sweep.dart (every
   size, every box, the tables) both use it. */
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:kantha_studio/data/numbers.dart' show busyOf, edgeOf;
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/solver/cam16.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/hue.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/solve.dart';
import 'package:kantha_studio/solver/spec.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

// ---- The thresholds, fixed on 1 November 2026 before any run of these rules. ----

/* Somers' d of the squares' lightness given their target (Somers 1962): over every pair of squares the target puts at
   different levels, the share ordered as the target orders them minus the share ordered against it. Pairs the target
   ties are left out, so a board that follows its target exactly scores 1 whatever the target's ties; ties in lightness
   (two pieces of one cloth) count as neither. The bar, 0.5, is the Kendall-scale value of the usual "strong" Spearman
   correlation, 0.7: under a bivariate normal, Spearman 0.7 is Pearson 2 sin(0.7π/6) = 0.717 and Kendall
   (2/π) arcsin(0.717) = 0.51 (Greiner's relation). At d = 0.5, pairs in the target's order outnumber pairs against it
   three to one. */
const double minSomersD = 0.5;

/* The lightness patterns' second rule: the squares the target puts in its lightest third are lighter on average than
   those it puts in its darkest third, by at least this share of the gap the target itself asks for there. A design
   choice with no published source. */
const double separationShare = 0.5;

/* Chess and Mixed: the median seam's lightness gap, at least the objective's lTarget, 25 L*. A design choice with no
   published source (about a quarter of the L* scale). */
const double seamL = 25;

/* Chess: the light and the dark squares keep to their own colour of the chessboard: of all seams, |light-on-even minus
   light-on-odd| / seams at least this. A true chessboard is 1; a random board is near 0. A design choice. */
const double checkerConsistency = 0.8;

/* Blocks: the share of squares whose cloth is nearer (CAM16-UCS a′b′) to its own block's colour than to any other
   block's. Diamond: the share of each ring's squares that are one colour family. A design choice. */
const double blockShare = 0.7;

/* "That colour": within this CAM16-UCS a′b′ distance (ΔE′, lightness left out). 19.4 keeps, over the 90 cloths of the
   Sample box, the tuning pool and the 47 factory cloths (4,005 pairs), the same share of pairs "the same colour"
   (44.3%) as the CIEDE2000 hue-and-chroma distance of 20 it replaces; that 20 had no published source either. */
const double sameColour = 19.4;

/* Heart: at least heartShare (lib/solver/compile.dart, the solver's own, 0.8) of the heart's squares that colour, at
   most [groundShare] of the ground's, and the ground lighter than the heart on average by at least [seamL]. Design
   choices. */
const double groundShare = 0.2;

/* The no-same-neighbour rule applies when the box holds at least this many cloths. */
const int apartFrom = 6;

/* Ripple needs some spread of busy cloth to rank: at least this many distinct edge values among the box's cloth. */
const int rippleKinds = 3;

/* Spectrum ranks only coloured squares (CAM16 chroma ≥ minChroma, 11.5, a design choice); fewer than this and the
   box cannot make it. */
const int spectrumMinSquares = 6;

// ---- Statistics. ----

/* Somers' d of y given x (Somers 1962): (concordant − discordant) / pairs not tied on x. NaN when x is constant. */
double somersD(List<double> y, List<double> x) {
  var s = 0, untied = 0;
  for (var i = 0; i < x.length; i++) {
    for (var j = i + 1; j < x.length; j++) {
      final dx = x[j] - x[i];
      if (dx == 0) continue;
      untied++;
      final dy = y[j] - y[i];
      if (dy != 0) s += (dx > 0) == (dy > 0) ? 1 : -1;
    }
  }
  return untied == 0 ? double.nan : s / untied;
}

/* The highest Somers' d any arrangement of these pieces can reach against target x: two squares holding pieces of one
   lightness tie, and only pairs the target also ties can hide those ties. So d ≤ 1 − (ties the pieces force, less all
   the pairs the target ties) / pairs not tied on x, the forced ties being the fewest any choice of n of the pieces can
   make (spread as evenly as stock allows over the lightness values). */
double maxSomersD(List<double> x, Map<double, int> piecesByValue) {
  final n = x.length;
  final caps = piecesByValue.values.toList()..sort();
  final take = List<int>.filled(caps.length, 0);
  var left = n;
  for (var k = 0; k < caps.length; k++) {
    final even = (left / (caps.length - k)).floor();
    take[k] = math.min(caps[k], even);
    left -= take[k];
  }
  // whatever the even split could not place goes on the largest stocks, one at a time
  for (var k = caps.length - 1; k >= 0 && left > 0; k--) {
    final more = math.min(caps[k] - take[k], left);
    take[k] += more;
    left -= more;
  }
  if (left > 0) return double.nan;
  int c2(int k) => k * (k - 1) ~/ 2;
  final forced = take.fold(0, (a, k) => a + c2(k));
  final groups = <double, int>{};
  for (final v in x) { groups[v] = (groups[v] ?? 0) + 1; }
  final xTied = groups.values.fold(0, (a, k) => a + c2(k));
  final untied = c2(n) - xTied;
  if (untied == 0) return double.nan;
  return 1 - math.max(0, forced - xTied) / untied;
}

/* Spearman's ρ with average ranks for ties, for comparing two target maps (Diamond against Centre). */
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

double spearman(List<double> x, List<double> y) => x.length < 3 ? double.nan : pearson(ranks(x), ranks(y));

/* The Wilson score interval for k successes in n (Brown, Cai and DasGupta 2001), at 95% (z = 1.96). */
({double lo, double hi}) wilson(int k, int n, [double z = 1.96]) {
  if (n == 0) return (lo: double.nan, hi: double.nan);
  final p = k / n, z2 = z * z, den = 1 + z2 / n;
  final mid = (p + z2 / (2 * n)) / den, half = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / den;
  return (lo: math.max(0, mid - half), hi: math.min(1, mid + half));
}

double _mean(Iterable<double> v) => v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;
double _median(List<double> v) { final s = List.of(v)..sort(); final n = s.length; return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2; }

/* The check's own hue measure, coded apart from the solver's: CAM16 hue (Li et al. 2017) straight from
   material_color_utilities, on a line cut where Spectrum is defined to cut it: in the purples, the arc no wavelength
   makes (from the spectrum locus's 380 nm end at 331.8° round through 0° to its 700 nm end at 19.3°), at the middle
   of the widest stretch of that arc holding none of the box's own coloured hues. Higher is cooler. */
double camHue(Lab lab) {
  final wp = ColorUtils.whitePointD65();
  final fy = (lab.l + 16) / 116;
  return Cam16.fromXyzInViewingConditions(wp[0] * _finv(fy + lab.a / 500), wp[1] * _finv(fy),
      wp[2] * _finv(fy - lab.b / 200), ViewingConditions.sRgb).hue;
}
double _finv(double t) => t > 6 / 29 ? t * t * t : 3 * (6 / 29) * (6 / 29) * (t - 4 / 29);
double checkCut(List<double> hues) {
  const from = 331.8, to = 379.3;
  final inside = [for (final h in hues) h < from ? h + 360 : h].where((h) => h > from && h < to).toList()..sort();
  var at = (from + to) / 2, wide = -1.0, prev = from;
  for (final h in [...inside, to]) {
    if (h - prev > wide) { wide = h - prev; at = (h + prev) / 2; }
    prev = h;
  }
  return at >= 360 ? at - 360 : at;
}
double onCheckLine(double h, double cut) => h > cut ? h - 360 : h;

double ab(Lab p, Lab q) => chromaUcs(ucsOf(p), ucsOf(q));

// ---- Bounds from the box's own pieces. ----

/* The most squares of `region` one cloth can take with none of them beside another (the no-same-neighbour rule): an
   independent set of the region's neighbour pairs, so at most the region's size less a largest matching of them (each
   matched pair holds at most one square of the set). The matching is over the orthogonal pairs alone, a bipartite
   graph, by Kuhn's augmenting paths; a matching of fewer pairs only loosens the bound. */
int apartCap(List<int> region, Objective obj) {
  final inRegion = region.toSet(), cols = obj.cols;
  final next = <int, List<int>>{};
  for (final (a, b) in obj.pairs) {
    if (!inRegion.contains(a) || !inRegion.contains(b)) continue;
    if ((a ~/ cols - b ~/ cols).abs() + (a % cols - b % cols).abs() != 1) continue;
    final even = ((a ~/ cols) + (a % cols)).isEven ? a : b, odd = even == a ? b : a;
    (next[even] ??= []).add(odd);
  }
  final partner = <int, int>{};
  bool augment(int u, Set<int> seen) {
    for (final v in next[u] ?? const <int>[]) {
      if (!seen.add(v)) continue;
      final w = partner[v];
      if (w == null || augment(w, seen)) { partner[v] = u; return true; }
    }
    return false;
  }
  var matched = 0;
  for (final u in next.keys) { if (augment(u, <int>{})) matched++; }
  return region.length - matched;
}

// ---- The verdict on one board. ----

enum Outcome { pass, fail, cannot }

class Verdict {
  Verdict(this.outcome, this.stat, this.detail);
  final Outcome outcome;
  /* The rule's main statistic (Somers' d, a share, a consistency, a seam gap). */
  final double stat;
  final String detail;
  bool get passes => outcome == Outcome.pass;
}

Verdict _cannot(String why) => Verdict(Outcome.cannot, double.nan, why);

class Judged {
  Judged(this.rule, this.repeats, this.apartApplies);
  final Verdict rule;
  final int repeats;
  final bool apartApplies;
  bool get apart => repeats == 0;
}

/* The pieces of a box, one entry per piece. */
List<int> piecesOf(List<int> stock, List<int> members) => [for (final i in members) for (var k = 0; k < stock[i]; k++) i];

Map<double, int> _byValue(List<double> v, List<int> stock, List<int> members) {
  final out = <double, int>{};
  for (final i in members) { if (stock[i] > 0) out[v[i]] = (out[v[i]] ?? 0) + stock[i]; }
  return out;
}

/* A lightness pattern: Somers' d of lightness given the target, and the light-third-against-dark-third separation. */
Verdict _map(Compiled m, List<int> grid, List<int> stock, List<int> members, {bool apart = false}) {
  final t = m.obj.targetL!, w = m.obj.wL!, l = m.pool.lightness;
  final idx = [for (var i = 0; i < grid.length; i++) if (w[i] > 0) i];
  final lt = [for (final i in idx) t[i]], ll = [for (final i in idx) l[grid[i]]];
  final lo = lt.reduce(math.min), hi = lt.reduce(math.max), span = hi - lo;
  if (span == 0) return _cannot('the box has one lightness');
  final top = [for (var k = 0; k < idx.length; k++) if (lt[k] >= lo + 2 * span / 3 - 1e-9) k];
  final bottom = [for (var k = 0; k < idx.length; k++) if (lt[k] <= lo + span / 3 + 1e-9) k];
  final want = _mean(top.map((k) => lt[k])) - _mean(bottom.map((k) => lt[k]));
  // The bound: the lightest pieces in the top third, the darkest in the bottom.
  final pieces = [for (final i in piecesOf(stock, members)) l[i]]..sort();
  final can = top.length + bottom.length > pieces.length ? double.negativeInfinity
      : _mean(pieces.sublist(pieces.length - top.length)) - _mean(pieces.sublist(0, bottom.length));
  final maxD = maxSomersD(lt, _byValue(l, stock, members));
  if (can < separationShare * want) {
    return _cannot('at most ${can.toStringAsFixed(1)} of separation from its pieces, needs ${(separationShare * want).toStringAsFixed(1)}');
  }
  // With the no-same-neighbour rule, a cloth takes at most an independent set of each third.
  if (apart) {
    final topSquares = [for (final k in top) idx[k]], bottomSquares = [for (final k in bottom) idx[k]];
    final hiMean = extremeMean(l, stock, members, top.length, darkest: false, cap: apartCap(topSquares, m.obj));
    final loMean = extremeMean(l, stock, members, bottom.length, darkest: true, cap: apartCap(bottomSquares, m.obj));
    final apartCan = hiMean == null || loMean == null ? double.negativeInfinity : hiMean - loMean;
    if (apartCan < separationShare * want) {
      return _cannot('at most ${apartCan.toStringAsFixed(1)} of separation with no cloth beside itself, needs '
          '${(separationShare * want).toStringAsFixed(1)}');
    }
  }
  if (maxD < minSomersD) return _cannot('at most d ${maxD.toStringAsFixed(2)} from its pieces');
  final d = somersD(ll, lt);
  final got = _mean(top.map((k) => ll[k])) - _mean(bottom.map((k) => ll[k]));
  final ok = d >= minSomersD && got >= separationShare * want;
  return Verdict(ok ? Outcome.pass : Outcome.fail, d,
      'd ${d.toStringAsFixed(2)}, separation ${got.toStringAsFixed(1)} of ${want.toStringAsFixed(1)}');
}

/* Chess and Mixed. The bound: a seam reaches [seamL] only between two pieces that far apart in lightness, so a square
   whose cloth has no such partner in the box spoils every seam it touches, at least one each; if those squares must
   be more than half the seams, the median cannot reach it. */
Verdict _seamRule(Compiled m, List<int> grid, List<int> stock, List<int> members, {required bool chess}) {
  final l = m.pool.lightness, cols = m.obj.cols, pairs = m.obj.pairs;
  final partnered = [for (final i in members) if (stock[i] > 0 && members.any((j) => stock[j] > 0 && (l[i] - l[j]).abs() >= seamL)) i];
  final open = partnered.fold(0, (a, i) => a + stock[i]);
  final lonely = math.max(0, grid.length - open);
  if (lonely > pairs.length / 2) return _cannot('$lonely squares must take cloth with no partner ${seamL.round()} L* away');
  // The median reaches seamL only if half the seams do. A seam that far apart has, for any lightness t, an end below t
  // or an end at least t + seamL (if its darker end is not below t, its lighter end is at least t + seamL). So the
  // squares holding those pieces touch every such seam, and those seams number at most the seams of that many
  // squares, the best-placed ones counted; the bound is the least over t.
  final degree = List<int>.filled(grid.length, 0);
  for (final (a, b) in pairs) { degree[a]++; degree[b]++; }
  degree.sort((a, b) => b.compareTo(a));
  final have = [for (final i in members) if (stock[i] > 0) i];
  var most = pairs.length;
  for (final t in [for (final i in have) ...[l[i], l[i] - seamL + 1e-9]]) {
    final k = math.min(grid.length, have.where((i) => l[i] < t || l[i] >= t + seamL).fold(0, (a, i) => a + stock[i]));
    most = math.min(most, degree.take(k).fold(0, (a, b) => a + b));
  }
  final need = (pairs.length / 2).ceil();
  if (most < need) return _cannot('at most $most seams ${seamL.round()} L* apart from its pieces, needs $need');
  final gaps = <double>[];
  var pos = 0, neg = 0;
  for (final (a, b) in pairs) {
    gaps.add((l[grid[a]] - l[grid[b]]).abs());
    final even = ((a ~/ cols) + (a % cols)).isEven ? a : b, odd = even == a ? b : a;
    final d = l[grid[even]] - l[grid[odd]];
    if (d > 0) { pos++; } else if (d < 0) { neg++; }
  }
  final median = _median(gaps), checker = (pos - neg).abs() / pairs.length;
  final detail = 'median seam ${median.toStringAsFixed(1)} (needs ${seamL.round()}), checker ${checker.toStringAsFixed(2)}';
  final ok = median >= seamL && (!chess || checker >= checkerConsistency);
  return Verdict(ok ? Outcome.pass : Outcome.fail, chess ? checker : median, detail);
}

/* Spectrum: cool on the left to warm on the right. Somers' d of the coloured squares' warmth (lower on the check's hue
   line) given their column. */
Verdict _spectrum(Compiled m, List<int> grid, List<int> stock, List<int> members) {
  final lab = m.pool.lab, cols = m.obj.cols;
  bool coloured(int f) => ucsOf(lab[f]).c >= minChroma;
  final colouredPieces = members.where(coloured).fold(0, (a, i) => a + stock[i]);
  if (colouredPieces < spectrumMinSquares) return _cannot('$colouredPieces coloured pieces');
  final hues = {for (final i in members) if (coloured(i)) i: camHue(lab[i])};
  if (hues.values.toSet().length < 2) return _cannot('one hue');
  final cut = checkCut(hues.values.toList());
  final idx = [for (var i = 0; i < grid.length; i++) if (coloured(grid[i])) i];
  if (idx.length < spectrumMinSquares) {
    return Verdict(Outcome.fail, double.nan, '${idx.length} coloured squares');
  }
  final d = somersD([for (final i in idx) -onCheckLine(hues[grid[i]]!, cut)], [for (final i in idx) (i % cols).toDouble()]);
  return Verdict(d >= minSomersD ? Outcome.pass : Outcome.fail, d, 'd ${d.toStringAsFixed(2)} over ${idx.length} coloured squares');
}

/* Blocks. The bound: each block can hold at most as many squares nearest its colour as there are pieces nearest it. */
Verdict _blocks(Compiled m, List<int> grid, List<int> stock, List<int> members) {
  final t = m.obj.targetColour!, lab = m.pool.lab;
  final targets = t.toSet().toList();
  bool nearest(int f, int q) { final own = ab(lab[f], lab[q]); return targets.every((o) => o == q || own <= ab(lab[f], lab[o])); }
  var reach = 0;
  for (final q in targets) {
    final squares = [for (final v in t) if (v == q) v].length;
    reach += math.min(squares, members.where((f) => nearest(f, q)).fold(0, (a, f) => a + stock[f]));
  }
  if (reach / grid.length < blockShare) return _cannot('at most ${(100 * reach / grid.length).round()}% from its pieces');
  var near = 0;
  for (var i = 0; i < grid.length; i++) { if (nearest(grid[i], t[i])) near++; }
  final share = near / grid.length;
  return Verdict(share >= blockShare ? Outcome.pass : Outcome.fail, share, '${(100 * share).round()}% nearest their own block’s colour');
}

/* Heart. The bounds: enough pieces of the heart's colour for the heart, enough of other colours for the ground, and
   the ground's lightest pieces against the heart's darkest at least [seamL] apart. */
Verdict _heart(Compiled m, List<int> grid, List<int> stock, List<int> members, BoardSize g) {
  final zones = layouts[LayoutKey.heart]!.zonesOn(g), anchor = m.anchors[1]!, lab = m.pool.lab, l = m.pool.lightness;
  final heart = [for (var i = 0; i < grid.length; i++) if (zones[i] == 1) i];
  final ground = [for (var i = 0; i < grid.length; i++) if (zones[i] != 1) i];
  bool near(int f) => ab(lab[f], lab[anchor]) <= sameColour;
  final nearPieces = members.where(near).fold(0, (a, f) => a + stock[f]);
  final farPieces = members.where((f) => !near(f)).fold(0, (a, f) => a + stock[f]);
  if (nearPieces < (heartShare * heart.length).ceil()) return _cannot('$nearPieces pieces of the heart’s colour for ${heart.length} squares');
  if (farPieces < ((1 - groundShare) * ground.length).ceil()) return _cannot('$farPieces pieces of other colours for ${ground.length} squares');
  final pieces = [for (final i in piecesOf(stock, members)) l[i]]..sort();
  final can = _mean(pieces.sublist(pieces.length - ground.length)) - _mean(pieces.sublist(0, heart.length));
  if (can < seamL) return _cannot('at most ${can.toStringAsFixed(1)} L* between ground and heart');
  // The same, with the heart's share of its colour and the ground's share of others, each cloth at most an
  // independent set of its zone where the no-same-neighbour rule applies.
  final apart = members.length >= apartFrom;
  final heartLeast = extremeMean(l, stock, members, heart.length, darkest: true, need: (heartShare * heart.length).ceil(),
      first: near, cap: apart ? apartCap(heart, m.obj) : null);
  final groundMost = extremeMean(l, stock, members, ground.length, darkest: false,
      need: ((1 - groundShare) * ground.length).ceil(), first: (f) => !near(f), cap: apart ? apartCap(ground, m.obj) : null);
  if (heartLeast == null || groundMost == null) return _cannot('its pieces cannot fill the heart and the ground with no cloth beside itself');
  if (groundMost - heartLeast < seamL) {
    return _cannot('at most ${(groundMost - heartLeast).toStringAsFixed(1)} L* between ground and heart with the colours '
        'and no cloth beside itself');
  }
  final inHeart = heart.where((i) => near(grid[i])).length / heart.length;
  final inGround = ground.isEmpty ? 0.0 : ground.where((i) => near(grid[i])).length / ground.length;
  final contrast = _mean(ground.map((i) => l[grid[i]])) - _mean(heart.map((i) => l[grid[i]]));
  final ok = inHeart >= heartShare && inGround <= groundShare && contrast >= seamL;
  return Verdict(ok ? Outcome.pass : Outcome.fail, inHeart, 'heart ${(100 * inHeart).round()}% its colour, ground '
      '${(100 * inGround).round()}%, ground lighter by ${contrast.toStringAsFixed(1)} (needs ${seamL.round()})');
}

/* The Single Irish Chain's links: the squares its own target makes darkest. Every one of them one cloth (owner,
   1 November 2026). The bound: a cloth with a piece for every link. */
Verdict _chain(Compiled m, List<int> grid, List<int> stock, List<int> members, BoardSize g) {
  final t = targetMap(LayoutKey.chain, g);
  final links = [for (var i = 0; i < grid.length; i++) if (t[i] == 0) i];
  if (!members.any((f) => stock[f] >= links.length)) return _cannot('no cloth has ${links.length} pieces for the links');
  // The separation, with the links one cloth: that cloth's lightness under the ground's, the ground from the pieces
  // left, each cloth of it at most an independent set of the ground under the no-same-neighbour rule; the best cloth.
  final l = m.pool.lightness, tl = m.obj.targetL!;
  final ground = [for (var i = 0; i < grid.length; i++) if (t[i] != 0) i];
  if (links.isNotEmpty && ground.isNotEmpty) {
    final want = _mean(ground.map((i) => tl[i])) - _mean(links.map((i) => tl[i]));
    final cap = members.length >= apartFrom ? apartCap(ground, m.obj) : null;
    var best = double.negativeInfinity;
    for (final c in members.where((f) => stock[f] >= links.length)) {
      final left = [for (final f in members) f == c ? stock[f] - links.length : stock[f]];
      final hi = extremeMean(l, [for (var f = 0; f < stock.length; f++) members.contains(f) ? left[members.indexOf(f)] : 0],
          members, ground.length, darkest: false, cap: cap);
      if (hi != null) best = math.max(best, hi - l[c]);
    }
    if (best < separationShare * want) {
      return _cannot('at most ${best.toStringAsFixed(1)} of separation with the links one cloth, needs '
          '${(separationShare * want).toStringAsFixed(1)}');
    }
  }
  final v = _map(m, grid, stock, members);
  if (v.outcome == Outcome.cannot) return v;
  final kinds = {for (final i in links) grid[i]}.length;
  return Verdict(v.passes && kinds == 1 ? Outcome.pass : Outcome.fail, v.stat, '${v.detail}, links of $kinds cloth');
}

/* Diamond as Sunshine and Shadow (owner, 1 November 2026): each ring one colour family, dark, middle and light outward,
   each family one colour at one lightness (grouped by CAM16-UCS ΔE′, J′a′b′). A ring is one family when at least
   [blockShare] of its squares are nearer (ΔE′) to its own family's colour than to any other family's; every ring
   must be. The lightness order is [_map]'s. A Diamond with no family per ring (before 1 November 2026) fails. The
   bound: as Blocks', over the rings. */
Verdict _diamond(Compiled m, List<int> grid, List<int> stock, List<int> members, BoardSize g) {
  final t = m.obj.targetColour, lab = m.pool.lab;
  final v = _map(m, grid, stock, members, apart: members.length >= apartFrom);
  if (v.outcome == Outcome.cannot) return v;
  if (t == null) return Verdict(Outcome.fail, 0, '${v.detail}, no colour family per ring');
  final targets = t.toSet().toList();
  double de(int p, int q) => deUcs(ucsOf(lab[p]), ucsOf(lab[q]));
  bool nearest(int f, int q) { final own = de(f, q); return targets.every((o) => o == q || own <= de(f, o)); }
  final cr = (g.rows - 1) / 2, cc = (g.cols - 1) / 2;
  int ringOf(int i) => (i ~/ g.cols - cr).abs().floor() + (i % g.cols - cc).abs().floor();
  final rings = <int, List<int>>{};
  for (var i = 0; i < grid.length; i++) { (rings[ringOf(i)] ??= []).add(i); }
  for (final q in targets) {
    final squares = [for (final x in t) if (x == q) x].length;
    final have = members.where((f) => nearest(f, q)).fold(0, (a, f) => a + stock[f]);
    if (have < blockShare * squares) return _cannot('$have pieces nearest a family that rings of $squares squares need');
  }
  var worst = 1.0;
  for (final ring in rings.values) {
    worst = [worst, ring.where((i) => nearest(grid[i], t[i])).length / ring.length].reduce((a, b) => a < b ? a : b);
  }
  final ok = v.passes && worst >= blockShare;
  return Verdict(ok ? Outcome.pass : Outcome.fail, worst, '${v.detail}, least one-family ring ${(100 * worst).round()}%');
}

Verdict ruleFor(LayoutKey key, Compiled m, List<int> grid, List<int> stock, List<int> members, BoardSize g) {
  switch (key) {
    case LayoutKey.contrast: return _seamRule(m, grid, stock, members, chess: true);
    case LayoutKey.boro: return _seamRule(m, grid, stock, members, chess: false);
    case LayoutKey.spectrum: return _spectrum(m, grid, stock, members);
    case LayoutKey.blocks: return _blocks(m, grid, stock, members);
    case LayoutKey.heart: return _heart(m, grid, stock, members, g);
    case LayoutKey.chain: return _chain(m, grid, stock, members, g);
    case LayoutKey.diamond: return _diamond(m, grid, stock, members, g);
    case LayoutKey.medallionPrint:
      final kinds = {for (final i in members) m.pool.lightness[i]}.length;
      if (kinds < rippleKinds) return _cannot('$kinds kinds of busy');
      return _map(m, grid, stock, members, apart: members.length >= apartFrom);
    default: return _map(m, grid, stock, members, apart: members.length >= apartFrom);
  }
}

int repeatsOf(List<int> grid, Objective obj) => obj.pairs.where((p) => grid[p.$1] == grid[p.$2]).length;

Judged judge(LayoutKey key, Compiled m, List<int> grid, List<int> stock, List<int> members, BoardSize g) =>
    Judged(ruleFor(key, m, grid, stock, members, g), repeatsOf(grid, m.obj), members.length >= apartFrom);

// ---- The two baselines. ----

/* A random arrangement of the same pieces: n drawn without replacement from the box's pieces, in a random order. */
List<int> randomGrid(List<int> stock, List<int> members, int n, int seed) {
  final pieces = piecesOf(stock, members)..shuffle(math.Random(seed));
  return pieces.take(n).toList();
}

/* n of the pieces, ordered by `key`, spread evenly over that order (its two ends included). */
List<int> _spread(List<int> pieces, double Function(int f) key, int n) {
  final s = List.of(pieces)..sort((a, b) { final c = key(a).compareTo(key(b)); return c != 0 ? c : a.compareTo(b); });
  if (n == 1) return [s.first];
  return [for (var k = 0; k < n; k++) s[(k * (s.length - 1) / (n - 1)).round()]];
}

List<int> _deal(List<double> target, List<int> chosen) {
  final order = [for (var i = 0; i < target.length; i++) i]
    ..sort((a, b) { final c = target[a].compareTo(target[b]); return c != 0 ? c : a.compareTo(b); });
  final grid = List<int>.filled(target.length, -1);
  for (var k = 0; k < order.length; k++) { grid[order[k]] = chosen[k]; }
  return grid;
}

/* The sorted baseline: no search. A lightness pattern takes n pieces spread evenly over the box's lightness and deals
   them in its target's order (lightest piece to the lightest target); Spectrum does the same with the solver's own hue
   targets on a CAM16 hue line; Blocks gives each square, block by block, the piece left that is nearest its block's
   colour; Heart gives the heart the pieces nearest its colour and the ground the lightest of the rest. Mixed has no
   order to follow and no sorted baseline (null). */
List<int>? sortedGrid(LayoutKey key, Compiled m, List<int> stock, List<int> members) {
  final n = m.obj.rows * m.obj.cols, pieces = piecesOf(stock, members), lab = m.pool.lab, l = m.pool.lightness;
  if (pieces.length < n) return null;
  switch (key) {
    case LayoutKey.boro:
      return null;
    case LayoutKey.spectrum:
      final cut = purpleCut([for (final f in members) if (coloured(lab[f])) ucsOf(lab[f]).hue]);
      double line(int f) => !coloured(lab[f]) ? 1e9 : hueOnLine(ucsOf(lab[f]).hue, cut);
      return _deal(m.obj.targetHue!, _spread(pieces, line, n));
    case LayoutKey.blocks:
      final t = m.obj.targetColour!, left = List.of(pieces), grid = List<int>.filled(n, -1);
      for (var i = 0; i < n; i++) {
        left.sort((a, b) => ab(lab[a], lab[t[i]]).compareTo(ab(lab[b], lab[t[i]])));
        grid[i] = left.removeAt(0);
      }
      return grid;
    case LayoutKey.heart:
      final anchor = m.anchors[1]!, zones = layouts[LayoutKey.heart]!.zonesOn((rows: m.obj.rows, cols: m.obj.cols));
      final left = List.of(pieces)..sort((a, b) => ab(lab[a], lab[anchor]).compareTo(ab(lab[b], lab[anchor])));
      final grid = List<int>.filled(n, -1);
      for (var i = 0; i < n; i++) { if (zones[i] == 1) grid[i] = left.removeAt(0); }
      left.sort((a, b) => l[b].compareTo(l[a]));
      for (var i = 0; i < n; i++) { if (zones[i] != 1) grid[i] = left.removeAt(0); }
      return grid;
    default:
      return _deal(m.obj.targetL!, _spread(pieces, (f) => l[f], n));
  }
}

// ---- Boxes. ----

class Box {
  const Box(this.name, this.fabrics, {this.heldOut = false});
  final String name;
  final List<Fabric> fabrics;
  /* Never tuned on (see [heldOutBoxes]). */
  final bool heldOut;
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

/* The Sample box's pieces per cloth, as lib/data/sample_box.dart gives them (that file imports Flutter, so they are
   copied here; sample_box_test.dart holds the two equal). */
const List<int> samplePiecesHere = [12, 12, 12, 12, 12, 12, 12, 12, 12, 12];

const sampleFiles = ['red', 'navy', 'purple', 'turmeric', 'orange', 'dark-green', 'white', 'red-bandhani',
  'red-and-blue-block-print', 'teal-flower-print'];

/* The Sample box as a fresh install makes it: the ten photos in assets/sample/, measured by the studio's own measure,
   with [samplePiecesHere] pieces (lib/data/sample_box.dart). Run in studio/. */
Box sampleBox([List<int> pieces = samplePiecesHere]) => Box('Sample', [
      for (var k = 0; k < sampleFiles.length; k++)
        () {
          final m = measureBytes(File('assets/sample/${sampleFiles[k]}.jpg').readAsBytesSync());
          return Fabric(id: sampleFiles[k], name: sampleFiles[k], lab: m.lab, busy: busyOf(m.spread), edge: edgeOf(m.spread),
              grain: null, stock: pieces[k]);
        }(),
    ]);

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

double _hue180(Fabric f) { final x = hueOf(f.lab) % 360; return x > 180 ? x - 360 : x; }

List<Fabric> Function(List<Fabric>, int) _drawer(int seed) {
  final r = math.Random(seed);
  return (from, n) {
    final pick = List.of(from)..shuffle(r);
    return [for (final f in pick.take(n)) Fabric(id: f.id, name: f.name, lab: f.lab, busy: f.busy, edge: f.edge, grain: null,
        stock: 2 + r.nextInt(7))];
  };
}

/* Boxes drawn from the 47 factory cloths, each with 2–8 pieces of a cloth, seeded so every run draws the same:
   any colour (6, 12 and 20 cloths), a narrow lightness spread (8 cloths, L* 40–65) and warm hues only (10 cloths,
   hue −60° to 90°). All five were swept while tuning on 1 November 2026. */
List<Box> drawnBoxes() {
  final all = startCloth(), draw = _drawer(20261031);
  return [
    Box('Any 6', draw(all, 6)),
    Box('Any 12', draw(all, 12)),
    Box('Any 20', draw(all, 20)),
    Box('Narrow 8', draw([for (final f in all) if (f.lab.l >= 40 && f.lab.l <= 65) f], 8)),
    Box('Warm 10', draw([for (final f in all) if (chroma(f.lab) >= 10 && _hue180(f) >= -60 && _hue180(f) <= 90) f], 10)),
  ];
}

/* The held-out boxes, fixed on 1 November 2026 before any tuning of the audit's fixes and never tuned on: four boxes
   drawn afresh (seed 20261102, used nowhere else) from the 47 factory cloths, at every board size. Any 8 and Any 16
   (any colour), Mid 10 (L* 30–75) and Cool 10 (hue 120° to 300°, chroma 10 or more). The cloths themselves are not
   new: the 47 were in the tuning boxes too, so these test new boxes of known cloth, not new cloth. The 11 September
   2026 tuning (~/kantha canvas/reports/sweep-2026-09-11.md) used only the tuning pool at 5 × 7. */
List<Box> heldOutBoxes() {
  final all = startCloth(), draw = _drawer(20261102);
  double h360(Fabric f) => ((hueOf(f.lab) % 360) + 360) % 360;
  return [
    Box('Held Any 8', draw(all, 8), heldOut: true),
    Box('Held Any 16', draw(all, 16), heldOut: true),
    Box('Held Mid 10', draw([for (final f in all) if (f.lab.l >= 30 && f.lab.l <= 75) f], 10), heldOut: true),
    Box('Held Cool 10', draw([for (final f in all) if (chroma(f.lab) >= 10 && h360(f) >= 120 && h360(f) <= 300) f], 10), heldOut: true),
  ];
}

/* The boxes tuning may look at. */
List<Box> tuningBoxes() => [sampleBox(), tuningBox(), Box('All 47', startCloth()), ...drawnBoxes()];

List<Box> allBoxes() => [...tuningBoxes(), ...heldOutBoxes()];

// ---- One case: a pattern, a box, a board, a seed. ----

class Case {
  Case(this.key, this.box, this.heldOut, this.size, this.seed, this.fills, this.why, this.solved, this.random, this.sorted,
      this.grid, this.colours, this.millis);
  final LayoutKey key;
  final String box;
  final bool heldOut;
  final BoardSize size;
  final int seed;
  /* False when the studio refuses to fill the pattern from this box (it fades the tile); then nothing is judged. */
  final bool fills;
  final String? why;
  final Judged? solved, random, sorted;
  final List<int>? grid;
  final List<Lab>? colours;
  final int millis;
  Outcome get outcome => fills ? solved!.rule.outcome : Outcome.cannot;
}

Case runCase(LayoutKey key, Box box, BoardSize g, int seed, {SolveOptions? options}) {
  final n = g.rows * g.cols, b = box.forBoard(n);
  final m = modelFor(key, ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock, size: g));
  Case refused(String why) => Case(key, box.name, box.heldOut, g, seed, false, why, null, null, null, null, null, 0);
  if (!m.fills) return refused(m.why?.name ?? 'refused');
  final prep = prepare(m.pool);
  final sw = Stopwatch()..start();
  final s = solve(m.obj, prep, b.stock, b.members, options ?? SolveOptions(seed: seed));
  final ms = sw.elapsedMilliseconds;
  if (s == null) return refused('no solve');
  final rand = randomGrid(b.stock, b.members, n, seed * 7919 + n);
  final sorted = sortedGrid(key, m, b.stock, b.members);
  return Case(key, box.name, box.heldOut, g, seed, true, null, judge(key, m, s.grid, b.stock, b.members, g),
      judge(key, m, rand, b.stock, b.members, g), sorted == null ? null : judge(key, m, sorted, b.stock, b.members, g),
      s.grid, b.pool.lab, ms);
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
