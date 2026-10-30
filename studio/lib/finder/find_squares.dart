/* The square finder: every cut square of cloth in one photo, at any angle, with no grid and no model of
   the floor. A port of the method tested in Python on 30 October 2026 (LSD lines, Felzenszwalb regions),
   same steps and thresholds:
   1. Outlines. Every channel of the blurred photo (B, G, R, L, a, b) thresholded at several levels, by
      Canny and by local thresholds, and Felzenszwalb's colour regions, each give outlines; those that
      simplify to 4 corners, convex, near-right corners and near-equal sides, are candidates. Candidates
      far from the common size go; duplicates (found in several pictures) merge to their median corners.
   2. Hypothesise and verify. A straight line segment about a side long is one side of a square of the
      common size; each such square is scored by how much of its sides lies on an edge running across it,
      refined by small shifts, turns and sizes, and kept if well supported and not split by a seam.
   3. Checks. A square needs different cloth across at least 3 of its sides, and cloth inside that is not
      the cloth around it.
   4. Panels. Squares found side by side in a regular grid are a sewn panel: each missing square inside the
      grid the found ones span is predicted from its found neighbours, row by row and column by column, and
      kept where edges run along its sides (a lighter check than step 2's, since a seam between two like
      cloths shows little). Loose squares do not touch in a grid, so they are never filled.
   Unlike the Python, each check works on the square's own bounding box, not a mask of the whole photo,
   and runs once per square. Every OpenCV call goes through FinderCv (cv.dart). */
import 'dart:math' as math;
import 'dart:typed_data';

import 'cv.dart';

/// The long side of the picture the finder works on, in pixels.
const workLongSide = 900;

class FoundSquares {
  FoundSquares(
    this.width,
    this.height,
    this.scale,
    this.side,
    this.squares,
    this.fromLines,
    this.outlineDropped,
    this.ringDropped,
    this.outlineMs,
    this.linesMs,
    this.fromPanels,
    this.panelMs,
    this.tiny,
  );

  /// The working picture, and its size over the photo's.
  final int width, height;
  final double scale;

  /// The common side, in working pixels; 0 when no square was found.
  final double side;

  /// Each square's 4 corners as x0, y0, … x3, y3 in working pixels.
  final List<Float32List> squares;

  /// How many squares step 2 added before the ring check; how many were dropped by the side check and the ring check.
  final int fromLines, outlineDropped, ringDropped;
  final int outlineMs, linesMs;

  /// How many squares step 4 added inside sewn panels.
  final int fromPanels, panelMs;

  /// How many outlines had a square's shape but were under the smallest size (0.0015 of the picture), down to
  /// [tinyArea] of it, counted over every picture step 1 looks at (so one piece is counted many times): many of them
  /// and no squares found means the pieces are there but too small in the photo.
  final int tiny;
}

/// The smallest outline [FoundSquares.tiny] counts, as a share of the picture's area.
const tinyArea = 0.0002;

FoundSquares findSquares(FinderCv cv, CvMat photo) => _Finder(cv).run(photo);

/// A finder that keeps what it read of the last photo it was given, so a tap on that photo can be snapped to the
/// square around it afterwards.
class SquareFinder {
  SquareFinder(FinderCv cv) : _f = _Finder(cv);
  final _Finder _f;
  bool _ready = false;

  FoundSquares find(CvMat photo) {
    final found = _f.run(photo);
    _ready = found.side > 0;
    return found;
  }

  /// The best-supported square near a tap at [x], [y] (working pixels), as [_Finder._verify] judges one, or null
  /// when nothing around the tap looks like a square (or the last photo had no common size).
  Float32List? snap(double x, double y) => _ready ? _f.snap(x, y) : null;
}

class _Cand {
  _Cand(this.area, this.q, this.strong);
  final double area;
  final Int32List q;
  final bool strong;
}

class _Group {
  _Group(this.q, this.pixels, this.strong) : all = [q];
  final Int32List q;
  final int pixels;
  final List<Int32List> all;
  bool strong;
}

/// Pixel box, inclusive.
typedef _Box = ({int x0, int y0, int x1, int y1});

class _Finder {
  _Finder(this.cv);
  final FinderCv cv;
  late int w, h;
  late double side;
  late Float32List gx, gy;
  late Uint8List edgeOn, labBytes;
  late Float64List gLength;

  FoundSquares run(CvMat photo) {
    final clock = Stopwatch()..start();
    _tiny = 0;
    final scale = workLongSide / math.max(photo.rows, photo.cols);
    final img = cv.resizeArea(photo, scale);
    h = img.rows;
    w = img.cols;
    final blur = cv.gaussianBlur(img, 5);
    final lab = cv.cvtColor(blur, CvColour.bgrToLab);
    final channels = [...cv.split(blur), ...cv.split(lab)];

    // ---- 1. Outlines.
    final cands = <_Cand>[];
    for (final ch in channels) {
      for (var t = 0; t < 255; t += 26) {
        if (t == 0) {
          final e = cv.canny(ch, 30, 90);
          _collect(cv.dilate(e), 0, 0, cands);
          e.dispose();
        } else {
          _collect(cv.threshold(ch, t.toDouble()), 0, 0, cands);
        }
      }
      for (final bs in const [51, 101]) {
        _collect(cv.adaptiveThreshold(ch, bs), 0, 0, cands);
      }
    }
    for (final k in const [200.0, 500.0]) {
      _regions(cv.graphSegmentation(blur, 0.8, k, (0.001 * h * w).toInt()), cands);
    }
    for (final c in channels) {
      c.dispose();
    }
    final peak = _commonArea([for (final c in cands) c.area]);
    final sized = [
      for (final c in cands)
        if (0.5 * peak < c.area && c.area < 1.8 * peak) c,
    ];
    // Largest first; equal areas keep the order they were found in.
    final order = List.generate(sized.length, (i) => i)
      ..sort((a, b) {
        final d = sized[b].area.compareTo(sized[a].area);
        return d != 0 ? d : a - b;
      });
    final groups = <_Group>[];
    for (final i in order) {
      final c = sized[i];
      final pixels = _pixels(c.q);
      _Group? into;
      for (final g in groups) {
        final inter = _overlap(c.q, g.q);
        if (inter == 0) continue;
        final union = pixels + g.pixels - inter;
        if (inter / math.max(1, union) > 0.5 || inter / math.max(1, math.min(pixels, g.pixels)) > 0.8) {
          into = g;
          break;
        }
      }
      if (into != null) {
        into.all.add(c.q);
        into.strong = into.strong || c.strong;
      } else {
        groups.add(_Group(c.q, pixels, c.strong));
      }
    }
    final outline = <Float32List>[];
    for (final g in groups) {
      if (g.all.length < 2 && !g.strong) continue; // seen once and only roughly square
      final qs = [for (final q in g.all) _ordered(q)];
      outline.add(
        Float32List.fromList([
          for (var k = 0; k < 8; k++) _median([for (final q in qs) q[k]]),
        ]),
      );
    }
    final outlineMs = clock.elapsedMilliseconds;

    // ---- 2. Hypothesise and verify, from line segments.
    side = outline.isEmpty ? 0 : _median([for (final q in outline) _meanSide(q)]);
    final gray = cv.cvtColor(blur, CvColour.bgrToGray);
    final grayF = cv.toFloat(gray);
    var sx = cv.sobel(grayF, 1, 0), sy = cv.sobel(grayF, 0, 1);
    final labF = cv.toFloat(lab);
    final labCh = cv.split(labF);
    for (final ch in labCh.skip(1)) {
      // Colour edges too: a dark green next to a dark blue has little grey-level edge.
      final cx = cv.sobel(ch, 1, 0), cy = cv.sobel(ch, 0, 1);
      final nx = cv.addWeighted(sx, 1, cx, 0.7), ny = cv.addWeighted(sy, 1, cy, 0.7);
      for (final m in [sx, sy, cx, cy]) {
        m.dispose();
      }
      sx = nx;
      sy = ny;
    }
    final mag = cv.magnitude(sx, sy);
    gx = cv.floats(sx);
    gy = cv.floats(sy);
    final magF = cv.floats(mag);
    final cut = _percentile(magF, 80);
    edgeOn = Uint8List(magF.length);
    gLength = Float64List(magF.length);
    for (var i = 0; i < magF.length; i++) {
      if (magF[i] > cut) {
        edgeOn[i] = 1;
        final a = gx[i], b = gy[i];
        gLength[i] = math.sqrt(a * a + b * b) + 1e-6;
      }
    }
    labBytes = cv.bytes(lab);
    for (final m in [grayF, sx, sy, labF, mag, ...labCh]) {
      m.dispose();
    }

    final found = cv.zeros(w, h);
    for (final q in outline) {
      cv.fillPoly(found, _trunc(q), 1);
    }
    final lines = <Float32List>[];
    if (side > 0) {
      final foundBefore = cv.bytes(found);
      final segs = cv.lineSegments(gray);
      final best = <({double v, Float32List q})>[];
      for (var s = 0; s + 3 < segs.length; s += 4) {
        final x1 = segs[s], y1 = segs[s + 1], x2 = segs[s + 2], y2 = segs[s + 3];
        final len = _hypot(x2 - x1, y2 - y1);
        if (len < 0.45 * side) continue;
        final ang = math.atan2(y2 - y1, x2 - x1);
        final dx = math.cos(ang), dy = math.sin(ang), nx = -dy, ny = dx;
        // A square with this segment on one side: anchored at either end, on either side of it; a long
        // segment is the side of several squares in a row.
        final anchors = <(double, double, double, double)>[(x1, y1, dx, dy), (x2, y2, -dx, -dy)];
        for (var k = 1; (k + 0.5) * side < len; k++) {
          anchors.add((x1 + dx * k * side, y1 + dy * k * side, dx, dy));
        }
        for (final (ax, ay, ddx, ddy) in anchors) {
          for (final sgn in const [1, -1]) {
            final cx = ax + ddx * side / 2 + sgn * nx * side / 2, cy = ay + ddy * side / 2 + sgn * ny * side / 2;
            final hit = _verify(cx, cy, ang, foundBefore);
            if (hit != null) best.add(hit);
          }
        }
      }
      final byScore = List.generate(best.length, (i) => i)
        ..sort((a, b) {
          final d = best[b].v.compareTo(best[a].v);
          return d != 0 ? d : a - b;
        });
      for (final i in byScore) {
        final q = best[i].q, qi = _trunc(q);
        final box = _clip(_boxOf(qi));
        if (box != null) {
          final bw = box.x1 - box.x0 + 1, bh = box.y1 - box.y0 + 1;
          final m = cv.zeros(bw, bh);
          cv.fillPoly(m, qi, 1, dx: box.x0, dy: box.y0);
          final part = cv.roi(found, box.x0, box.y0, bw, bh);
          final both = cv.bitwiseAnd(m, part);
          final over = cv.countNonZero(both), all = cv.countNonZero(m);
          for (final x in [m, part, both]) {
            x.dispose();
          }
          if (over > 0.25 * all) continue;
        }
        if (_contrastSides(q) < 3) continue;
        lines.add(q);
        cv.fillPoly(found, qi, 1);
      }
    }
    found.dispose();
    gray.dispose();
    final kept = <Float32List>[];
    var outlineDropped = 0;
    for (final q in outline) {
      if (_contrastSides(q) >= 3) {
        kept.add(q);
      } else {
        outlineDropped++;
      }
    }
    kept.addAll(lines);
    // Cloth inside and the same cloth around it: floor, not a square (the false wood square measured 0.47,
    // real squares 0.53 and up).
    final squares = <Float32List>[];
    for (final q in kept) {
      if (_ringDistance(q, lab) >= 0.5) squares.add(q);
    }
    final linesMs = clock.elapsedMilliseconds - outlineMs;
    final checked = squares.length;
    if (side > 0) squares.addAll(_panels(squares));
    for (final m in [img, blur, lab]) {
      m.dispose();
    }
    return FoundSquares(
      w,
      h,
      scale,
      side,
      squares,
      lines.length,
      outlineDropped,
      kept.length - checked,
      outlineMs,
      linesMs,
      squares.length - checked,
      clock.elapsedMilliseconds - outlineMs - linesMs,
      _tiny,
    );
  }

  int _tiny = 0;

  /// Tap to add (squares.py's tap section): square centres within 0.3 of a side of the tap, every turn from 0 to 85
  /// degrees in 5-degree steps, sizes 0.8 to 1.2; the best supported with at least 3 sides on an edge, if it scores
  /// 0.4 or more.
  Float32List? snap(double x, double y) {
    var top = -1.0;
    late double bx, by, ba, bs;
    for (var i = 0; i < 7; i++) {
      for (var j = 0; j < 7; j++) {
        final cx = x + (-0.3 + 0.1 * i) * side, cy = y + (-0.3 + 0.1 * j) * side;
        for (var a = 0; a < 90; a += 5) {
          final ang = a * math.pi / 180;
          for (final sc in const [0.8, 0.9, 1.0, 1.1, 1.2]) {
            final (sup, mid, on) = _support(cx, cy, ang, sc);
            final v = sup - mid;
            if (v > top && on >= 3) {
              top = v;
              (bx, by, ba, bs) = (cx, cy, ang, sc);
            }
          }
        }
      }
    }
    return top >= 0.4 ? _squareAt(bx, by, ba, bs) : null;
  }

  /// Step 4: the squares missing inside sewn panels, from the squares already found ([anchors]).
  List<Float32List> _panels(List<Float32List> anchors) {
    final n = anchors.length;
    final cs = [for (final q in anchors) _centre(q)];
    final sides = [for (final q in anchors) _meanSide(q)];
    List<_Vec> edgesOf(Float32List q) => [
      for (var i = 0; i < 4; i++)
        (q[2 * ((i + 1) % 4)] - q[2 * i].toDouble(), q[2 * ((i + 1) % 4) + 1] - q[2 * i + 1].toDouble()),
    ];
    final edges = [for (final q in anchors) edgesOf(q)];
    // Neighbours: a square whose centre is one step (across, down or diagonal) of this square's own sides away,
    // within 0.2 of a side, turned within 10 degrees, and no more than 1.25 times larger or smaller.
    final near = List.generate(n, (_) => <int>[]);
    for (var m = 0; m < n; m++) {
      final (um, vm) = _aligned(edges[m], (1, 0));
      for (var k = 0; k < n; k++) {
        if (k == m || math.max(sides[k], sides[m]) / math.min(sides[k], sides[m]) > 1.25) continue;
        final (uk, _) = _aligned(edges[k], um);
        if (math.atan2(um.$1 * uk.$2 - um.$2 * uk.$1, um.$1 * uk.$1 + um.$2 * uk.$2).abs() > 10 * math.pi / 180) continue;
        final d = (cs[k].$1 - cs[m].$1, cs[k].$2 - cs[m].$2);
        final (a, b) = _solve(um, vm, d);
        final ra = _roundEven(a), rb = _roundEven(b);
        if ((ra == 0 && rb == 0) || math.max(ra.abs(), rb.abs()) > 1) continue;
        final rx = d.$1 - ra * um.$1 - rb * vm.$1, ry = d.$2 - ra * um.$2 - rb * vm.$2;
        if (_hypot(rx, ry) / sides[m] < 0.2) near[m].add(k);
      }
    }
    // Panels: groups of 3 or more joined by neighbours who count each other.
    final seen = List.filled(n, false);
    final panels = <List<int>>[];
    for (var s = 0; s < n; s++) {
      if (seen[s]) continue;
      final stack = [s], group = <int>[];
      seen[s] = true;
      while (stack.isNotEmpty) {
        final m = stack.removeLast();
        group.add(m);
        for (final k in near[m]) {
          if (near[k].contains(m) && !seen[k]) {
            seen[k] = true;
            stack.add(k);
          }
        }
      }
      if (group.length >= 3) panels.add(group);
    }
    final found = cv.zeros(w, h);
    for (final q in anchors) {
      cv.fillPoly(found, _trunc(q), 1);
    }
    bool isFound(double x, double y) {
      final at = cv.roi(found, x.toInt(), y.toInt(), 1, 1);
      final hit = cv.countNonZero(at) > 0;
      at.dispose();
      return hit;
    }

    final added = <Float32List>[];
    for (final group in panels) {
      // Grid places, walking the panel from its best-joined square in each square's own frame.
      final inGroup = group.toSet();
      var seed = group.first;
      for (final m in group) {
        if (near[m].length > near[seed].length) seed = m;
      }
      final place = <int, (int, int)>{seed: (0, 0)};
      final frame = <int, (_Vec, _Vec)>{seed: _aligned(edges[seed], (1, 0))};
      final taken = <(int, int), int>{(0, 0): seed};
      final queue = [seed];
      for (var qi = 0; qi < queue.length; qi++) {
        final m = queue[qi];
        final (um, vm) = frame[m]!;
        for (final k in near[m]) {
          if (place.containsKey(k) || !inGroup.contains(k)) continue;
          final (a, b) = _solve(um, vm, (cs[k].$1 - cs[m].$1, cs[k].$2 - cs[m].$2));
          final cell = (place[m]!.$1 + _roundEven(a), place[m]!.$2 + _roundEven(b));
          if (taken.containsKey(cell)) continue;
          place[k] = cell;
          taken[cell] = k;
          frame[k] = _aligned(edges[k], um);
          queue.add(k);
        }
      }
      final cols = {for (final p in place.values) p.$1}, rows = {for (final p in place.values) p.$2};
      if (cols.length < 2 || rows.length < 2) continue;
      final i0 = cols.reduce(math.min), i1 = cols.reduce(math.max);
      final j0 = rows.reduce(math.min), j1 = rows.reduce(math.max);
      final geo = <(int, int), (_Vec, _Vec, _Vec)>{
        for (final MapEntry(key: cell, value: k) in taken.entries) cell: (cs[k], frame[k]!.$1, frame[k]!.$2),
      };
      var frontier = taken.keys.toList();
      while (frontier.isNotEmpty) {
        final next = <(int, int)>[];
        for (final (i, j) in frontier) {
          for (final (di, dj) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final cell = (i + di, j + dj);
            if (geo.containsKey(cell) || next.contains(cell)) continue;
            if (cell.$1 < i0 || cell.$1 > i1 || cell.$2 < j0 || cell.$2 > j1) continue;
            // Where its found neighbours (all 8) say it is: the mean of each one's step to it.
            var px = 0.0, py = 0.0, ux = 0.0, uy = 0.0, vx = 0.0, vy = 0.0, count = 0;
            for (final (si, sj) in const [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]) {
              final g = geo[(cell.$1 - si, cell.$2 - sj)];
              if (g == null) continue;
              final (c, u, v) = g;
              px += c.$1 + si * u.$1 + sj * v.$1;
              py += c.$2 + si * u.$2 + sj * v.$2;
              ux += u.$1;
              uy += u.$2;
              vx += v.$1;
              vy += v.$2;
              count++;
            }
            if (count == 0) continue;
            px /= count;
            py /= count;
            ux /= count;
            uy /= count;
            vx /= count;
            vy /= count;
            if (!(px >= 0 && px < w && py >= 0 && py < h) || isFound(px, py)) continue;
            final ang = math.atan2(uy, ux);
            final size = (2 * _hypot(ux, uy) + 2 * _hypot(vx, vy)) / 4;
            var top = double.negativeInfinity;
            late double bx, by, ba, bs, bSup, bMid;
            for (final fx in const [-0.12, -0.06, 0.0, 0.06, 0.12]) {
              for (final fy in const [-0.12, -0.06, 0.0, 0.06, 0.12]) {
                for (final da in const [-0.06, 0.0, 0.06]) {
                  for (final sc in const [0.92, 1.0, 1.08]) {
                    final (sup, mid, _) = _support(px + fx * size, py + fy * size, ang + da, size * sc / side);
                    if (sup - mid > top) {
                      top = sup - mid;
                      (bx, by, ba, bs, bSup, bMid) = (px + fx * size, py + fy * size, ang + da, size * sc, sup, mid);
                    }
                  }
                }
              }
            }
            if (bSup < 0.4 || bMid >= 0.5 * bSup) continue;
            final q = _squareAt(bx, by, ba, bs / side);
            added.add(q);
            cv.fillPoly(found, _trunc(q), 1);
            final d = (math.cos(ba) * bs, math.sin(ba) * bs);
            geo[cell] = ((bx, by), d, (-d.$2, d.$1));
            next.add(cell);
          }
        }
        frontier = next;
      }
    }
    found.dispose();
    return added;
  }

  /// The candidates among one binary picture's outlines; [ox], [oy] place the picture in the frame.
  void _collect(CvMat binary, int ox, int oy, List<_Cand> into) {
    final minArea = 0.0015 * h * w, maxArea = 0.2 * h * w, tinyMin = tinyArea * h * w;
    final contours = cv.findContours(binary);
    for (var i = 0; i < contours.length; i++) {
      // A polygon on a contour's points is no larger than their box: too small a box cannot hold a candidate.
      final p = contours.points(i);
      var x0 = p[0], x1 = p[0], y0 = p[1], y1 = p[1];
      for (var k = 2; k < p.length; k += 2) {
        x0 = math.min(x0, p[k]);
        x1 = math.max(x1, p[k]);
        y0 = math.min(y0, p[k + 1]);
        y1 = math.max(y1, p[k + 1]);
      }
      if ((x1 - x0) * (y1 - y0) < tinyMin) continue;
      final q = contours.approxPolyDP(i, 0.03 * contours.arcLength(i));
      if (q.length != 8) continue;
      final area = cv.contourArea(q);
      if (area < tinyMin || area > maxArea || !cv.isContourConvex(q)) continue;
      for (var k = 0; k < 8; k += 2) {
        q[k] += ox;
        q[k + 1] += oy;
      }
      var cosMax = 0.0;
      for (var k = 0; k < 4; k++) {
        cosMax = math.max(cosMax, _angleCos(q, k, (k + 1) % 4, (k + 2) % 4));
      }
      if (cosMax > 0.26) continue; // within about 15 degrees of 90
      final sides = [
        for (var k = 0; k < 4; k++) _dist(q[2 * k], q[2 * k + 1], q[2 * ((k + 1) % 4)], q[2 * ((k + 1) % 4) + 1]),
      ];
      final ratio = sides.reduce(math.max) / sides.reduce(math.min);
      if (ratio > 1.35) continue;
      if (area < minArea) {
        _tiny++;
        continue;
      }
      into.add(_Cand(area, q, cosMax < 0.12 && ratio < 1.2));
    }
    contours.dispose();
    binary.dispose();
  }

  /// The outlines of each colour region, opened (5 x 5), each in its own box.
  void _regions(Int32List labels, List<_Cand> into) {
    final boxes = <int, List<int>>{};
    for (var y = 0, i = 0; y < h; y++) {
      for (var x = 0; x < w; x++, i++) {
        final b = boxes[labels[i]];
        if (b == null) {
          boxes[labels[i]] = [x, y, x, y];
        } else {
          if (x < b[0]) b[0] = x;
          if (x > b[2]) b[2] = x;
          b[3] = y;
        }
      }
    }
    // 4 pixels of other regions around each box: opening reaches 2, so the box's own edge changes nothing.
    // At the photo's edge the box stops there, as the whole picture does.
    for (final v in boxes.keys.toList()..sort()) {
      final b = boxes[v]!;
      final x0 = math.max(0, b[0] - 4), y0 = math.max(0, b[1] - 4);
      final x1 = math.min(w - 1, b[2] + 4), y1 = math.min(h - 1, b[3] + 4);
      final bw = x1 - x0 + 1, bh = y1 - y0 + 1;
      final mask = Uint8List(bw * bh);
      for (var y = 0; y < bh; y++) {
        final row = (y + y0) * w + x0;
        for (var x = 0; x < bw; x++) {
          if (labels[row + x] == v) mask[y * bw + x] = 255;
        }
      }
      final m = cv.fromBytes(mask, bw, bh);
      _collect(cv.open(m, 5), x0, y0, into);
      m.dispose();
    }
  }

  /// The best square near a hypothesis, or null: small shifts, turns and sizes, scored by edge support.
  ({double v, Float32List q})? _verify(double cx, double cy, double ang, Uint8List foundBefore) {
    final fx = cx.clamp(0, w - 1).toInt(), fy = cy.clamp(0, h - 1).toInt();
    if (foundBefore[fy * w + fx] != 0) return null;
    var top = -1.0;
    late double bx, by, ba, bs, bSup, bMid;
    late int bOn;
    for (final dx in const [-6, -3, 0, 3, 6]) {
      for (final dy in const [-6, -3, 0, 3, 6]) {
        for (final da in const [-0.08, 0.0, 0.08]) {
          for (final sc in const [0.9, 1.0, 1.1]) {
            // Cut squares are not all exactly one size.
            final (sup, mid, on) = _support(cx + dx, cy + dy, ang + da, sc);
            final v = sup - mid;
            if (v > top) {
              top = v;
              (bx, by, ba, bs, bSup, bMid, bOn) = (cx + dx, cy + dy, ang + da, sc, sup, mid, on);
            }
          }
        }
      }
    }
    if (top == -1.0) return null;
    // A print has edges inside too; a seam through the middle has more.
    if (bSup >= 0.6 && bOn >= 3 && bMid < 0.5 * bSup) return (v: top, q: _squareAt(bx, by, ba, bs));
    return null;
  }

  static final _t = Float64List.fromList(_linspace(-0.85, 0.85, 24));

  /// How much of the square's sides (centre, turn, size) lies on an edge running across that side, judged
  /// on its best 3 sides (one may be hidden under another piece); the same for its two mid-lines; and how
  /// many sides are there. The search calls this some 200,000 times a photo, so it makes no lists.
  (double, double, int) _support(double cx, double cy, double ang, double sc) {
    final dx = math.cos(ang), dy = math.sin(ang), nx = -dy, ny = dx;
    final hh = side * sc / 2;
    final s0 = _count(cx + -1 * hh * nx, cy + -1 * hh * ny, dx, dy, nx, ny, hh);
    final s1 = _count(cx + 1 * hh * nx, cy + 1 * hh * ny, dx, dy, nx, ny, hh);
    final s2 = _count(cx + -1 * hh * dx, cy + -1 * hh * dy, nx, ny, dx, dy, hh);
    final s3 = _count(cx + 1 * hh * dx, cy + 1 * hh * dy, nx, ny, dx, dy, hh);
    final mid = _count(cx, cy, dx, dy, nx, ny, hh) + _count(cx, cy, nx, ny, dx, dy, hh);
    final least = math.min(math.min(s0, s1), math.min(s2, s3));
    final n = _t.length;
    final there = (s0 / n >= 0.5 ? 1 : 0) + (s1 / n >= 0.5 ? 1 : 0) + (s2 / n >= 0.5 ? 1 : 0) + (s3 / n >= 0.5 ? 1 : 0);
    return ((s0 + s1 + s2 + s3 - least) / (3 * n), mid / (2 * n), there);
  }

  /// How many of the sample points along a line (from [bx], [by] along [ax], [ay]) are on an edge across it.
  int _count(double bx, double by, double ax, double ay, double mx, double my, double hh) {
    var n = 0;
    final t = _t;
    for (var k = 0; k < t.length; k++) {
      final tt = t[k] * hh;
      if (_on(bx + tt * ax, by + tt * ay, mx, my)) n++;
    }
    return n;
  }

  /// A point on a strong edge whose direction is across the line (normal [mx], [my]).
  bool _on(double px, double py, double mx, double my) {
    if (!(px >= 0 && px < w && py >= 0 && py < h)) return false;
    var x = _roundEven(px), y = _roundEven(py);
    if (x > w - 1) x = w - 1;
    if (y > h - 1) y = h - 1;
    final i = y * w + x;
    if (edgeOn[i] == 0) return false;
    final a = gx[i], b = gy[i];
    return (a * mx + b * my).abs() / gLength[i] > 0.8;
  }

  Float32List _squareAt(double cx, double cy, double ang, double sc) {
    final dx = math.cos(ang), dy = math.sin(ang), nx = -dy, ny = dx, hh = side * sc / 2;
    return Float32List.fromList([
      cx - hh * dx - hh * nx,
      cy - hh * dy - hh * ny,
      cx + hh * dx - hh * nx,
      cy + hh * dy - hh * ny,
      cx + hh * dx + hh * nx,
      cy + hh * dy + hh * ny,
      cx - hh * dx + hh * nx,
      cy - hh * dy + hh * ny,
    ]);
  }

  /// How many of the square's sides have different cloth across them: a strip just inside against a strip
  /// just outside, CIELAB distance over 12.
  int _contrastSides(Float32List q) {
    final (cx, cy) = _centre(q);
    final ts = _linspace(0.2, 0.8, 12);
    var ok = 0;
    for (var i = 0; i < 4; i++) {
      final ax = q[2 * i], ay = q[2 * i + 1], bx = q[2 * ((i + 1) % 4)], by = q[2 * ((i + 1) % 4) + 1];
      var ox = (ax + bx) / 2 - cx, oy = (ay + by) / 2 - cy;
      final on = _hypot(ox, oy) + 1e-6;
      ox /= on;
      oy /= on;
      final inside = [0.0, 0.0, 0.0], outside = [0.0, 0.0, 0.0];
      for (final t in ts) {
        final lx = ax + t * (bx - ax), ly = ay + t * (by - ay);
        _addLab(inside, lx - ox * 0.08 * side, ly - oy * 0.08 * side);
        _addLab(outside, lx + ox * 0.08 * side, ly + oy * 0.08 * side);
      }
      final d0 = inside[0] - outside[0], d1 = inside[1] - outside[1], d2 = inside[2] - outside[2];
      if (math.sqrt(d0 * d0 + d1 * d1 + d2 * d2) / ts.length > 12) ok++;
    }
    return ok;
  }

  void _addLab(List<double> sum, double px, double py) {
    final i = (_roundEven(py).clamp(0, h - 1) * w + _roundEven(px).clamp(0, w - 1)) * 3;
    sum[0] += labBytes[i];
    sum[1] += labBytes[i + 1];
    sum[2] += labBytes[i + 2];
  }

  /// Colour-histogram distance (Bhattacharyya, a*b* and L* averaged) between the square's inner 70 % and
  /// a ring just outside it (1.08 to 1.3 times its size).
  double _ringDistance(Float32List q, CvMat lab) {
    final (cx, cy) = _centre(q);
    Int32List scaled(double k) => Int32List.fromList([
      for (var i = 0; i < 8; i += 2) ...[(cx + (q[i] - cx) * k).toInt(), (cy + (q[i + 1] - cy) * k).toInt()],
    ]);
    final inner = scaled(0.7), outer = scaled(1.3), hole = scaled(1.08);
    final box = _clip(_boxOf(outer));
    if (box == null) return 0;
    final bw = box.x1 - box.x0 + 1, bh = box.y1 - box.y0 + 1;
    final part = cv.roi(lab, box.x0, box.y0, bw, bh);
    final inM = cv.zeros(bw, bh), ringM = cv.zeros(bw, bh);
    cv.fillPoly(inM, inner, 1, dx: box.x0, dy: box.y0);
    cv.fillPoly(ringM, outer, 1, dx: box.x0, dy: box.y0);
    cv.fillPoly(ringM, hole, 0, dx: box.x0, dy: box.y0);
    Float32List norm(Float32List hist) {
      final s = math.max(hist.fold(0.0, (a, b) => a + b), 1.0);
      return Float32List.fromList([for (final v in hist) v / s]);
    }

    final ab = cv.compareHistBhattacharyya(
      norm(cv.calcHist(part, const [1, 2], inM, 16)),
      norm(cv.calcHist(part, const [1, 2], ringM, 16)),
    );
    final l = cv.compareHistBhattacharyya(
      norm(cv.calcHist(part, const [0], inM, 16)),
      norm(cv.calcHist(part, const [0], ringM, 16)),
    );
    for (final m in [part, inM, ringM]) {
      m.dispose();
    }
    return (ab + l) / 2;
  }

  /// Pixels a filled polygon covers in the frame.
  int _pixels(Int32List q) {
    final box = _clip(_boxOf(q));
    if (box == null) return 0;
    final m = cv.zeros(box.x1 - box.x0 + 1, box.y1 - box.y0 + 1);
    cv.fillPoly(m, q, 1, dx: box.x0, dy: box.y0);
    final n = cv.countNonZero(m);
    m.dispose();
    return n;
  }

  /// Pixels two filled polygons both cover, counted in the overlap of their boxes.
  int _overlap(Int32List a, Int32List b) {
    final ba = _boxOf(a), bb = _boxOf(b);
    final box = _clip((
      x0: math.max(ba.x0, bb.x0),
      y0: math.max(ba.y0, bb.y0),
      x1: math.min(ba.x1, bb.x1),
      y1: math.min(ba.y1, bb.y1),
    ));
    if (box == null) return 0;
    final bw = box.x1 - box.x0 + 1, bh = box.y1 - box.y0 + 1;
    final ma = cv.zeros(bw, bh), mb = cv.zeros(bw, bh);
    cv.fillPoly(ma, a, 1, dx: box.x0, dy: box.y0);
    cv.fillPoly(mb, b, 1, dx: box.x0, dy: box.y0);
    final both = cv.bitwiseAnd(ma, mb);
    final n = cv.countNonZero(both);
    for (final m in [ma, mb, both]) {
      m.dispose();
    }
    return n;
  }

  _Box? _clip(_Box b) {
    final x0 = math.max(0, b.x0), y0 = math.max(0, b.y0), x1 = math.min(w - 1, b.x1), y1 = math.min(h - 1, b.y1);
    return x0 > x1 || y0 > y1 ? null : (x0: x0, y0: y0, x1: x1, y1: y1);
  }
}

_Box _boxOf(Int32List q) {
  var x0 = q[0], x1 = q[0], y0 = q[1], y1 = q[1];
  for (var k = 2; k < q.length; k += 2) {
    x0 = math.min(x0, q[k]);
    x1 = math.max(x1, q[k]);
    y0 = math.min(y0, q[k + 1]);
    y1 = math.max(y1, q[k + 1]);
  }
  return (x0: x0, y0: y0, x1: x1, y1: y1);
}

typedef _Vec = (double, double);

/// Of a square's 4 sides, either way round, the one pointing most like [ref], and the side 90 degrees on from it
/// (down the picture when the first points right), as long.
(_Vec, _Vec) _aligned(List<_Vec> edges, _Vec ref) {
  _Vec? best;
  var bestCos = double.negativeInfinity;
  for (final e in edges) {
    for (final s in const [1, -1]) {
      final x = s * e.$1, y = s * e.$2;
      final cos = (x * ref.$1 + y * ref.$2) / (_hypot(x, y) + 1e-9);
      if (cos > bestCos) {
        bestCos = cos;
        best = (x, y);
      }
    }
  }
  final u = best!;
  return (u, (-u.$2, u.$1));
}

/// a and b with a * u + b * v = d.
(double, double) _solve(_Vec u, _Vec v, _Vec d) {
  final det = u.$1 * v.$2 - v.$1 * u.$2;
  return ((d.$1 * v.$2 - v.$1 * d.$2) / det, (u.$1 * d.$2 - d.$1 * u.$2) / det);
}

/// Corners to whole pixels, toward zero (numpy's astype(int32)).
Int32List _trunc(Float32List q) => Int32List.fromList([for (final v in q) v.toInt()]);

(double, double) _centre(Float32List q) => ((q[0] + q[2] + q[4] + q[6]) / 4, (q[1] + q[3] + q[5] + q[7]) / 4);

double _meanSide(Float32List q) {
  var s = 0.0;
  for (var k = 0; k < 4; k++) {
    s += _dist(q[2 * k], q[2 * k + 1], q[2 * ((k + 1) % 4)], q[2 * ((k + 1) % 4) + 1]);
  }
  return s / 4;
}

double _angleCos(Int32List q, int i0, int i1, int i2) {
  final d1x = (q[2 * i0] - q[2 * i1]).toDouble(), d1y = (q[2 * i0 + 1] - q[2 * i1 + 1]).toDouble();
  final d2x = (q[2 * i2] - q[2 * i1]).toDouble(), d2y = (q[2 * i2 + 1] - q[2 * i1 + 1]).toDouble();
  return (d1x * d2x + d1y * d2y).abs() / math.sqrt((d1x * d1x + d1y * d1y) * (d2x * d2x + d2y * d2y));
}

double _dist(num ax, num ay, num bx, num by) => _hypot((ax - bx).toDouble(), (ay - by).toDouble());

double _hypot(double x, double y) => math.sqrt(x * x + y * y);

/// The corners from the top-left one (smallest x + y), in angle order round the centre.
List<double> _ordered(Int32List q) {
  final cx = (q[0] + q[2] + q[4] + q[6]) / 4, cy = (q[1] + q[3] + q[5] + q[7]) / 4;
  final idx = [0, 1, 2, 3]
    ..sort(
      (a, b) => math.atan2(q[2 * a + 1] - cy, q[2 * a] - cx).compareTo(math.atan2(q[2 * b + 1] - cy, q[2 * b] - cx)),
    );
  var start = 0;
  for (var k = 1; k < 4; k++) {
    if (q[2 * idx[k]] + q[2 * idx[k] + 1] < q[2 * idx[start]] + q[2 * idx[start] + 1]) start = k;
  }
  return [
    for (var k = 0; k < 4; k++) ...[q[2 * idx[(start + k) % 4]].toDouble(), q[2 * idx[(start + k) % 4] + 1].toDouble()],
  ];
}

double _median(List<double> v) {
  final s = [...v]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// numpy's linspace.
List<double> _linspace(double a, double b, int n) {
  final step = (b - a) / (n - 1);
  return [for (var i = 0; i < n; i++) i == n - 1 ? b : i * step + a];
}

/// numpy's round: halves to even.
int _roundEven(double x) {
  final f = x.floorToDouble(), d = x - f;
  if (d != 0.5) return d < 0.5 ? f.toInt() : f.toInt() + 1;
  final r = d < 0.5
      ? f
      : d > 0.5
      ? f + 1
      : (f % 2 == 0 ? f : f + 1);
  return r.toInt();
}

/// numpy's percentile, linear.
double _percentile(Float32List v, double p) {
  final s = Float32List.fromList(v)..sort();
  final at = p / 100 * (s.length - 1);
  final lo = at.floor(), t = at - lo;
  if (lo + 1 >= s.length) return s[lo];
  final a = s[lo].toDouble(), b = s[lo + 1].toDouble();
  return t >= 0.5 ? b - (b - a) * (1 - t) : a + (b - a) * t;
}

/// The common size: the middle of the fullest of 30 bins of log area (numpy's histogram), as an area.
double _commonArea(List<double> areas) {
  if (areas.isEmpty) return 0;
  final la = [for (final a in areas) math.log(a)];
  var first = la.reduce(math.min), last = la.reduce(math.max);
  if (first == last) {
    first -= 0.5;
    last += 0.5;
  }
  const n = 30;
  final edges = _linspace(first, last, n + 1);
  final counts = List.filled(n, 0);
  for (final v in la) {
    var i = ((v - first) / (last - first) * n).toInt();
    if (i == n) i--;
    if (v < edges[i]) i--;
    if (v >= edges[i + 1] && i != n - 1) i++;
    counts[i]++;
  }
  var best = 0;
  for (var i = 1; i < n; i++) {
    if (counts[i] > counts[best]) best = i;
  }
  return math.exp((edges[best] + edges[best + 1]) / 2);
}
