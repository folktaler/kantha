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
}

FoundSquares findSquares(FinderCv cv, CvMat photo) => _Finder(cv).run(photo);

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

  FoundSquares run(CvMat photo) {
    final clock = Stopwatch()..start();
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
    for (var i = 0; i < magF.length; i++) {
      if (magF[i] > cut) edgeOn[i] = 1;
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
      kept.length - squares.length,
      outlineMs,
      clock.elapsedMilliseconds - outlineMs,
    );
  }

  /// The candidates among one binary picture's outlines; [ox], [oy] place the picture in the frame.
  void _collect(CvMat binary, int ox, int oy, List<_Cand> into) {
    final minArea = 0.0015 * h * w, maxArea = 0.2 * h * w;
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
      if ((x1 - x0) * (y1 - y0) < minArea) continue;
      final q = contours.approxPolyDP(i, 0.03 * contours.arcLength(i));
      if (q.length != 8) continue;
      final area = cv.contourArea(q);
      if (area < minArea || area > maxArea || !cv.isContourConvex(q)) continue;
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

  static final _t = _linspace(-0.85, 0.85, 24);

  /// How much of the square's sides (centre, turn, size) lies on an edge running across that side, judged
  /// on its best 3 sides (one may be hidden under another piece); the same for its two mid-lines; and how
  /// many sides are there.
  (double, double, int) _support(double cx, double cy, double ang, double sc) {
    final dx = math.cos(ang), dy = math.sin(ang), nx = -dy, ny = dx;
    final hh = side * sc / 2;
    int count(double bx, double by, double ax, double ay, double mx, double my) {
      var n = 0;
      for (final t in _t) {
        final tt = t * hh;
        if (_on(bx + tt * ax, by + tt * ay, mx, my)) n++;
      }
      return n;
    }

    final on = [
      count(cx + -1 * hh * nx, cy + -1 * hh * ny, dx, dy, nx, ny),
      count(cx + 1 * hh * nx, cy + 1 * hh * ny, dx, dy, nx, ny),
      count(cx + -1 * hh * dx, cy + -1 * hh * dy, nx, ny, dx, dy),
      count(cx + 1 * hh * dx, cy + 1 * hh * dy, nx, ny, dx, dy),
    ];
    final mid = count(cx, cy, dx, dy, nx, ny) + count(cx, cy, nx, ny, dx, dy);
    final sorted = [...on]..sort();
    return (
      (sorted[1] + sorted[2] + sorted[3]) / (3 * _t.length),
      mid / (2 * _t.length),
      on.where((n) => n / _t.length >= 0.5).length,
    );
  }

  /// A point on a strong edge whose direction is across the line (normal [mx], [my]).
  bool _on(double px, double py, double mx, double my) {
    if (!(px >= 0 && px < w && py >= 0 && py < h)) return false;
    final i = _roundEven(py).clamp(0, h - 1) * w + _roundEven(px).clamp(0, w - 1);
    if (edgeOn[i] == 0) return false;
    final a = gx[i], b = gy[i];
    return (a * mx + b * my).abs() / (math.sqrt(a * a + b * b) + 1e-6) > 0.8;
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
