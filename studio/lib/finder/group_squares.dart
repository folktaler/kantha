/* Repeated cloths among the found squares: each square's colours as CIELAB histograms (a*b* 16 x 16 and L* 16,
   each summing to 1), compared by Bhattacharyya distance (the mean of the two), joined by average linkage, as
   tested in Python on 30 October 2026. Each square is measured on its middle only, away from seams and the floor. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'cv.dart';
import 'find_squares.dart';

/// Squares closer than this (mean Bhattacharyya distance, average linkage) are one cloth. 0.25, the owner's
/// decision of 30 October 2026: a wrong split is the safer mistake, since two box entries of the same colour still
/// design right, while a wrong join puts one cloth in the wrong colour. Measured: the halloween quilt 62 of 63
/// squares in the right group, 30 groups for its 18 cloths, adjusted Rand index 0.63; the stacks photo 4 of 26
/// squares wrongly joined. At 0.35, the cut tested first: 56 of 63, 19 groups, 0.70; 9 of 26 wrongly joined.
const groupCut = 0.25;

typedef LabHistograms = ({Float32List ab, Float32List l});

/// [cell]'s histograms: a*b* 16 x 16 and L* 16, each summing to 1. [cell] is BGR.
LabHistograms labHistograms(FinderCv cv, CvMat cell) {
  final lab = cv.cvtColor(cell, CvColour.bgrToLab);
  Float32List norm(Float32List h) {
    final s = h.fold(0.0, (a, b) => a + b);
    return Float32List.fromList([for (final v in h) v / s]);
  }

  final out = (ab: norm(cv.calcHist(lab, const [1, 2], null, 16)), l: norm(cv.calcHist(lab, const [0], null, 16)));
  lab.dispose();
  return out;
}

double histDistance(FinderCv cv, LabHistograms a, LabHistograms b) =>
    (cv.compareHistBhattacharyya(a.ab, b.ab) + cv.compareHistBhattacharyya(a.l, b.l)) / 2;

/// The histograms of each found square's middle: the square straightened to 80 x 80 in the working picture,
/// 12 % taken off each side (as the Python did).
List<LabHistograms> squareHistograms(FinderCv cv, FoundSquares found) {
  const size = 80, margin = 9; // int(80 * 0.12)
  final out = <LabHistograms>[];
  for (final q in found.squares) {
    final cell = cv.warpQuad(found.work, q, size);
    final middle = cv.roi(cell, margin, margin, size - 2 * margin, size - 2 * margin);
    out.add(labHistograms(cv, middle));
    middle.dispose();
    cell.dispose();
  }
  return out;
}

/// One group number per item, 0 for the largest group: average linkage on [distance], cut at [cut]. Groups of
/// equal size are numbered by their first item.
List<int> groupsOf(FinderCv cv, List<LabHistograms> hists, {double cut = groupCut}) {
  final n = hists.length;
  final d = List.generate(n, (_) => Float64List(n));
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      d[i][j] = d[j][i] = histDistance(cv, hists[i], hists[j]);
    }
  }
  return averageLinkage(d, cut);
}

/// Average linkage (UPGMA): the two closest groups are joined while they are no further apart than [cut], their
/// distance to every other group the mean over all pairs of members. The same groups as scipy's
/// fcluster(linkage(d, 'average'), cut, 'distance'). No maintained Dart package does it: simple_cluster, the one
/// on pub.dev, was last released in March 2021 and does not allow Dart 3.
List<int> averageLinkage(List<Float64List> distance, double cut) {
  final n = distance.length;
  final members = [for (var i = 0; i < n; i++) [i]];
  final d = [for (final row in distance) Float64List.fromList(row)];
  final alive = List.filled(n, true);
  while (true) {
    var bi = -1, bj = -1, best = double.infinity;
    for (var i = 0; i < n; i++) {
      if (!alive[i]) continue;
      for (var j = i + 1; j < n; j++) {
        if (alive[j] && d[i][j] < best) (bi, bj, best) = (i, j, d[i][j]);
      }
    }
    if (bi < 0 || best > cut) break;
    final ni = members[bi].length, nj = members[bj].length;
    for (var k = 0; k < n; k++) {
      if (!alive[k] || k == bi || k == bj) continue;
      d[bi][k] = d[k][bi] = (d[bi][k] * ni + d[bj][k] * nj) / (ni + nj);
    }
    members[bi].addAll(members[bj]);
    alive[bj] = false;
  }
  final groups = [for (var i = 0; i < n; i++) if (alive[i]) members[i]..sort()]
    ..sort((a, b) => a.length != b.length ? b.length - a.length : a.first - b.first);
  final out = List.filled(n, 0);
  for (var g = 0; g < groups.length; g++) {
    for (final i in groups[g]) {
      out[i] = g;
    }
  }
  return out;
}

/// The size, in the picture's own pixels, a found square is cut at: its mean side, never enlarged.
int cropSide(Float32List q, double scale) {
  var s = 0.0;
  for (var k = 0; k < 4; k++) {
    final dx = q[2 * ((k + 1) % 4)] - q[2 * k], dy = q[2 * ((k + 1) % 4) + 1] - q[2 * k + 1];
    s += math.sqrt(dx * dx + dy * dy);
  }
  return (s / 4 / scale).round();
}

/// How the found squares sit in their photo, to tell one printed cloth (a check or a gingham: the squares are its
/// pattern, and between them is the cloth's own band) from separate pieces (between them is the table). Colours are
/// the finder's blurred CIELAB ([FoundSquares.lab]); each region's colour is its median, channel by channel.
/// - [boxSpread]: how far each square's middle (its inner 60 %) is from the squares' common colour, the median;
/// - [ringSpread]: the same for the ring round each square (out to 1.3 times it, every square left out);
/// - [ringVsBox]: how far the rings' common colour is from the squares';
/// - [ringVsOutside]: how far the rings' common colour is from everything more than a side beyond the squares'
///   convex hull, or null when that is under 2 % of the photo (the squares fill it).
/// Null when no square is big enough to measure.
typedef PrintLook = ({double boxSpread, double ringSpread, double ringVsBox, double? ringVsOutside});

PrintLook? printLook(FinderCv cv, FoundSquares found) {
  final quads = found.squares;
  if (quads.isEmpty) return null;
  final lab = found.lab, w = lab.cols, h = lab.rows;
  final sides = [for (final q in quads) _sideOf(q)]..sort();
  final side = sides[sides.length ~/ 2];
  // The least a region is measured on: 4 points an eighth of a side apart, as the colours were first sampled.
  final least = 4 * math.pow(math.max(1.0, side / 8), 2);
  Int32List grown(Float32List q, double by) {
    final cx = (q[0] + q[2] + q[4] + q[6]) / 4, cy = (q[1] + q[3] + q[5] + q[7]) / 4;
    return Int32List.fromList([for (var k = 0; k < 8; k++) (k.isEven ? cx + (q[k] - cx) * by : cy + (q[k] - cy) * by).round()]);
  }

  // Everything but the squares, once.
  final open = cv.zeros(w, h);
  cv.fillPoly(open, Int32List.fromList([0, 0, w, 0, w, h, 0, h]), 255);
  for (final q in quads) {
    cv.fillPoly(open, grown(q, 1), 0);
  }
  final boxMid = <List<double>>[], ringMid = <List<double>>[];
  for (final q in quads) {
    final outer = grown(q, 1.3);
    var x0 = w, y0 = h, x1 = 0, y1 = 0;
    for (var k = 0; k < 8; k += 2) {
      x0 = math.min(x0, outer[k]);
      x1 = math.max(x1, outer[k] + 1);
      y0 = math.min(y0, outer[k + 1]);
      y1 = math.max(y1, outer[k + 1] + 1);
    }
    x0 = math.max(x0, 0);
    y0 = math.max(y0, 0);
    x1 = math.min(x1, w);
    y1 = math.min(y1, h);
    if (x1 <= x0 || y1 <= y0) continue;
    final rw = x1 - x0, rh = y1 - y0;
    final colours = cv.roi(lab, x0, y0, rw, rh), around = cv.roi(open, x0, y0, rw, rh);
    final box = cv.zeros(rw, rh), ringAll = cv.zeros(rw, rh);
    cv.fillPoly(box, grown(q, 0.6), 255, dx: x0, dy: y0);
    cv.fillPoly(ringAll, outer, 255, dx: x0, dy: y0);
    final ring = cv.bitwiseAnd(ringAll, around);
    if (cv.countNonZero(box) >= least && cv.countNonZero(ring) >= least) {
      boxMid.add(_medianUnder(cv, colours, box));
      ringMid.add(_medianUnder(cv, colours, ring));
    }
    for (final m in [colours, around, box, ringAll, ring]) {
      m.dispose();
    }
  }
  open.dispose();
  if (boxMid.isEmpty) return null;

  // Beyond the squares: the outside of their convex hull grown by a side, read at an eighth of a side to the pixel
  // (a full-size dilate by a side took 400 ms of a slowed phone's time on a photo of large squares).
  final f = 1 / math.max(1.0, side / 8);
  final small = f < 1 ? cv.resizeArea(lab, f) : lab;
  final hull = cv.convexHull(Int32List.fromList([for (final q in quads) for (final v in q) (v * f).round()]));
  final within = cv.zeros(small.cols, small.rows);
  cv.fillPoly(within, hull, 255);
  final near = cv.dilateEllipse(within, 2 * (side * f).round() + 1), outside = cv.bitwiseNot(near);
  within.dispose();
  near.dispose();
  final outsideColour =
      cv.countNonZero(outside) < 0.02 * small.cols * small.rows ? null : _medianUnder(cv, small, outside);
  outside.dispose();
  if (f < 1) small.dispose();

  final b = _median(boxMid), r = _median(ringMid);
  double spread(List<List<double>> cs, List<double> m) => _median([for (final c in cs) [_distance(c, m)]]).single;
  return (
    boxSpread: spread(boxMid, b),
    ringSpread: spread(ringMid, r),
    ringVsBox: _distance(r, b),
    ringVsOutside: outsideColour == null ? null : _distance(r, outsideColour),
  );
}

/// The median colour of [lab] under [mask], channel by channel (the upper one of an even count), as L* 0 to 100 and
/// a*, b* about 0.
List<double> _medianUnder(FinderCv cv, CvMat lab, CvMat mask) {
  final out = <double>[];
  for (var c = 0; c < 3; c++) {
    final hist = cv.calcHist(lab, [c], mask, 256);
    final half = hist.fold(0.0, (a, b) => a + b) ~/ 2;
    var v = 0;
    for (var seen = hist[0]; seen <= half; seen += hist[++v]) {}
    out.add(c == 0 ? v * 100 / 255 : v - 128.0);
  }
  return out;
}

double _sideOf(Float32List q) {
  var s = 0.0;
  for (var k = 0; k < 4; k++) {
    s += math.sqrt(math.pow(q[2 * ((k + 1) % 4)] - q[2 * k], 2) + math.pow(q[2 * ((k + 1) % 4) + 1] - q[2 * k + 1], 2));
  }
  return s / 4;
}

double _distance(List<double> a, List<double> b) =>
    math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2) + math.pow(a[2] - b[2], 2));

/// The median of each channel, the upper one of an even count.
List<double> _median(List<List<double>> cs) => [
      for (var k = 0; k < cs.first.length; k++) ([for (final c in cs) c[k]]..sort())[cs.length ~/ 2],
    ];
