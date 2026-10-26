/* What a template asks of each zone of the panel. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'geometry.dart';
import 'js_math.dart';
import 'score.dart';

typedef CellFn = double Function(int r, int c);

class PoolStats {
  const PoolStats(this.lmin, this.lmax, this.emin, this.emax);
  final double lmin, lmax, emin, emax;
}

sealed class LRule {
  const LRule(this.weight);
  final double weight;
}
class LFromT extends LRule { const LFromT(this.t, super.weight); final CellFn t; }
class LAt extends LRule { const LAt(this.at, super.weight); final double Function(int r, int c, PoolStats s) at; }

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
      required this.perimeter, required this.balance});
  final Uint8List zones;
  final Map<int, ZoneRules> rules;
  final SeamRule within;
  final SeamRule? boundary;
  final bool perimeter, balance;
}

int get _rows => a4.rows;
int get _cols => a4.cols;

Uint8List zoneMap(List<String> rows) {
  if (rows.length != _rows || rows.any((r) => r.length != _cols)) throw ArgumentError('a zone map is $_rows rows of $_cols');
  final z = Uint8List(cells);
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < _cols; c++) {
      final ch = rows[r][c];
      if (ch != '.' && !RegExp(r'^[0-9]$').hasMatch(ch)) throw ArgumentError("zone map: '$ch' is not '.' or a digit");
      z[r * _cols + c] = ch == '.' ? 0 : int.parse(ch);
    }
  }
  return z;
}

Float64List fieldCells(CellFn f) {
  final out = Float64List(cells);
  for (var r = 0; r < _rows; r++) { for (var c = 0; c < _cols; c++) { out[r * _cols + c] = f(r, c); } }
  return out;
}

abstract final class Ramps {
  static double gradient(int r, int c, PoolStats s) =>
      s.lmax + (s.lmin - s.lmax) * ((r / (_rows - 1) + c / (_cols - 1)) / 2);
  static double gradientT(int r, int c) => 1 - (r / (_rows - 1) + c / (_cols - 1)) / 2;
  static double medallion(int r, int c) {
    final cr = (_rows - 1) / 2, cc = (_cols - 1) / 2;
    return jsHypot2(r - cr, c - cc) / jsHypot2(cr, cc);
  }
  static double wave(int r, int c) => const [1.0, 0.5, 0.0, 1.0][((r + c) % 8) ~/ 2];
  static double framed(int r, int c) =>
      math.min(math.min(r, _rows - 1 - r), math.min(c, _cols - 1 - c)) / math.min((_rows - 1) / 2, (_cols - 1) / 2);
  static double cross(int r, int c) {
    final x = c / (_cols - 1), y = r / (_rows - 1);
    return math.min(1.0, math.min((x - y).abs(), (x + y - 1).abs()) / 0.4);
  }
  static double printMedallion(int r, int c) {
    final cr = (_rows - 1) / 2, cc = (_cols - 1) / 2;
    return 1 - jsHypot2(r - cr, c - cc) / jsHypot2(cr, cc);
  }
  static double spectrumHue(int r, int c) => 200 - 180 * (c / (_cols - 1));
}
