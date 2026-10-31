/* What a template asks of each zone of the panel. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'geometry.dart';
import 'js_math.dart';
import 'score.dart';

/* A value for the square at row r, column c of a board of size g. */
typedef CellFn = double Function(int r, int c, BoardSize g);

class PoolStats {
  const PoolStats(this.lmin, this.lmax, this.emin, this.emax);
  final double lmin, lmax, emin, emax;
}

sealed class LRule {
  const LRule(this.weight);
  final double weight;
}
class LFromT extends LRule { const LFromT(this.t, super.weight); final CellFn t; }
class LAt extends LRule { const LAt(this.at, super.weight); final double Function(int r, int c, BoardSize g, PoolStats s) at; }

class ZoneRules {
  const ZoneRules({this.l, this.edge, this.hue, this.family, this.colour, this.orient});
  final LRule? l;
  final ({CellFn t, double weight})? edge;
  final ({CellFn angle, double weight})? hue;
  final ({double weight})? family;
  final ({double hue, double weight})? colour;
  final ({CellFn angle, double weight})? orient;
}

class LayoutSpec {
  const LayoutSpec({required this.zones, required this.rules, required this.within, this.boundary,
      required this.perimeter, required this.balance, this.ground});
  final Uint8List zones;
  /* A drawing that keeps its own shape on other sizes (owner, 31 Oct 2026): the zone of its plain ground. */
  final int? ground;
  final Map<int, ZoneRules> rules;
  final SeamRule within;
  final SeamRule? boundary;
  final bool perimeter, balance;

  /* The zones on a board of size g. The map is drawn for Level 1. On any other size each square takes the zone of the
     Level 1 square under its centre (nearest neighbour): a map with a `ground` is scaled the same both ways and
     centred, keeping its shape, the rest of the board its ground; one without stretches to fill the board. */
  Uint8List zonesOn(BoardSize g) => g == level1 ? zones
      : ground == null ? stretchZones(zones, level1, g) : fitZones(zones, level1, g, ground!);
}

Uint8List stretchZones(Uint8List zones, BoardSize from, BoardSize to) {
  final out = Uint8List(to.rows * to.cols);
  for (var r = 0; r < to.rows; r++) {
    final sr = ((r + 0.5) * from.rows / to.rows).floor();
    for (var c = 0; c < to.cols; c++) {
      out[r * to.cols + c] = zones[sr * from.cols + ((c + 0.5) * from.cols / to.cols).floor()];
    }
  }
  return out;
}

/* The map scaled evenly to fit inside `to`, centred; the squares round it are `ground`. */
Uint8List fitZones(Uint8List zones, BoardSize from, BoardSize to, int ground) {
  final s = math.min(to.rows / from.rows, to.cols / from.cols);
  final top = (to.rows - from.rows * s) / 2, left = (to.cols - from.cols * s) / 2;
  final out = Uint8List(to.rows * to.cols)..fillRange(0, to.rows * to.cols, ground);
  for (var r = 0; r < to.rows; r++) {
    final sr = ((r + 0.5 - top) / s).floor();
    if (sr < 0 || sr >= from.rows) continue;
    for (var c = 0; c < to.cols; c++) {
      final sc = ((c + 0.5 - left) / s).floor();
      if (sc >= 0 && sc < from.cols) out[r * to.cols + c] = zones[sr * from.cols + sc];
    }
  }
  return out;
}

Uint8List zoneMap(List<String> rows) {
  final g = level1;
  if (rows.length != g.rows || rows.any((r) => r.length != g.cols)) throw ArgumentError('a zone map is ${g.rows} rows of ${g.cols}');
  final z = Uint8List(cells);
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < g.cols; c++) {
      final ch = rows[r][c];
      if (ch != '.' && !RegExp(r'^[0-9]$').hasMatch(ch)) throw ArgumentError("zone map: '$ch' is not '.' or a digit");
      z[r * g.cols + c] = ch == '.' ? 0 : int.parse(ch);
    }
  }
  return z;
}

Float64List fieldCells(CellFn f, BoardSize g) {
  final out = Float64List(g.rows * g.cols);
  for (var r = 0; r < g.rows; r++) { for (var c = 0; c < g.cols; c++) { out[r * g.cols + c] = f(r, c, g); } }
  return out;
}

abstract final class Ramps {
  static double gradient(int r, int c, BoardSize g, PoolStats s) =>
      s.lmax + (s.lmin - s.lmax) * ((r / (g.rows - 1) + c / (g.cols - 1)) / 2);
  static double gradientT(int r, int c, BoardSize g) => 1 - (r / (g.rows - 1) + c / (g.cols - 1)) / 2;
  static double medallion(int r, int c, BoardSize g) {
    final cr = (g.rows - 1) / 2, cc = (g.cols - 1) / 2;
    return jsHypot2(r - cr, c - cc) / jsHypot2(cr, cc);
  }
  static double wave(int r, int c, BoardSize g) => const [1.0, 0.5, 0.0, 1.0][((r + c) % 8) ~/ 2];
  static double framed(int r, int c, BoardSize g) =>
      math.min(math.min(r, g.rows - 1 - r), math.min(c, g.cols - 1 - c)) / math.min((g.rows - 1) / 2, (g.cols - 1) / 2);
  static double cross(int r, int c, BoardSize g) {
    final x = c / (g.cols - 1), y = r / (g.rows - 1);
    return math.min(1.0, math.min((x - y).abs(), (x + y - 1).abs()) / 0.4);
  }
  static double printMedallion(int r, int c, BoardSize g) {
    final cr = (g.rows - 1) / 2, cc = (g.cols - 1) / 2;
    return 1 - jsHypot2(r - cr, c - cc) / jsHypot2(cr, cc);
  }
  static double spectrumHue(int r, int c, BoardSize g) => 200 - 180 * (c / (g.cols - 1));
}
