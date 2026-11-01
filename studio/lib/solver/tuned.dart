/* The solver's tuned values, fixed on 6 October 2026 from a sweep of the templates, and on 1 November 2026 from the
   pattern checks (tool/pattern_sweep.dart) where the owner had a pattern fixed. The recorded fixtures hold them. */
abstract final class Tuned {
  static const double lightness = 10;      // the seam weight; immaterial where it is gated
  static const double blockWeight = 8;     // 1 Nov 2026: 2 lost each block's colour to the seams
  static const double colourWeight = 2;    // heart: flat over 1, 2, 4
  static const double boundaryWeight = 2;  // heart: flat over 1–8
  static const double avoidWeight = 16;    // heart: the ground away from the heart's colour; 4 too weak, 40 cost same-cloth neighbours
  // 1 November 2026, later: Heart's colour and avoid terms became steps at sameColour, where its rule draws the line (a cloth
  // within it is the heart's colour, free in the heart, 19.4 × avoidWeight in the ground); the weights were not re-tuned.
  static const double pinWeight = 500;     // chain: a link of any other cloth
  static const double ringWeight = 1;      // diamond: a ring's family; with each level's lightness its family's (1 Nov 2026), 0.5, 1, 2, 4 and 8 passed 375, 377, 376, 376 and 354 of the tuning units; 4 and 8 left same-cloth neighbours
  // The lightness fit's weight per pattern, chosen on 1 November 2026 on the tuning boxes only, over 0.05, 0.1 and 0.2:
  // the most rule passes with no cloth beside itself on at least 99% of boards, 0.05 on a tie. Centre passed 798, 797
  // and 800 units; Cross 773, 797, 799 (92% apart at 0.2); Heart 327, 335, 299; Stripes 715, 721, 722 (88% apart at
  // 0.2). Wave passed 775, 800, 800 but kept no same-cloth neighbours on only 96% and 85% of boards above 0.05.
  static const double fitChess = 0.05, fitGradient = 0.05, fitCentre = 0.2, fitWave = 0.05, fitBorder = 0.05,
      fitCross = 0.1, fitRipple = 0.05, fitHeart = 0.1, fitStripes = 0.1, fitZigzag = 0.05, fitChain = 0.05,
      fitDiamond = 0.05;
}
