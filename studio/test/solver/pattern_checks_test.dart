@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/hue.dart' show Lab;
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
  // The Sample box of 2 November 2026 (Purple 34, Turmeric 31, White 40, the rest 12; 189 pieces) has too few pieces
  // for a 12 x 12 Heart, Chain or Diamond. The tuning pool has no dark cloth with a piece for every 12 x 12 link.
  'heart Sample 12x12': Outcome.cannot, // fewPieces
  'chain Sample 12x12': Outcome.cannot, // noChainCloth
  'chain Tuning pool 12x12': Outcome.cannot, // noChainCloth
  'diamond Sample 12x12': Outcome.cannot, // noRingFamily
  // Accepted for now by the owner, 2 November 2026: Diamond on the Sample box falls short, the least one-family ring
  // 67% (seeds 1 to 6 alike).
  'diamond Sample 8x8': Outcome.fail,
};

/* The most same-cloth neighbours accepted on a case that passes, for now, by the owner (2 November 2026); a case not
   listed must have none. Stripes on the Sample box of that day: 0 to 2 over seeds 1 to 6. */
const Map<String, int> _knownRepeats = {
  'stripes Sample 12x12': 2,
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
          if (c.solved!.apartApplies) {
            expect(c.solved!.repeats, lessThanOrEqualTo(_knownRepeats[id] ?? 0), reason: '$id: same-cloth neighbours');
          }
        }
      }
      expect(judged, greaterThan(0));
      expect(mine, greaterThan(chance), reason: 'passes $mine of $judged; random $chance');
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('Heart keeps its rule at 12 wide and 10 tall from the Sample box (owner, 2 November 2026: "Add Turmeric")', () {
    for (final seed in [1, 2, 3]) {
      final c = runCase(LayoutKey.heart, sampleBox(), (rows: 10, cols: 12), seed);
      expect(c.outcome, Outcome.pass, reason: 'seed $seed: ${c.fills ? c.solved!.rule.detail : c.why}');
      expect(c.solved!.repeats, 0, reason: 'seed $seed: same-cloth neighbours');
    }
  });

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

  test('Spectrum puts the one coloured cloth wherever its pieces reach, before any grey', () {
    Fabric f(String id, Lab lab) => Fabric(id: id, name: id, lab: lab, busy: false, edge: null, grain: null, stock: 10);
    final box = Box('One red', [
      f('red', (l: 45, a: 60, b: 40)),
      for (var k = 0; k < 4; k++) f('grey$k', (l: 30.0 + 15 * k, a: 0, b: 0)),
    ]);
    final c = runCase(LayoutKey.spectrum, box, (rows: 7, cols: 5), 1);
    expect(c.fills, isTrue, reason: c.why);
    expect(c.grid!.where((x) => x == 0).length, 10, reason: 'all 10 red pieces');
    // With one hue the run from warm to cool is 0, and a grey still costs 180 on the hue line, as it always did.
    final b = box.forBoard(35);
    final m = modelFor(LayoutKey.spectrum, ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members,
        mount: Mount.none, stock: b.stock, size: (rows: 7, cols: 5)));
    expect(m.obj.hueExcludeGap, 180);
  });

  test('the bounds from the pieces: one cloth with no neighbour, the extreme mean, and the seams a box can make', () {
    final obj = modelFor(LayoutKey.contrast, ObjectiveInput(pool: sampleBox().forBoard(9).pool,
        edge: sampleBox().forBoard(9).edge, members: sampleBox().forBoard(9).members, mount: Mount.none,
        stock: sampleBox().forBoard(9).stock, size: (rows: 3, cols: 3))).obj;
    // A 3 x 3 board holds one cloth on at most its 5 corner-and-centre squares; a row of 3 on at most 2.
    expect(apartCap([for (var i = 0; i < 9; i++) i], obj), 5);
    expect(apartCap([0, 1, 2], obj), 2);
    // Lightness 10 (2 pieces), 50 (5) and 90 (1); the darkest 3 squares average (10 + 10 + 50) / 3, and at most one
    // piece each gives (10 + 50 + 90) / 3; with 2 of them from the 90 cloth, there are not enough.
    final l = [10.0, 50.0, 90.0], stock = [2, 5, 1], members = [0, 1, 2];
    expect(extremeMean(l, stock, members, 3, darkest: true), closeTo(70 / 3, 1e-9));
    expect(extremeMean(l, stock, members, 3, darkest: true, cap: 1), closeTo(50, 1e-9));
    expect(extremeMean(l, stock, members, 3, darkest: true, need: 2, first: (f) => f == 2), isNull);
    // Held Any 8 at 5 x 7: only its 4 pieces at L* 7.8 and 2 at 90.5 have a partner 25 L* away on every seam, so at
    // most 24 seams of 58 can be that far apart and the median cannot reach 25.
    final c = runCase(LayoutKey.contrast, heldOutBoxes().firstWhere((b) => b.name == 'Held Any 8'), (rows: 5, cols: 7), 1);
    expect(c.outcome, Outcome.cannot, reason: c.solved!.rule.detail);
    // Chain on the same box: its links one cloth, the ground from what is left, cannot reach half the separation.
    final chain = runCase(LayoutKey.chain, heldOutBoxes().firstWhere((b) => b.name == 'Held Any 8'), (rows: 7, cols: 5), 1);
    expect(chain.outcome, Outcome.cannot, reason: chain.fills ? chain.solved!.rule.detail : chain.why);
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
