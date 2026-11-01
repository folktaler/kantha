import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/hue.dart' show Lab;
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/spec.dart';
import 'pattern_rules.dart' as rules;

/* Heart's two colour terms are steps at sameColour, where its rule draws the line between "the heart's colour" and
   not: in the heart a cloth that near costs nothing and a farther one its full distance; in the ground a cloth that
   near costs sameColour × wAvoid wherever it falls within, and a farther one nothing. A square of another zone with a
   colour target (Blocks' and Diamond's families) keeps paying its distance from the first step.
   Also: the solver's Heart numbers agree with the pattern checks' own, which are coded apart so that the checks stay an
   independent judge; and the order compile relies on. */
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

  test("the solver's heart share is the checks' own", () {
    expect(heartColourShare, rules.heartShare);
  });

  test("darkestMean gives the checks' extremeMean answer for every box's heart, at every board size", () {
    var compared = 0;
    for (final box in rules.allBoxes()) {
      for (var r = boardMin; r <= boardMax; r++) {
        for (var c = boardMin; c <= boardMax; c++) {
          final g = (rows: r, cols: c), b = box.forBoard(r * c);
          final m = modelFor(LayoutKey.heart,
              ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock, size: g));
          final anchor = m.anchors[1] ?? -1;
          if (anchor < 0) continue;
          final heart = layouts[LayoutKey.heart]!.zonesOn(g).where((z) => z == 1).length;
          bool near(int f) => rules.ab(b.pool.lab[f], b.pool.lab[anchor]) <= rules.sameColour;
          final need = (rules.heartShare * heart).ceil();
          final want = rules.extremeMean(b.pool.lightness, b.stock, b.members, heart, darkest: true, need: need, first: near);
          final got = darkestMean(b.pool.lightness, b.stock, b.members, heart, need: need, first: near);
          if (want == null) { expect(got, isNull, reason: '${box.name} $r × $c'); } else { expect(got, closeTo(want, 1e-9), reason: '${box.name} $r × $c'); }
          compared++;
        }
      }
    }
    expect(compared, greaterThan(500));
  });

  test('darkestMean asked for pieces from nowhere, or for more than its squares, is an error, not a guess', () {
    expect(() => darkestMean(const [10, 20], const [1, 1], const [0, 1], 1, need: 1), throwsArgumentError);
    expect(() => darkestMean(const [10, 20], const [1, 1], const [0, 1], 1, need: 2, first: (_) => true), throwsArgumentError);
  });

  test('a box with too few pieces of the heart\'s colour is refused (fewPieces), not given a heart with no target', () {
    // The Sample box with one piece each of its three reds (red, orange, red-bandhani).
    final box = rules.sampleBox([1, 12, 12, 12, 1, 12, 12, 1, 12, 12]);
    final b = box.forBoard(35);
    final m = modelFor(LayoutKey.heart,
        ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock, size: (rows: 7, cols: 5)));
    expect(m.fills, isFalse);
    expect(m.why, Unfillable.fewPieces);
  });

  test('a square a later pass gives a family colour is no longer free of its colour distance', () {
    // One zone asking for the heart's colour and for Diamond's ring families: the rings retarget every square.
    final spec = LayoutSpec(zones: Uint8List(cells), rules: {
      0: const ZoneRules(l: LFromT(Ramps.diamond, 0.05), colour: (hue: heartHue, weight: 2), ringFamilies: (weight: 1)),
    }, within: const SeamNone(), perimeter: false, balance: false);
    final b = rules.sampleBox().forBoard(35);
    final m = compile(spec, ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock,
        size: (rows: 7, cols: 5)));
    expect(m.obj.colourFree, isNotNull);
    expect(m.obj.colourFree!.every((v) => v == 0), isTrue);
  });
}
