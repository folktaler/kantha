/* A template and a box of cloth become the
   objective the solver minimises. The two sorts break ties by original order, as
   JavaScript's stable sort did. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'families.dart';
import 'geometry.dart';
import 'hue.dart';
import 'score.dart';
import 'spec.dart';
import 'tuned.dart';

const double hueMinChroma = 10;
Weights baseWeightsWith(double lightness) => Weights(clump: 100, contrast: 1, lightness: lightness, printClash: 60,
    printFrame: 4, balance: 50, deTarget: 20, lTarget: 25, frameLTarget: 30);
const double wFit = 4, wHue = 0.5;
const double _canvasClearance = 25, _wPerimeter = 20;

PoolStats _statsOf(Pool pool, List<double?> edge, List<int> members) {
  var lmin = double.infinity, lmax = double.negativeInfinity;
  for (final i in members) { lmin = math.min(lmin, pool.lightness[i]); lmax = math.max(lmax, pool.lightness[i]); }
  final es = [for (final i in members) if (edge[i] != null) edge[i]!];
  return PoolStats(lmin, lmax, es.isEmpty ? 0 : es.reduce(math.min), es.isEmpty ? 0 : es.reduce(math.max));
}

Pool _printPool(Pool pool, List<double?> edge, PoolStats s) {
  final span = math.max(1e-9, s.emax - s.emin);
  return pool.withLightness([for (final e in edge) e == null ? 0.0 : 100 * (e - s.emin) / span]);
}

class ObjectiveInput {
  const ObjectiveInput({required this.pool, required this.edge, required this.members, required this.mount,
      required this.stock, this.lightnessWeight, this.seamOverride, this.blockWeight, this.boundaryWeight, this.colourWeight});
  final Pool pool;
  final List<double?> edge;
  final List<int> members;
  final Mount mount;
  final List<int> stock;
  final double? lightnessWeight, blockWeight, boundaryWeight, colourWeight;
  final SeamRule? seamOverride;
}

enum Unfillable { noColour, fewPieces, noDarkEnough, noFamilies }

class Compiled {
  const Compiled(this.obj, this.pool, this.fills, this.why, this.anchors);
  final Objective obj;
  final Pool pool;
  final bool fills;
  final Unfillable? why;
  final Map<int, int> anchors;
}

int anchorFor(Pool pool, List<int> members, double hue) {
  var best = -1;
  var bestGap = double.infinity, bestC = -1.0;
  for (final i in members) {
    final c = chroma(pool.lab[i]);
    if (c < hueMinChroma) continue;
    final gap = angleGap(hueOf(pool.lab[i]), hue);
    if (gap < bestGap - 1e-9 || ((gap - bestGap).abs() <= 1e-9 && c > bestC)) { best = i; bestGap = gap; bestC = c; }
  }
  return best;
}

Compiled compile(LayoutSpec spec, ObjectiveInput input) {
  final rows = a4.rows, cols = a4.cols;
  final members = input.members, mount = input.mount, stock = input.stock;
  final s = _statsOf(input.pool, input.edge, members);
  final weights = baseWeightsWith(input.lightnessWeight ?? Tuned.lightness);
  final pairs = pairsFor(rows, cols, edgeOffsets);
  final obj = newObjective(rows: rows, cols: cols, pairs: pairs, weights: weights, balance: spec.balance, distance: Distance.cie76);
  var pool = input.pool;
  final anchors = <int, int>{};
  Unfillable? why;
  void refuse(Unfillable reason) => why ??= reason;

  for (var p = 0; p < pairs.length; p++) {
    final (a, b) = pairs[p];
    final crosses = spec.zones[a] != spec.zones[b];
    if (crosses) obj.boundary[p] = 1;
    final rule = input.seamOverride ?? (crosses && spec.boundary != null ? spec.boundary! : spec.within);
    final r = seamOf(rule, weights);
    obj.seamLTarget[p] = r.lTarget; obj.seamL[p] = r.l; obj.seamDE[p] = r.de; obj.seamFrame[p] = r.frame;
    if (crosses && spec.boundary != null && input.boundaryWeight != null) obj.seamL[p] = input.boundaryWeight!;
  }

  final zoneIds = spec.zones.toSet().toList()..sort();
  List<int> cellsIn(int z) => [for (var i = 0; i < cells; i++) if (spec.zones[i] == z) i];
  final familyZones = [for (final z in zoneIds) if (spec.rules[z]?.family != null) z];
  final medoidOf = <int, int>{};
  if (familyZones.isNotEmpty) {
    final families = colourFamilies(input.pool.lab, members, familyZones.length, hueMinChroma);
    if (families == null) {
      refuse(Unfillable.noFamilies);
    } else {
      final capacity = [
        for (var q = 0; q < families.medoids.length; q++)
          tileableCells([for (final i in members) if (families.family[i] == q) i], input.pool.lightness, stock, weights.lTarget),
      ];
      final byCapacity = [for (var q = 0; q < families.medoids.length; q++) q]
        ..sort((a, b) { final c = capacity[b].compareTo(capacity[a]); return c != 0 ? c : a.compareTo(b); });
      final bySize = List.of(familyZones)
        ..sort((a, b) { final c = cellsIn(b).length.compareTo(cellsIn(a).length); return c != 0 ? c : a.compareTo(b); });
      for (var rank = 0; rank < bySize.length; rank++) { medoidOf[bySize[rank]] = families.medoids[byCapacity[rank]]; }
    }
  }

  void ensureL() { if (obj.targetL == null) { obj.targetL = Float64List(cells); obj.wL = Float64List(cells); } }
  void ensureHue() { if (obj.targetHue == null) { obj.targetHue = Float64List(cells); obj.wHue = Float64List(cells); } }
  void ensureColour() { if (obj.targetColour == null) { obj.targetColour = Int32List(cells); obj.wColour = Float64List(cells); } }
  void ensureOrient() { if (obj.targetOrient == null) { obj.targetOrient = Float64List(cells); obj.wOrient = Float64List(cells); } }

  for (final z in zoneIds) {
    final rules = spec.rules[z] ?? const ZoneRules();
    final zone = cellsIn(z);
    final lr = rules.l;
    if (lr != null) {
      ensureL();
      final t = lr is LFromT ? fieldCells(lr.t) : null;
      for (final i in zone) {
        obj.targetL![i] = t != null ? s.lmin + t[i] * (s.lmax - s.lmin) : (lr as LAt).at(i ~/ cols, i % cols, s);
        obj.wL![i] = lr.weight;
      }
    }
    final er = rules.edge;
    if (er != null) {
      ensureL();
      pool = _printPool(input.pool, input.edge, s);
      final t = fieldCells(er.t);
      for (final i in zone) { obj.targetL![i] = 100 * t[i]; obj.wL![i] = er.weight; }
    }
    final hr = rules.hue;
    if (hr != null) {
      ensureHue();
      final t = fieldCells(hr.angle);
      for (final i in zone) { obj.targetHue![i] = t[i]; obj.wHue![i] = hr.weight; }
      obj.hueExclude ??= [for (final l in input.pool.lab) chroma(l) < hueMinChroma];
    }
    final fr = rules.family;
    if (fr != null && medoidOf[z] != null) {
      ensureColour();
      for (final i in zone) { obj.targetColour![i] = medoidOf[z]!; obj.wColour![i] = input.blockWeight ?? fr.weight; }
    }
    final cr = rules.colour;
    if (cr != null) {
      final anchor = anchorFor(input.pool, members, cr.hue);
      anchors[z] = anchor;
      if (anchor < 0) {
        refuse(Unfillable.noColour);
      } else {
        ensureColour();
        for (final i in zone) { obj.targetColour![i] = anchor; obj.wColour![i] = input.colourWeight ?? cr.weight; }
      }
    }
    final or = rules.orient;
    if (or != null) {
      ensureOrient();
      final t = fieldCells(or.angle);
      for (final i in zone) { obj.targetOrient![i] = t[i]; obj.wOrient![i] = or.weight; }
    }
  }

  if (spec.perimeter) {
    final edgeCells = Uint8List(cells);
    for (var i = 0; i < cells; i++) {
      final r = i ~/ cols, c = i % cols;
      if (r == 0 || c == 0 || r == rows - 1 || c == cols - 1) edgeCells[i] = 1;
    }
    obj.perimeter = Perimeter(groundL: canvasL(mount), clearance: _canvasClearance, weight: _wPerimeter, cells: edgeCells);
  }

  for (final z in zoneIds) {
    if (why != null || spec.rules[z]?.colour == null || anchors[z]! < 0) continue;
    final anchor = anchors[z]!, zone = cellsIn(z);
    final half = (zone.length / 2).ceil();
    final candidates = [
      for (final i in members)
        if (stock[i] > 0 && chromaDistance(input.pool.lab[i], input.pool.lab[anchor]) <= weights.deTarget) i,
    ];
    var reach = 0;
    for (final i in candidates) { reach += math.min(stock[i], half); }
    if (reach < zone.length) { refuse(Unfillable.fewPieces); continue; }
    final touching = <int>{};
    var groundL = double.negativeInfinity, target = weights.lTarget;
    for (var p = 0; p < pairs.length; p++) {
      final (a, b) = pairs[p];
      final mine = spec.zones[a] == z ? a : spec.zones[b] == z ? b : -1;
      final other = mine == a ? b : a;
      if (mine < 0 || spec.zones[other] == z || obj.targetL == null || !(obj.wL![other] > 0)) continue;
      touching.add(mine);
      groundL = math.max(groundL, obj.targetL![other]);
      target = obj.seamLTarget[p];
    }
    if (touching.isEmpty) continue;
    var dark = 0;
    for (final i in candidates) {
      if (input.pool.lightness[i] <= groundL - target) dark += math.min(stock[i], (touching.length / 2).ceil());
    }
    if (dark < touching.length) refuse(Unfillable.noDarkEnough);
  }
  return Compiled(obj, pool, why == null, why, anchors);
}
