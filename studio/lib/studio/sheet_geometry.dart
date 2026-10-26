/* The printed sheet's geometry, and how far a square can reach. All in cm. */
import '../solver/geometry.dart';

/* The order squares are laid: column by column, so each lies over the one before. */
int layIndex(int r, int c) => c * a4.rows + r;

/* Where a square's cloth lies on the sheet: 6 cm cut, the last row and column trimmed to 4. */
({double left, double top, double w, double h}) footprintOf(int r, int c) => (
      left: a4.mx + c * patchCm,
      top: a4.my + r * patchCm,
      w: c == a4.cols - 1 ? patchCm : cutCm,
      h: r == a4.rows - 1 ? patchCm : cutCm,
    );

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
