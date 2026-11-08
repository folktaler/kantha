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
