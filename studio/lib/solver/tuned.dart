/* The solver's tuned values, fixed on 6 October 2026 from a sweep of the templates. The recorded fixtures hold them. */
abstract final class Tuned {
  static const double lightness = 10;      // the seam weight; immaterial where it is gated
  static const double blockWeight = 2;     // flat over 1–8 on pool-2026-09-11
  static const double colourWeight = 2;    // heart: flat over 1, 2, 4
  static const double boundaryWeight = 2;  // heart: flat over 1–8
}
