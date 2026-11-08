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

/* The sizes she may choose, rows and columns alike (Level 2). Level 1's 7 × 5 is among them. */
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

/* The ground the panel's edge is judged against. The studio shows only none since Mount left it (8 November 2026);
   frame and tote stay because the solver's recorded snapshot judges every pattern on all three grounds. */
enum Mount { none, frame, tote }

/* L* of each mount's ground colour (none #EFEBDD, frame #FBFAF6, tote #DED2B8), as culori's lab65 gave it,
   recorded 2026-10-06 in test/fixtures/solver/recorded.json. */
const Map<Mount, double> _groundL = {
  Mount.none: 93.00920635395671, Mount.frame: 98.24691178188672, Mount.tote: 84.52697004414956,
};
double canvasL(Mount m) => _groundL[m]!;
