import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/hue.dart' show Lab;
import 'package:kantha_studio/solver/score.dart';

/* Heart's two colour terms are steps at sameColour, where its rule draws the line between "the heart's colour" and
   not: in the heart a cloth that near costs nothing and a farther one its full distance; in the ground a cloth that
   near costs sameColour × wAvoid wherever it falls within, and a farther one nothing. A square of another zone with a
   colour target (Blocks' and Diamond's families) keeps paying its distance from the first step. */
void main() {
  // Cloth 0, the anchor (a red); 1, another red within sameColour of it; 2, a blue far from it.
  const labs = <Lab>[(l: 45, a: 60, b: 40), (l: 35, a: 50, b: 30), (l: 50, a: -5, b: -40)];
  final pool = Pool(lab: labs, lightness: [for (final x in labs) x.l], busy: const [false, false, false]);
  final prep = prepare(pool);
  final weights = baseWeightsWith(10);
  double dc(int f) => prep.dc[f * prep.n + 0];

  /* The colour cost of one board of a single square holding `cloth`, the square set up by `setUp`. */
  double block(int cloth, void Function(Objective o) setUp) {
    final o = newObjective(rows: 1, cols: 1, pairs: const [], weights: weights, balance: false);
    setUp(o);
    return score([cloth], o, prep).block;
  }

  void heart(Objective o) {
    o.targetColour = Int32List.fromList([0]);
    o.wColour = Float64List.fromList([2]);
    o.colourFree = Float64List.fromList([weights.sameColour]);
  }

  void family(Objective o) {
    o.targetColour = Int32List.fromList([0]);
    o.wColour = Float64List.fromList([2]);
  }

  void ground(Objective o) {
    o.avoidColour = Int32List.fromList([0]);
    o.wAvoid = Float64List.fromList([16]);
  }

  test('the test cloths sit where the test needs them', () {
    expect(dc(0), 0);
    expect(dc(1), allOf(greaterThan(0), lessThanOrEqualTo(weights.sameColour)));
    expect(dc(2), greaterThan(weights.sameColour));
  });

  test("in the heart, a cloth of the heart's colour costs nothing and another its full distance", () {
    expect(block(0, heart), 0);
    expect(block(1, heart), 0);
    expect(block(2, heart), closeTo(dc(2) * 2, 1e-9));
  });

  test('a square with a colour target and no free distance pays its distance, as before', () {
    expect(block(0, family), 0);
    expect(block(1, family), closeTo(dc(1) * 2, 1e-9));
    expect(block(2, family), closeTo(dc(2) * 2, 1e-9));
  });

  test("in the ground, a cloth of the heart's colour costs sameColour × wAvoid wherever it falls within; another nothing", () {
    expect(block(0, ground), closeTo(weights.sameColour * 16, 1e-9));
    expect(block(1, ground), closeTo(weights.sameColour * 16, 1e-9));
    expect(block(2, ground), 0);
  });
}
