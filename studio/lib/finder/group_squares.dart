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
List<LabHistograms> squareHistograms(FinderCv cv, CvMat photo, FoundSquares found) {
  const size = 80, margin = 9; // int(80 * 0.12)
  final work = cv.resizeArea(photo, found.scale);
  final out = <LabHistograms>[];
  for (final q in found.squares) {
    final cell = cv.warpQuad(work, q, size);
    final middle = cv.roi(cell, margin, margin, size - 2 * margin, size - 2 * margin);
    out.add(labHistograms(cv, middle));
    middle.dispose();
    cell.dispose();
  }
  work.dispose();
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
/// CIELAB; each is the median, channel by channel, of points sampled every eighth of a side.
/// - [boxSpread]: how far each square's middle (its inner 60 %) is from the squares' common colour, the median;
/// - [ringSpread]: the same for the ring round each square (out to 1.3 times it, other squares left out);
/// - [ringVsBox]: how far the rings' common colour is from the squares';
/// - [ringVsOutside]: how far the rings' common colour is from everything more than a side beyond the squares'
///   outline, or null when that is under 2 % of the photo (the squares fill it).
/// Null when no square is big enough to sample.
typedef PrintLook = ({double boxSpread, double ringSpread, double ringVsBox, double? ringVsOutside});

PrintLook? printLook(FinderCv cv, CvMat photo, FoundSquares found) {
  final work = cv.resizeArea(photo, found.scale);
  final lab = cv.cvtColor(work, CvColour.bgrToLab);
  work.dispose();
  final w = lab.cols, h = lab.rows, px = cv.bytes(lab);
  lab.dispose();
  final quads = found.squares;
  if (quads.isEmpty) return null;
  final sides = [for (final q in quads) _sideOf(q)]..sort();
  final side = sides[sides.length ~/ 2];
  final step = math.max(1.0, side / 8);
  final centres = [for (final q in quads) ((q[0] + q[2] + q[4] + q[6]) / 4, (q[1] + q[3] + q[5] + q[7]) / 4)];
  Float32List grown(int i, double by) {
    final (cx, cy) = centres[i];
    return Float32List.fromList([for (var k = 0; k < 8; k++) k.isEven ? cx + (quads[i][k] - cx) * by : cy + (quads[i][k] - cy) * by]);
  }

  final inner = [for (var i = 0; i < quads.length; i++) grown(i, 0.6)];
  final outer = [for (var i = 0; i < quads.length; i++) grown(i, 1.3)];
  final hull = _hull([for (final q in quads) for (var k = 0; k < 8; k += 2) (q[k].toDouble(), q[k + 1].toDouble())]);
  final boxes = [for (final _ in quads) <List<double>>[]], rings = [for (final _ in quads) <List<double>>[]];
  final outside = <List<double>>[];
  var all = 0;
  for (var y = step / 2; y < h; y += step) {
    for (var x = step / 2; x < w; x += step) {
      all++;
      final o = (y.toInt() * w + x.toInt()) * 3;
      final c = [px[o] * 100 / 255, px[o + 1] - 128.0, px[o + 2] - 128.0];
      var inBox = -1, inRing = -1;
      for (var i = 0; i < quads.length; i++) {
        final (cx, cy) = centres[i];
        if ((x - cx).abs() > side || (y - cy).abs() > side) continue;
        if (_holds(quads[i], x, y)) {
          inBox = i;
          if (_holds(inner[i], x, y)) boxes[i].add(c);
          break;
        }
        if (inRing < 0 && _holds(outer[i], x, y)) inRing = i;
      }
      if (inBox >= 0) continue;
      if (inRing >= 0) {
        rings[inRing].add(c);
      } else if (_beyond(hull, x, y, side)) {
        outside.add(c);
      }
    }
  }
  final boxMid = <List<double>>[], ringMid = <List<double>>[];
  for (var i = 0; i < quads.length; i++) {
    if (boxes[i].length < 4 || rings[i].length < 4) continue;
    boxMid.add(_median(boxes[i]));
    ringMid.add(_median(rings[i]));
  }
  if (boxMid.isEmpty) return null;
  final b = _median(boxMid), r = _median(ringMid);
  double spread(List<List<double>> cs, List<double> m) => _median([for (final c in cs) [_distance(c, m)]]).single;
  return (
    boxSpread: spread(boxMid, b),
    ringSpread: spread(ringMid, r),
    ringVsBox: _distance(r, b),
    ringVsOutside: outside.length < 0.02 * all ? null : _distance(r, _median(outside)),
  );
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

/// Inside the convex quad [q], either way round.
bool _holds(Float32List q, double x, double y) {
  var sign = 0;
  for (var k = 0; k < 4; k++) {
    final ax = q[2 * k], ay = q[2 * k + 1], bx = q[2 * ((k + 1) % 4)], by = q[2 * ((k + 1) % 4) + 1];
    final s = ((bx - ax) * (y - ay) - (by - ay) * (x - ax)).sign.toInt();
    if (s == 0) continue;
    if (sign == 0) sign = s;
    if (s != sign) return false;
  }
  return true;
}

/// The convex hull, anticlockwise in image axes (Andrew's monotone chain).
List<(double, double)> _hull(List<(double, double)> points) {
  final p = [...points]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  double cross((double, double) o, (double, double) a, (double, double) b) =>
      (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
  final lower = <(double, double)>[], upper = <(double, double)>[];
  for (final q in p) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, q) <= 0) {
      lower.removeLast();
    }
    lower.add(q);
  }
  for (final q in p.reversed) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, q) <= 0) {
      upper.removeLast();
    }
    upper.add(q);
  }
  return [...lower..removeLast(), ...upper..removeLast()];
}

/// More than [by] outside the convex [hull].
bool _beyond(List<(double, double)> hull, double x, double y, double by) {
  var inside = true;
  var nearest = double.infinity;
  for (var k = 0; k < hull.length; k++) {
    final (ax, ay) = hull[k];
    final (bx, by2) = hull[(k + 1) % hull.length];
    if ((bx - ax) * (y - ay) - (by2 - ay) * (x - ax) < 0) inside = false;
    final dx = bx - ax, dy = by2 - ay, len = dx * dx + dy * dy;
    final t = len == 0 ? 0.0 : (((x - ax) * dx + (y - ay) * dy) / len).clamp(0.0, 1.0);
    nearest = math.min(nearest, math.sqrt(math.pow(x - ax - t * dx, 2) + math.pow(y - ay - t * dy, 2)));
  }
  return !inside && nearest > by;
}
