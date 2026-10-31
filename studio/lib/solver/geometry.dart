import 'js_math.dart';

const double patchCm = 4, cutCm = patchCm + 2;
const int maxLongSide = 2500;
const double sheetW = 21, sheetH = 29.7;

class SheetGrid {
  const SheetGrid(this.cols, this.rows, this.bw, this.bh, this.mx, this.my, {this.w = sheetW, this.h = sheetH});
  final int cols, rows;
  /* The squares' width and height, their margins on the sheet, and the sheet itself; all in cm. */
  final double bw, bh, mx, my, w, h;
}

final SheetGrid a4 = () {
  final cols = (sheetW / patchCm).floor(), rows = (sheetH / patchCm).floor();
  final bw = cols * patchCm, bh = rows * patchCm;
  return SheetGrid(cols, rows, bw, bh, (sheetW - bw) / 2, (sheetH - bh) / 2);
}();
final int cells = a4.rows * a4.cols;

/* A board's size in squares. Level 1, every board on A4, is the sheet's own: 7 rows of 5. */
typedef BoardSize = ({int rows, int cols});
final BoardSize level1 = (rows: a4.rows, cols: a4.cols);

/* The sizes a Patchworker may choose, rows and columns alike (Level 2). Level 1's 7 × 5 is among them. */
const int boardMin = 3, boardMax = 12;
bool boardSizeAllowed(BoardSize g) =>
    g == level1 || (g.rows >= boardMin && g.rows <= boardMax && g.cols >= boardMin && g.cols <= boardMax);

/* The sheet a board of size g is drawn on: A4 for Level 1; any other size is a picture only, its squares on a sheet
   just bigger than they are, `_margin` all round. */
const double _margin = 1;
final _sheets = <BoardSize, SheetGrid>{};
/* One sheet per size, made once, so a sheet is the same object every time it is asked for. */
SheetGrid sheetFor(BoardSize g) => g == level1 ? a4 : _sheets.putIfAbsent(g, () => SheetGrid(g.cols, g.rows,
    g.cols * patchCm, g.rows * patchCm, _margin, _margin, w: g.cols * patchCm + 2 * _margin, h: g.rows * patchCm + 2 * _margin));

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
