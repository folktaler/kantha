import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'pattern_rules.dart';

/* lib/solver/rules.dart for a caller grading boards with it: a pass or a fail always carries a term, every perfect is
   the rule's own aim (it does not move with the box), and lightnessRule says cannot, never throws, where a model has
   no lightness target. */
void main() {
  const size = (rows: 7, cols: 5);
  final boxes = [sampleBox(), drawnBoxes()[1]];

  test('a pass or a fail carries at least one term, and its perfect does not depend on the box', () {
    final perfects = <String, Set<double>>{};
    for (final box in boxes) {
      for (final key in layoutKeys) {
        final c = runCase(key, box, size, 1);
        for (final j in [c.solved, c.random, c.sorted]) {
          if (j == null || j.rule.outcome == Outcome.cannot) continue;
          expect(j.rule.terms, isNotEmpty, reason: '${box.name} ${key.name}: ${j.rule.detail}');
          for (final t in j.rule.terms) {
            if (t.name == 'separation') expect(t.perfect, closeTo(t.bar / separationShare, 1e-9));
            (perfects['${key.name} ${t.name}'] ??= {}).add(t.perfect);
          }
        }
      }
    }
    expect(perfects, isNotEmpty);
    // Every aim is a constant but separation's: the whole gap the pattern's target asks for, and the target is set from
    // the box's lightness, so it is checked as the bar's own multiple instead.
    for (final e in perfects.entries.where((e) => !e.key.endsWith(' separation'))) {
      expect(e.value, hasLength(1), reason: '${e.key}: $e');
    }
  });

  test('lightnessRule on a model with no lightness target says cannot', () {
    final b = sampleBox().forBoard(35);
    for (final key in layoutKeys) {
      final m = modelFor(key, ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock, size: size));
      final grid = randomGrid(b.stock, b.members, 35, 1);
      final v = lightnessRule(m, grid, b.stock, b.members);
      if (m.obj.targetL == null || m.obj.wL == null || !m.obj.wL!.any((w) => w > 0)) expect(v.outcome, Outcome.cannot, reason: key.name);
    }
  });
}
