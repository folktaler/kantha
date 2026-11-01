@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'pattern_rules.dart';

/* Each pattern looks like its name (pattern_rules.dart has the rules and why), on a quick subset of what
   tool/pattern_sweep.dart runs: the Sample box and the tuning pool, the start board and the long, the square and the
   largest boards, one seed. The full sweep, every board 3–12 × 3–12 over eight boxes, is the tool. */

const _sizes = [(rows: 7, cols: 5), (rows: 3, cols: 12), (rows: 12, cols: 3), (rows: 8, cols: 8), (rows: 12, cols: 12)];

/* Cases that fail their rule, each reported to the owner (1 November 2026) and left until he decides; a case not
   listed must pass. Keyed '<pattern> <box> <rows>x<cols>'; the comment is what the rule measured then. Heart's three
   cannot pass from the Sample box's pieces at all: its light cloth away from the heart's colour is too little for the
   ground (tool/pattern_sweep.dart's sweep, and the bound in the report). */
const Set<String> _knownFailures = {
  'medallionPrint Tuning pool 7x5', // ρ 0.63, separation 82.8 of 65.7
  'medallionPrint Tuning pool 8x8', // ρ 0.59, separation 35.3 of 50.0
  'medallionPrint Tuning pool 12x12', // ρ 0.49, separation 50.0 of 53.0
  'heart Sample 3x12', // heart 100% its colour, ground 16%, ground lighter by 11.2 (needs 19.7)
  'heart Sample 12x3', // heart 100% its colour, ground 13%, ground lighter by 10.7 (needs 19.7)
  'heart Sample 12x12', // heart 90% its colour, ground 14%, ground lighter by 14.4 (needs 19.7)
};

ObjectiveInput _input(Box box, BoardSize g) {
  final b = box.forBoard(g.rows * g.cols);
  return ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock, size: g);
}

void main() {
  final boxes = [sampleBox(), tuningBox()];
  for (final key in layoutKeys) {
    test('${patternName[key]} keeps its rule, and beats a random arrangement of the same pieces', () {
      var mine = 0, chance = 0, judged = 0;
      for (final box in boxes) {
        for (final g in _sizes) {
          final c = runCase(key, box, g, 1);
          final id = '${key.name} ${box.name} ${g.rows}x${g.cols}';
          if (key == LayoutKey.chain && !c.fills) {
            // Every link one cloth (owner, 1 November 2026): no cloth of these has a piece for each link.
            expect(modelFor(key, _input(box, g)).why, Unfillable.noChainCloth, reason: id);
            continue;
          }
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
      if (key == LayoutKey.chain && judged == 0) return;
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
