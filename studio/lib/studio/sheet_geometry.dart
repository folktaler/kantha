/* The printed sheet's geometry, and how far a square can reach. All in cm. */
import '../solver/geometry.dart';

/* The order squares are laid (the sheet null: Level 1's A4): column by column, so each lies over the one before. */
int layIndex(int r, int c, [SheetGrid? sheet]) => c * (sheet ?? a4).rows + r;

/* Where a square's cloth lies on the sheet: 6 cm cut, the last row and column trimmed to 4. */
({double left, double top, double w, double h}) footprintOf(int r, int c, [SheetGrid? sheet]) {
  final g = sheet ?? a4;
  return (
    left: g.mx + c * patchCm,
    top: g.my + r * patchCm,
    w: c == g.cols - 1 ? patchCm : cutCm,
    h: r == g.rows - 1 ? patchCm : cutCm,
  );
}

/* How far the printed grid runs past the squares. */
const double bleedCm = 0.45;

/* How far a mount reaches past the A4 sheet (left, right, top, bottom). */
({double left, double right, double top, double bottom}) reachOf(Mount mount) {
  switch (mount) {
    case Mount.frame:
      final x = (frame.outer.$1 - sheetW) / 2, y = (frame.outer.$2 - sheetH) / 2;
      return (left: x, right: x, top: y, bottom: y);
    case Mount.tote:
      final x = tote.w / 2 - a4.mx - a4.bw / 2, top = tote.top - a4.my;
      return (left: x, right: x, top: top, bottom: tote.h - top - sheetH);
    case Mount.none:
      return (left: 0, right: 0, top: 0, bottom: 0);
  }
}
