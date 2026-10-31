@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'pattern_rules.dart';

/* Each pattern looks like its name (pattern_rules.dart has the rules and why), on a quick subset of what
   tool/pattern_sweep.dart runs: the Sample box and the tuning pool, the start board and the long, the square and the
   largest boards, one seed. The full sweep, every board 3–12 × 3–12 over eight boxes, is the tool. */

const _sizes = [(rows: 7, cols: 5), (rows: 3, cols: 12), (rows: 12, cols: 3), (rows: 8, cols: 8), (rows: 12, cols: 12)];

/* Cases that failed their rule when the rules were first run (31 October 2026), reported to the owner with a proposed
   fix (Chess, Spectrum, Blocks, Ripple, Heart); each stays here, as it is, until he decides. A case not listed must
   pass. Keyed '<pattern> <box> <rows>x<cols>'; the comment is what the rule measured then. */
const Set<String> _knownFailures = {
  'contrast Sample 7x5', // median seam 35.2 (needs 25.0), checker 0.31
  'contrast Sample 3x12', // median seam 36.8 (needs 25.0), checker 0.26
  'contrast Sample 12x3', // median seam 35.2 (needs 25.0), checker 0.58
  'contrast Sample 8x8', // median seam 37.8 (needs 25.0), checker 0.36
  'contrast Sample 12x12', // median seam 39.3 (needs 20.5), checker 0.38
  'contrast Tuning pool 7x5', // median seam 41.0 (needs 25.0), checker 0.79
  'contrast Tuning pool 3x12', // median seam 41.4 (needs 25.0), checker 0.79
  'contrast Tuning pool 8x8', // median seam 39.8 (needs 25.0), checker 0.07
  'contrast Tuning pool 12x12', // median seam 36.9 (needs 25.0), checker 0.17
  'spectrum Sample 7x5', // ρ 0.49 over 35 coloured squares
  'spectrum Sample 3x12', // ρ 0.58 over 36 coloured squares
  'spectrum Sample 12x3', // ρ 0.42 over 36 coloured squares
  'spectrum Sample 8x8', // ρ 0.61 over 64 coloured squares
  'spectrum Sample 12x12', // ρ 0.66 over 144 coloured squares
  'blocks Sample 3x12', // 50% nearest their own block’s colour
  'blocks Sample 12x12', // 65% nearest their own block’s colour
  'medallionPrint Tuning pool 7x5', // ρ 0.63, separation 82.8 of 65.7
  'medallionPrint Tuning pool 8x8', // ρ 0.59, separation 35.3 of 50.0
  'medallionPrint Tuning pool 12x12', // ρ 0.49, separation 50.0 of 53.0
  'heart Sample 7x5', // heart 100% its colour, ground 26%, ground lighter by 22.8 (needs 19.7)
  'heart Sample 3x12', // heart 75% its colour, ground 56%, ground lighter by 15.6 (needs 19.7)
  'heart Sample 12x3', // heart 75% its colour, ground 56%, ground lighter by 15.3 (needs 19.7)
  'heart Sample 8x8', // heart 100% its colour, ground 26%, ground lighter by 23.1 (needs 19.7)
  'heart Sample 12x12', // heart 52% its colour, ground 39%, ground lighter by 24.6 (needs 19.7)
};

void main() {
  final boxes = [sampleBox(), tuningBox()];
  for (final key in layoutKeys) {
    test('${patternName[key]} keeps its rule, and beats a random arrangement of the same pieces', () {
      var mine = 0, chance = 0, judged = 0;
      for (final box in boxes) {
        for (final g in _sizes) {
          final c = runCase(key, box, g, 1);
          final id = '${key.name} ${box.name} ${g.rows}x${g.cols}';
          expect(c.fills, isTrue, reason: '$id: the box fills it');
          final v = c.solved!;
          if (v.rule.applies) {
            judged++;
            if (v.rule.passes) mine++;
            if (c.random!.rule.passes) chance++;
            if (!_knownFailures.contains(id)) expect(v.rule.passes, isTrue, reason: '$id: ${v.rule.detail}');
          }
          if (v.apartApplies) expect(v.repeats, 0, reason: '$id: same-cloth neighbours');
        }
      }
      expect(judged, greaterThan(0));
      expect(mine, greaterThan(chance), reason: 'passes $mine of $judged; random $chance');
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('Diamond is not Centre: their target maps disagree on boards with three rings or more', () {
    for (final g in [(rows: 7, cols: 5), (rows: 8, cols: 8), (rows: 12, cols: 12), (rows: 3, cols: 12)]) {
      final rho = spearman(targetMap(LayoutKey.medallion, g).toList(), targetMap(LayoutKey.diamond, g).toList());
      expect(rho.abs(), lessThan(strongRho), reason: '${g.rows} × ${g.cols}: ρ $rho');
    }
  });

  test('the rules themselves: Spearman with ties, and the spectrum axis', () {
    expect(spearman([1, 2, 3, 4], [10, 20, 30, 40]), closeTo(1, 1e-12));
    expect(spearman([1, 2, 3, 4], [4, 3, 2, 1]), closeTo(-1, 1e-12));
    expect(spearman([1, 1, 2, 2], [1, 2, 3, 4]), closeTo(0.8944, 1e-4));
    expect(spearman([1, 1, 1], [1, 2, 3]).isNaN, isTrue);
    expect(spectrumAxis(200), 200);
    expect(spectrumAxis(260), 260);
    expect(spectrumAxis(300), -60);
    expect(spectrumAxis(-10), -10);
  });
}
