import 'js_math.dart';

const double patchCm = 4, cutCm = patchCm + 2;
const int maxLongSide = 2500;
const double sheetW = 21, sheetH = 29.7;

class SheetGrid {
  const SheetGrid(this.cols, this.rows, this.bw, this.bh, this.mx, this.my);
  final int cols, rows;
  final double bw, bh, mx, my;
}

final SheetGrid a4 = () {
  final cols = (sheetW / patchCm).floor(), rows = (sheetH / patchCm).floor();
  final bw = cols * patchCm, bh = rows * patchCm;
  return SheetGrid(cols, rows, bw, bh, (sheetW - bw) / 2, (sheetH - bh) / 2);
}();
final int cells = a4.rows * a4.cols;

const frame = (outer: (32.0, 42.0), depth: 3.0, moulding: 1.0, opening: (30.0, 40.0), picture: (21.0, 30.0), aperture: (20.0, 29.0));

const double _inch = 2.54, _toteTopFraction = 0.42;
double _round1(double v) => jsRound((v + 1e-9) * 10) / 10;
final double _toteW = _round1(16 * _inch), _toteH = _round1(17.5 * _inch);
final tote = (
  inch: '16 × 17½ in', w: _toteW, h: _toteH,
  top: _round1((_toteH - a4.bh) * _toteTopFraction), side: _round1((_toteW - a4.bw) / 2),
);
const double hem = 2.5;

enum Mount { none, frame, tote }
const mounts = Mount.values;

/* L* of each mount's ground colour (none #EFEBDD, frame #FBFAF6, tote #DED2B8), as culori's lab65 gave it,
   recorded 2026-10-06 in test/fixtures/solver/recorded.json. */
const Map<Mount, double> _groundL = {
  Mount.none: 93.00920635395671, Mount.frame: 98.24691178188672, Mount.tote: 84.52697004414956,
};
double canvasL(Mount m) => _groundL[m]!;
