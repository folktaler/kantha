@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'pattern_rules.dart';

/* Each pattern looks like its name (pattern_rules.dart has the rules and why), on a quick subset of what
   tool/pattern_sweep.dart runs: the Sample box and the tuning pool, the start board and the long, the square and the
   largest boards, one seed. The full sweep, every board 3–12 × 3–12 over twelve boxes, is the tool. */

const _sizes = [(rows: 7, cols: 5), (rows: 3, cols: 12), (rows: 12, cols: 3), (rows: 8, cols: 8), (rows: 12, cols: 12)];

/* Cases whose outcome is not a pass, each reported to the owner (1 November 2026) and left until he decides; a case not
   listed must pass. Keyed '<pattern> <box> <rows>x<cols>'; the comment is what the rule measured then. */
const Map<String, Outcome> _known = {
  // Heart on the Sample box: the heart holds its colour, but the ground is not 25 L* lighter.
  'heart Sample 3x12': Outcome.fail, // ground lighter by 23.4
  'heart Sample 12x3': Outcome.fail, // ground lighter by 23.2
  'heart Sample 8x8': Outcome.fail, // heart 96%, ground lighter by 19.7
  'heart Sample 12x12': Outcome.fail, // heart 96%, ground lighter by 15.8
  // Chain needs one dark cloth with a piece for every link; 12 pieces cover 7 x 5 but not these boards.
  'chain Sample 8x8': Outcome.cannot, // noChainCloth
  'chain Sample 12x12': Outcome.cannot, // noChainCloth
  'chain Tuning pool 12x12': Outcome.cannot, // noChainCloth
  // Diamond needs a colour family with enough pieces for each ring.
  'diamond Sample 8x8': Outcome.cannot, // noRingFamily
  'diamond Sample 12x12': Outcome.cannot, // noRingFamily
};

void main() {
  final boxes = [sampleBox(), tuningBox()];
  for (final key in layoutKeys) {
    test('${patternName[key]} keeps its rule, beats a random arrangement of the same pieces, and keeps one cloth from '
        'its neighbours', () {
      var mine = 0, chance = 0, judged = 0;
      for (final box in boxes) {
        for (final g in _sizes) {
          final c = runCase(key, box, g, 1);
          final id = '${key.name} ${box.name} ${g.rows}x${g.cols}';
          expect(c.outcome, _known[id] ?? Outcome.pass, reason: '$id: ${c.fills ? c.solved!.rule.detail : c.why}');
          if (c.outcome == Outcome.cannot) continue;
          judged++;
          if (c.solved!.rule.passes) mine++;
          if (c.random!.rule.passes) chance++;
          if (c.solved!.apartApplies) expect(c.solved!.repeats, 0, reason: '$id: same-cloth neighbours');
        }
      }
      expect(judged, greaterThan(0));
      expect(mine, greaterThan(chance), reason: 'passes $mine of $judged; random $chance');
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('Diamond is not Centre: their target maps disagree on boards with three rings or more', () {
    for (final g in [(rows: 7, cols: 5), (rows: 8, cols: 8), (rows: 12, cols: 12), (rows: 3, cols: 12)]) {
      final rho = spearman(targetMap(LayoutKey.medallion, g).toList(), targetMap(LayoutKey.diamond, g).toList());
      expect(rho.abs(), lessThan(0.7), reason: '${g.rows} × ${g.cols}: ρ $rho');
    }
  });

  test('the Single Irish Chain: diagonal chains six squares apart, crossing as a five-square X at the middle', () {
    final t = targetMap(LayoutKey.chain, (rows: 7, cols: 7));
    String row(int r) => [for (var c = 0; c < 7; c++) t[r * 7 + c] == 0 ? 'X' : '.'].join();
    expect([for (var r = 0; r < 7; r++) row(r)], ['X.....X', '.X...X.', '..X.X..', '...X...', '..X.X..', '.X...X.', 'X.....X']);
    final big = targetMap(LayoutKey.chain, level1);
    expect(big.where((v) => v == 0).length, 9, reason: 'the start board has 9 links');
  });

  test('the statistics: Somers’ d, its bound from the pieces, and the Wilson interval', () {
    expect(somersD([1, 2, 3, 4], [10, 20, 30, 40]), 1);
    expect(somersD([4, 3, 2, 1], [10, 20, 30, 40]), -1);
    // Ties in the target are left out: a board that follows a tied target exactly scores 1.
    expect(somersD([1, 2, 5, 6], [0, 0, 1, 1]), 1);
    // Ties in lightness count as neither.
    expect(somersD([1, 1, 2, 2], [1, 2, 3, 4]), closeTo(4 / 6, 1e-12));
    expect(somersD([1, 2, 3], [5, 5, 5]).isNaN, isTrue);
    expect(maxSomersD([1, 2, 3, 4], {10: 4}), 0, reason: 'one lightness: every pair tied');
    expect(maxSomersD([1, 2, 3, 4], {10: 1, 20: 1, 30: 1, 40: 1}), 1);
    expect(maxSomersD([0, 0, 1, 1], {10: 2, 20: 2}), 1, reason: 'ties the target also ties cost nothing');
    final w = wilson(8, 10);
    expect(w.lo, closeTo(0.4902, 1e-4));
    expect(w.hi, closeTo(0.9433, 1e-4));
    expect(wilson(0, 10).lo, 0);
    expect(wilson(0, 10).hi, closeTo(0.2775, 1e-4));
  });

  test('the check cuts the hue circle in the purples where the box has no hue, and blue is cool', () {
    expect(checkCut([340, 350, 100]), closeTo(4.65, 1e-9));
    expect(onCheckLine(camHue((l: 32.3, a: 79.2, b: -107.9)), 355.55), greaterThan(onCheckLine(camHue((l: 53.2, a: 80.1, b: 67.2)), 355.55)),
        reason: 'sRGB blue cooler than sRGB red');
  });
}
