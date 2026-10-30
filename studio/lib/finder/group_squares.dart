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
