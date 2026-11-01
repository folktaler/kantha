/* A template and a box of cloth become the
   objective the solver minimises. The two sorts break ties by original order, as
   JavaScript's stable sort did. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'cam16.dart';
import 'families.dart';
import 'geometry.dart';
import 'hue.dart';
import 'score.dart';
import 'spec.dart';
import 'tuned.dart';

/* The thresholds, each on its own measure. lTarget 25 L* (a seam's lightness gap) and frameLTarget 30 L* are design
   choices with no published source. deTarget, a seam's colour difference, is 15.8 CAM16-UCS ΔE′, and sameColour, the
   distance within which a cloth is "that colour", 19.4 in CAM16-UCS a′b′: each keeps, over the 90 cloths of the Sample
   box, the tuning pool and the 47 factory cloths, the same share of pairs on its side as the 20 it replaces did (20 in
   CIE76 ΔE*ab for seams, 9.3% of pairs under it; 20 in CIEDE2000's hue-and-chroma part, 44.3%). That 20 had no
   published source either. */
Weights baseWeightsWith(double lightness) => Weights(clump: 100, contrast: 1, lightness: lightness, printClash: 60,
    printFrame: 4, balance: 50, deTarget: 15.8, sameColour: 19.4, lTarget: 25, frameLTarget: 30);
/* wFit weighs the squared lightness error (L*²). 0.05, tuned on 1 November 2026 on the tuning boxes only (tool/
   pattern_sweep.dart's held-out boxes untouched; 36 board sizes, seed 1), against the clump weight of 100: of 0.05,
   0.1, 0.2, 0.4 and 0.8, the rules passed 94.1, 94.8, 94.6, 94.4 and 94.1% of cases and no same-cloth neighbours held
   in 99.8, 98.7, 95.4, 86.2 and 77.3%. 0.05 keeps the owner's no-neighbours rule best for 0.7 points of passes.
   wHue weighs Spectrum's squared hue error (degrees²), 0.001. With an uncoloured cloth costing max(the box's run, 180)
   on the hue line (1 November 2026), the pattern sweep passed 800 of 800 tuning units and 400 of 400 held-out, with no
   same-cloth neighbours on 100% of boards. */
const double wFit = 0.05, wHue = 0.001;
/* Heart: the share of the heart's squares that must be its colour, the rest any cloth. The pattern checks' own
   heartShare (test/solver/pattern_rules.dart, fixed 1 November 2026) is the same number by definition; Heart's lightness
   target asks for the darkest heart that share allows (1 November 2026). */
const double heartColourShare = 0.8;
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
      required this.stock, this.size, this.lightnessWeight, this.seamOverride, this.blockWeight, this.boundaryWeight, this.colourWeight});
  final Pool pool;
  final List<double?> edge;
  final List<int> members;
  final Mount mount;
  final List<int> stock;
  /* The board; null is Level 1's. */
  final BoardSize? size;
  final double? lightnessWeight, blockWeight, boundaryWeight, colourWeight;
  final SeamRule? seamOverride;
}

enum Unfillable { noColour, fewPieces, noDarkEnough, noFamilies, noChainCloth, noRingFamily }

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
    final u = ucsOf(pool.lab[i]), c = u.c;
    if (c < minChroma) continue;
    final gap = angleGap(u.hue, hue);
    if (gap < bestGap - 1e-9 || ((gap - bestGap).abs() <= 1e-9 && c > bestC)) { best = i; bestGap = gap; bestC = c; }
  }
  return best;
}

/* A zone made of one cloth (Chain's links): its squares on `size`, those where its lightness field is 0, and the cloth
   that takes them, the darkest member at or below the middle of the box's lightness with a piece for each square (-1
   when none has). With no `stock`, the cloth it would take given the pieces (the start page, start.dart). */
({List<int> squares, int cloth}) oneClothOf(LayoutSpec spec, int zone, Pool pool, List<int> members, BoardSize size,
    {List<int>? stock}) {
  final zones = spec.zonesOn(size), t = fieldCells((spec.rules[zone]!.l! as LFromT).t, size);
  final squares = [for (var i = 0; i < zones.length; i++) if (zones[i] == zone && t[i] == 0) i];
  var lmin = double.infinity, lmax = double.negativeInfinity;
  for (final i in members) { lmin = math.min(lmin, pool.lightness[i]); lmax = math.max(lmax, pool.lightness[i]); }
  final mid = (lmin + lmax) / 2;
  var cloth = -1;
  for (final i in members) {
    if ((stock != null && stock[i] < squares.length) || pool.lightness[i] > mid) continue;
    if (cloth < 0 || pool.lightness[i] < pool.lightness[cloth]) cloth = i;
  }
  return (squares: squares, cloth: cloth);
}

Compiled compile(LayoutSpec spec, ObjectiveInput input) {
  final size = input.size ?? level1, rows = size.rows, cols = size.cols, cells = rows * cols;
  if (rows < 2 || cols < 2) throw ArgumentError('a board is at least 2 × 2 squares, not $rows × $cols');
  final zones = spec.zonesOn(size);
  final members = input.members, mount = input.mount, stock = input.stock;
  final s = _statsOf(input.pool, input.edge, members);
  final weights = baseWeightsWith(input.lightnessWeight ?? Tuned.lightness);
  final pairs = pairsFor(rows, cols, edgeOffsets);
  final obj = newObjective(rows: rows, cols: cols, pairs: pairs, weights: weights, balance: spec.balance);
  var pool = input.pool;
  final anchors = <int, int>{};
  Unfillable? why;
  void refuse(Unfillable reason) => why ??= reason;

  for (var p = 0; p < pairs.length; p++) {
    final (a, b) = pairs[p];
    final crosses = zones[a] != zones[b];
    if (crosses) obj.boundary[p] = 1;
    final rule = input.seamOverride ?? (crosses && spec.boundary != null ? spec.boundary! : spec.within);
    final r = seamOf(rule, weights);
    obj.seamLTarget[p] = r.lTarget; obj.seamL[p] = r.l; obj.seamDE[p] = r.de; obj.seamFrame[p] = r.frame;
    if (crosses && spec.boundary != null && input.boundaryWeight != null) obj.seamL[p] = input.boundaryWeight!;
  }

  final zoneIds = zones.toSet().toList()..sort();
  List<int> cellsIn(int z) => [for (var i = 0; i < cells; i++) if (zones[i] == z) i];
  final familyZones = [for (final z in zoneIds) if (spec.rules[z]?.family != null) z];
  final medoidOf = <int, int>{};
  if (familyZones.isNotEmpty) {
    final families = colourFamilies(input.pool.lab, members, familyZones.length);
    if (families == null) {
      refuse(Unfillable.noFamilies);
    } else {
      // A family's capacity is its pieces. Capping it at the squares it can tile keeping the light-and-dark seam gap
      // (tileableCells, until 1 November 2026) matched families to blocks they cannot fill: over the pattern sweep's
      // tuning boxes it made 650 units, against 751 by pieces, and on the held-out boxes 304 against 377.
      final capacity = [
        for (var q = 0; q < families.medoids.length; q++)
          [for (final i in members) if (families.family[i] == q) stock[i]].fold(0, (a, b) => a + b),
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
      final t = lr is LFromT ? fieldCells(lr.t, size) : null;
      for (final i in zone) {
        obj.targetL![i] = t != null ? s.lmin + t[i] * (s.lmax - s.lmin) : (lr as LAt).at(i ~/ cols, i % cols, size, s);
        obj.wL![i] = lr.weight;
      }
    }
    final er = rules.edge;
    if (er != null) {
      ensureL();
      pool = _printPool(input.pool, input.edge, s);
      final t = fieldCells(er.t, size);
      for (final i in zone) { obj.targetL![i] = 100 * t[i]; obj.wL![i] = er.weight; }
    }
    final hr = rules.hue;
    if (hr != null) {
      ensureHue();
      final t = fieldCells(hr.angle, size);
      // Spectrum runs from the box's coolest coloured cloth to its warmest, as Gradient runs from its lightest to its
      // darkest: CAM16 hue, the circle cut in the purples where the box has no hue (purpleCut), and the drawn 200° to 20°
      // stretched onto the box's own run along that line.
      final hues = [for (final i in members) if (coloured(input.pool.lab[i])) ucsOf(input.pool.lab[i]).hue];
      final cut = purpleCut(hues), line = [for (final h in hues) hueOnLine(h, cut)];
      final cool = line.isEmpty ? 0.0 : line.reduce(math.max), warm = line.isEmpty ? 0.0 : line.reduce(math.min);
      for (final i in zone) { obj.targetHue![i] = warm + (t[i] - 20) / 180 * (cool - warm); obj.wHue![i] = hr.weight; }
      obj.hueExclude ??= [for (final l in input.pool.lab) !coloured(l)];
      obj.hueCut = cut;
      // An uncoloured cloth costs at least as much as the farthest a coloured one can be: 180, as it always was, or the
      // box's own run from warm to cool where that is wider.
      obj.hueExcludeGap = math.max(cool - warm, 180);
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
        obj.colourFree = weights.sameColour;
        // Its lightness: the darkest heart its shares allow, so the fit asks for the darkest of that colour and leaves
        // the light pieces to the ground: the darkest pieces of its colour for [heartColourShare] of its squares, then the
        // darkest pieces left, of any colour, for the rest (as Diamond's rings take their family's).
        final l = input.pool.lightness;
        bool near(int i) => chromaUcs(ucsOf(input.pool.lab[i]), ucsOf(input.pool.lab[anchor])) <= weights.sameColour;
        final dark = [for (final i in members) if (stock[i] > 0) i]..sort((a, b) => l[a].compareTo(l[b]));
        final left = {for (final i in dark) i: stock[i]};
        var placed = 0, sum = 0.0;
        void take(Iterable<int> from, int upTo) {
          for (final i in from) {
            final k = math.min(left[i]!, upTo - placed);
            sum += k * l[i]; placed += k; left[i] = left[i]! - k;
            if (placed == upTo) return;
          }
        }
        take(dark.where(near), (heartColourShare * zone.length).ceil());
        if (placed > 0) {
          take(dark, zone.length);
          ensureL();
          final mean = sum / placed;
          for (final i in zone) { obj.targetL![i] = mean; obj.wL![i] = Tuned.fitHeart; }
        }
      }
    }
    final or = rules.orient;
    if (or != null) {
      ensureOrient();
      final t = fieldCells(or.angle, size);
      for (final i in zone) { obj.targetOrient![i] = t[i]; obj.wOrient![i] = or.weight; }
    }
  }

  for (final z in zoneIds) {
    final rules = spec.rules[z];
    final av = rules?.avoid;
    // The colour to keep away from: the anchor of the zone that asks for a colour (the heart), not any other zone's.
    final anchor = av == null ? null
        : [for (final y in zoneIds) if (spec.rules[y]?.colour != null && (anchors[y] ?? -1) >= 0) anchors[y]!].firstOrNull;
    // Only where the box can: as many pieces away from that colour as the zone has squares. Otherwise the ground has
    // to take the colour, and pushing against it buys only same-cloth neighbours.
    final away = anchor == null ? 0 : [for (final i in members)
        if (chromaUcs(ucsOf(input.pool.lab[i]), ucsOf(input.pool.lab[anchor])) > weights.sameColour) stock[i]].fold(0, (a, b) => a + b);
    if (av != null && anchor != null && away >= cellsIn(z).length) {
      obj.avoidColour ??= Int32List(cells)..fillRange(0, cells, -1);
      obj.wAvoid ??= Float64List(cells);
      for (final i in cellsIn(z)) { obj.avoidColour![i] = anchor; obj.wAvoid![i] = av.weight; }
    }
    final one = rules?.oneCloth, lr = rules?.l;
    if (one != null && lr is LFromT) {
      final (squares: links, :cloth) = oneClothOf(spec, z, input.pool, members, size, stock: stock);
      final best = cloth;
      if (best < 0) {
        refuse(Unfillable.noChainCloth);
      } else {
        anchors[z] = best;
        obj.pin ??= Int32List(cells)..fillRange(0, cells, -1);
        obj.pinWeight = one.weight;
        // The links' lightness target is the pinned cloth's own, so the fit and the pin ask for the same thing.
        for (final i in links) { obj.pin![i] = best; obj.targetL![i] = input.pool.lightness[best]; }
      }
    }
  }

  for (final z in zoneIds) {
    final rf = spec.rules[z]?.ringFamilies, lr = spec.rules[z]?.l;
    if (rf == null || lr is! LFromT) continue;
    final t = fieldCells(lr.t, size), zone = cellsIn(z);
    final levels = {for (final i in zone) t[i]}.toList()..sort();
    final families = colourFamilies(input.pool.lab, members, levels.length, lightness: true);
    if (families == null) { refuse(Unfillable.noRingFamily); continue; }
    // The families darkest first (their pieces' mean L*), to the levels darkest first; each needs a piece for every
    // square of its level.
    double meanL(int q) {
      var sum = 0.0, count = 0;
      for (final i in members) { if (families.family[i] == q) { sum += stock[i] * input.pool.lightness[i]; count += stock[i]; } }
      return count == 0 ? double.infinity : sum / count;
    }
    int pieces(int q) => [for (final i in members) if (families.family[i] == q) stock[i]].fold(0, (a, b) => a + b);
    final order = [for (var q = 0; q < families.medoids.length; q++) q]
      ..sort((a, b) { final c = meanL(a).compareTo(meanL(b)); return c != 0 ? c : a.compareTo(b); });
    ensureColour();
    // Each level's lightness target is its own family's mean L*, so the lightness fit asks for the family's pieces
    // rather than pulling the ring towards other families' lightness.
    for (var k = 0; k < levels.length; k++) {
      final q = order[k], at = [for (final i in zone) if (t[i] == levels[k]) i];
      if (pieces(q) < at.length) refuse(Unfillable.noRingFamily);
      for (final i in at) { obj.targetColour![i] = families.medoids[q]; obj.wColour![i] = rf.weight; obj.targetL![i] = meanL(q); }
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
        if (stock[i] > 0 && chromaUcs(ucsOf(input.pool.lab[i]), ucsOf(input.pool.lab[anchor])) <= weights.sameColour) i,
    ];
    var reach = 0;
    for (final i in candidates) { reach += math.min(stock[i], half); }
    if (reach < zone.length) { refuse(Unfillable.fewPieces); continue; }
    final touching = <int>{};
    var groundL = double.negativeInfinity, target = weights.lTarget;
    for (var p = 0; p < pairs.length; p++) {
      final (a, b) = pairs[p];
      final mine = zones[a] == z ? a : zones[b] == z ? b : -1;
      final other = mine == a ? b : a;
      if (mine < 0 || zones[other] == z || obj.targetL == null || !(obj.wL![other] > 0)) continue;
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
