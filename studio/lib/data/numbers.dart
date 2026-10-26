import '../solver/geometry.dart' show cells;
import 'box_view.dart';

/* Boxes are numbers to her, never names — Box 1, Box 2, … — each number given once when the box is made and
   never reused (spec 2026-10-07 sample box, decision 8). A sample box has no number. */
Map<int, int> boxNumbers(List<BoxView> boxes) => {for (final b in boxes) if (b.number != null) b.id: b.number!};

/* A cloth is a print when its measured lightness spread is 10 or more; its busyness for Print medallion is the
   same spread over 200 (spec decision 4, measured 7 Oct on 47 photos). It has no upper bound: Print medallion
   ranks it relative to the box's own cloth, least to most edge (`_printPool` in solver/compile.dart). */
const busySpread = 10.0, edgePerSpread = 1 / 200;
bool busyOf(double spread) => spread >= busySpread;
double edgeOf(double spread) => spread * edgePerSpread;

/* Which box the studio opens on (spec 2026-10-07, decision 5): the one asked for, if it is hers; else her
   newest box that can fill a panel; else her newest box; else none, and the board is the empty sheet. */
int? openingBox({int? wanted, required List<({int box, int pieces})> own}) {
  if (wanted != null && own.any((b) => b.box == wanted)) return wanted;
  final newestFirst = [...own]..sort((p, q) => q.box.compareTo(p.box));
  for (final b in newestFirst) {
    if (b.pieces >= cells) return b.box;
  }
  return newestFirst.firstOrNull?.box;
}

/* Add a piece starts its count at 1, on every box (owner, 22 Oct 2026). */
const startCount = 1;
