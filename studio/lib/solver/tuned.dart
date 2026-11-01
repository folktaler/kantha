/* The solver's tuned values, fixed on 6 October 2026 from a sweep of the templates, and on 1 November 2026 from the
   pattern checks (tool/pattern_sweep.dart) where the owner had a pattern fixed. The recorded fixtures hold them. */
abstract final class Tuned {
  static const double lightness = 10;      // the seam weight; immaterial where it is gated
  static const double blockWeight = 8;     // 1 Nov 2026: 2 lost each block's colour to the seams
  static const double colourWeight = 2;    // heart: flat over 1, 2, 4
  static const double boundaryWeight = 2;  // heart: flat over 1–8
  static const double avoidWeight = 16;    // heart: the ground away from the heart's colour; 4 too weak, 40 cost same-cloth neighbours
  static const double pinWeight = 500;     // chain: a link of any other cloth
  static const double ringWeight = 2;      // diamond: a ring's family; on the tuning boxes 0.25, 0.5, 1, 2, 8 and 32 passed 63, 76, 76, 77, 47 and 26%
}
