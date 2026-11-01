import 'dart:math' as math;
import 'dart:typed_data';
import 'cam16.dart';
import 'hue.dart' show Lab;
import 'js_math.dart';

typedef Pair = (int, int);
const edgeOffsets = [(0, 1), (1, 0)];

List<Pair> pairsFor(int rows, int cols, List<(int, int)> offsets) {
  final out = <Pair>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      for (final (dr, dc) in offsets) {
        final nr = r + dr, nc = c + dc;
        if (nr < rows && nc >= 0 && nc < cols) out.add((r * cols + c, nr * cols + nc));
      }
    }
  }
  return out;
}

class Weights {
  const Weights({required this.clump, required this.contrast, required this.lightness, required this.printClash,
      required this.printFrame, required this.balance, required this.deTarget, required this.sameColour, required this.lTarget,
      required this.frameLTarget});
  /* deTarget: the colour difference a seam asks for (CAM16-UCS ΔE′); sameColour: within it (a′b′ only), a cloth is
     "that colour". */
  final double clump, contrast, lightness, printClash, printFrame, balance, deTarget, sameColour, lTarget, frameLTarget;
}

class Pool {
  const Pool({required this.lab, required this.lightness, required this.busy, this.visualWeight, this.grain, this.coherence});
  final List<Lab> lab;
  final List<double> lightness;
  final List<bool> busy;
  final List<double>? visualWeight;
  final List<double?>? grain, coherence;
  Pool withLightness(List<double> l) =>
      Pool(lab: lab, lightness: l, busy: busy, visualWeight: visualWeight, grain: grain, coherence: coherence);
}

class Perimeter {
  const Perimeter({required this.groundL, required this.clearance, required this.weight, required this.cells});
  final double groundL, clearance, weight;
  final Uint8List cells;
}

class Objective {
  Objective._(this.rows, this.cols, this.pairs, this.weights, this.balance)
      : seamLTarget = Float64List(pairs.length), seamL = Float64List(pairs.length), seamDE = Float64List(pairs.length),
        seamFrame = Float64List(pairs.length), boundary = Uint8List(pairs.length);
  final int rows, cols;
  final List<Pair> pairs;
  final Weights weights;
  final bool balance;
  final Float64List seamLTarget, seamL, seamDE, seamFrame;
  final Uint8List boundary;
  Float64List? targetL, wL, targetHue, wHue, wColour, targetOrient, wOrient, wAvoid;
  List<bool>? hueExclude;
  /* Where Spectrum's hue line cuts the CAM16 hue circle (purpleCut); targetHue is a position on that line. */
  double hueCut = 0;
  /* What a square costs, in degrees on the hue line, for an uncoloured cloth (hueExclude): never less than the farthest
     a coloured cloth can be from a target, the box's run from its warmest coloured cloth to its coolest (compile). */
  double hueExcludeGap = 0;
  Int32List? targetColour;
  /* The colour distance (CAM16-UCS a′b′) a square's cloth may be from its targetColour at no cost: 0 for Blocks' and
     Diamond's families, sameColour for Heart, whose rule counts every cloth that near as the heart's colour. */
  double colourFree = 0;
  /* A colour a square stays away from (Heart's ground from the heart's cloth): a cloth within sameColour of it is that
     colour, and costs as much wherever it falls within; beyond, nothing. */
  Int32List? avoidColour;
  /* The one cloth a square must take (Chain's links), -1 for none; any other costs pinWeight. */
  Int32List? pin;
  double pinWeight = 0;
  Perimeter? perimeter;
}

Objective newObjective({required int rows, required int cols, required List<Pair> pairs, required Weights weights,
        required bool balance}) =>
    Objective._(rows, cols, pairs, weights, balance);

sealed class SeamRule { const SeamRule(); }
class SeamFull extends SeamRule { const SeamFull(); }
class SeamLightness extends SeamRule { const SeamLightness(); }
class SeamNone extends SeamRule { const SeamNone(); }
class SeamCustom extends SeamRule {
  const SeamCustom({required this.lTarget, required this.weight});
  final double lTarget, weight;
}

typedef SeamWeights = ({double lTarget, double l, double de, double frame});

SeamWeights seamOf(SeamRule rule, Weights w) => switch (rule) {
      SeamCustom(:final lTarget, :final weight) => (lTarget: lTarget, l: weight, de: 0.0, frame: 0.0),
      SeamNone() => (lTarget: w.lTarget, l: 0.0, de: 0.0, frame: 0.0),
      SeamLightness() => (lTarget: w.lTarget, l: w.lightness, de: 0.0, frame: 0.0),
      SeamFull() => (lTarget: w.lTarget, l: w.lightness, de: w.contrast, frame: w.printFrame),
    };

class Prepared {
  Prepared(this.n, this.de, this.dl, this.dc, this.l, this.vw, this.busy, this.hue, this.grain, this.coherence);
  final int n;
  /* de: CAM16-UCS ΔE′; dl: |ΔL*|; dc: CAM16-UCS a′b′ distance; hue: CAM16 hue angle. */
  final Float64List de, dl, dc;
  final List<double> l, vw, hue, grain, coherence;
  final List<bool> busy;
}

/* `list?.[i] ?? 0` in TypeScript: an index past the end, or a null entry, gives 0. */
double _at(List<double?>? list, int i) => list != null && i < list.length ? (list[i] ?? 0) : 0;

/* Every colour difference is CAM16-UCS (cam16.dart); lightness differences are CIE L*. */
Prepared prepare(Pool pool) {
  final n = pool.lab.length;
  final de = Float64List(n * n), dl = Float64List(n * n), dc = Float64List(n * n);
  final ucs = [for (final l in pool.lab) ucsOf(l)];
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      de[i * n + j] = deUcs(ucs[i], ucs[j]);
      dl[i * n + j] = (pool.lightness[i] - pool.lightness[j]).abs();
      dc[i * n + j] = chromaUcs(ucs[i], ucs[j]);
    }
  }
  return Prepared(n, de, dl, dc, pool.lightness, pool.visualWeight ?? [for (final l in pool.lightness) 100 - l],
      pool.busy, [for (final u in ucs) u.hue],
      [for (var i = 0; i < n; i++) _at(pool.grain, i)], [for (var i = 0; i < n; i++) _at(pool.coherence, i)]);
}

class Breakdown {
  const Breakdown({required this.clump, required this.contrast, required this.lightness, required this.printClash,
      required this.printFrame, required this.balance, required this.fit, required this.hue, required this.block,
      required this.orient, required this.perimeter, required this.total, required this.centreOffset, required this.underL,
      required this.underLBoundary, required this.faintest, required this.repeats, required this.prints, required this.bleeding});
  final double clump, contrast, lightness, printClash, printFrame, balance, fit, hue, block, orient, perimeter, total;
  final double centreOffset, faintest;
  final int underL, underLBoundary, repeats, prints, bleeding;
  Map<String, double> toMap() => {
        'clump': clump, 'contrast': contrast, 'lightness': lightness, 'printClash': printClash, 'printFrame': printFrame,
        'balance': balance, 'fit': fit, 'hue': hue, 'block': block, 'orient': orient, 'perimeter': perimeter, 'total': total,
        'centreOffset': centreOffset, 'underL': underL.toDouble(), 'underLBoundary': underLBoundary.toDouble(),
        'faintest': faintest, 'repeats': repeats.toDouble(), 'prints': prints.toDouble(), 'bleeding': bleeding.toDouble(),
      };
}

double orientGap(double a, double b) {
  final d = (a - b).abs().remainder(180);
  return math.min(d, 180 - d);
}

Breakdown score(List<int> grid, Objective obj, Prepared prep, [List<int>? rot]) {
  final w = obj.weights, cols = obj.cols, n = prep.n;
  var clump = 0.0, contrast = 0.0, lightness = 0.0, printClash = 0.0, printFrame = 0.0;
  var underL = 0, underLBoundary = 0, repeats = 0, prints = 0;
  var faintest = double.infinity;

  for (var p = 0; p < obj.pairs.length; p++) {
    final (a, b) = obj.pairs[p];
    final x = grid[a], y = grid[b], k = x * n + y;
    final gap = prep.dl[k];
    if (x == y) { clump += w.clump; repeats++; }
    if (gap < w.lTarget) { underL++; if (obj.boundary[p] != 0) underLBoundary++; }
    if (gap < faintest) faintest = gap;
    if (prep.busy[x] && prep.busy[y]) { printClash += w.printClash; prints++; }
    if (obj.seamL[p] > 0) lightness += math.max(0.0, obj.seamLTarget[p] - gap) * obj.seamL[p];
    if (obj.seamDE[p] > 0) contrast += math.max(0.0, w.deTarget - prep.de[k]) * obj.seamDE[p];
    if (obj.seamFrame[p] > 0 && prep.busy[x] != prep.busy[y]) {
      printFrame += math.max(0.0, w.frameLTarget - gap) * obj.seamFrame[p];
    }
  }

  var wsum = 0.0, wr = 0.0, wc = 0.0, fit = 0.0, hueFit = 0.0, block = 0.0, orient = 0.0, perimeter = 0.0;
  var bleeding = 0;
  final lastR = obj.rows - 1, lastC = cols - 1;
  for (var i = 0; i < grid.length; i++) {
    final f = grid[i], r = i ~/ cols, c = i % cols;
    wsum += prep.vw[f]; wr += prep.vw[f] * r; wc += prep.vw[f] * c;
    // Squared error: two pieces that both miss on one side cost more in the wrong order than in the right one, so the
    // fit itself ranks them (an absolute error would let them swap for nothing).
    if (obj.targetL != null) { final e = prep.l[f] - obj.targetL![i]; fit += e * e * obj.wL![i]; }
    if (obj.targetHue != null) {
      // Squared, as the lightness fit, so two squares both off one way cost more in the wrong order.
      final gap = (obj.hueExclude?[f] ?? false) ? obj.hueExcludeGap : hueOnLine(prep.hue[f], obj.hueCut) - obj.targetHue![i];
      hueFit += gap * gap * obj.wHue![i];
    }
    if (obj.targetColour != null) { final d = prep.dc[f * n + obj.targetColour![i]]; if (d > obj.colourFree) block += d * obj.wColour![i]; }
    // Avoiding a colour and taking a pinned cloth are colour terms too, so they count in `block`.
    if (obj.avoidColour != null && obj.avoidColour![i] >= 0) {
      if (prep.dc[f * n + obj.avoidColour![i]] <= w.sameColour) block += w.sameColour * obj.wAvoid![i];
    }
    if (obj.pin != null && obj.pin![i] >= 0 && f != obj.pin![i]) block += obj.pinWeight;
    if (obj.targetOrient != null && obj.wOrient![i] > 0 && prep.coherence[f] > 0) {
      final t = obj.targetOrient![i];
      final gapAt = rot != null
          ? orientGap(prep.grain[f] + 90 * rot[i], t)
          : math.min(orientGap(prep.grain[f], t), orientGap(prep.grain[f] + 90, t));
      orient += prep.coherence[f] * gapAt * obj.wOrient![i];
    }
    final per = obj.perimeter;
    if (per != null && per.cells[i] != 0) {
      final clear = (prep.l[f] - per.groundL).abs();
      if (clear < per.clearance) {
        perimeter += (per.clearance - clear) * per.weight;
        bleeding++;
      }
    }
  }
  final centreOffset = wsum > 0 ? jsHypot2(wr / wsum - lastR / 2, wc / wsum - lastC / 2) : 0.0;
  final balance = obj.balance ? centreOffset * w.balance : 0.0;

  return Breakdown(
    clump: clump, contrast: contrast, lightness: lightness, printClash: printClash, printFrame: printFrame,
    balance: balance, fit: fit, hue: hueFit, block: block, orient: orient, perimeter: perimeter,
    total: clump + contrast + lightness + printClash + printFrame + balance + fit + hueFit + block + orient + perimeter,
    centreOffset: centreOffset, underL: underL, underLBoundary: underLBoundary,
    faintest: faintest == double.infinity ? 0 : faintest, repeats: repeats, prints: prints, bleeding: bleeding,
  );
}
