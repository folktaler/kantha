import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/hue.dart';
import '../fixtures/fixtures.g.dart' as g;
import 'recorded.dart';

void main() {
  final rows = [for (final line in g.sharma.trim().split('\n')) [for (final x in line.trim().split(RegExp(r'\s+'))) double.parse(x)]];

  // The 34 published pairs are the only test here that runs in the Dart VM as well (dart_test.yaml).
  test('reproduces all 34 published CIEDE2000 reference pairs to four decimals', () {
    expect(rows.length, 34);
    for (final r in rows) {
      final got = ciede2000((l: r[0], a: r[1], b: r[2]), (l: r[3], a: r[4], b: r[5])).dE;
      expect((got - r[6]).abs(), lessThan(5e-5), reason: '$r');
    }
  });

  test('every pair of the pool, as the snapshot holds it', tags: 'chrome-only', () {
    final labs = poolLab();
    for (final e in recorded['ciede'] as List) {
      final got = ciede2000(labs[e['p'] as int], labs[e['q'] as int]);
      expect((got.dE - d(e['dE'])).abs(), lessThanOrEqualTo(1e-12), reason: '$e');
      expect((got.dEChroma - d(e['dEChroma'])).abs(), lessThanOrEqualTo(1e-12), reason: '$e');
      expect((got.dH - d(e['dH'])).abs(), lessThanOrEqualTo(1e-12), reason: '$e');
    }
  });

  test('angleGap keeps JavaScript remainder semantics', tags: 'chrome-only', () {
    expect(angleGap(-10.3, 0), closeTo(10.3, 1e-12));
    expect(angleGap(350, 10), closeTo(20, 1e-12));
  });

  test("angleGap gives JavaScript's answer to the last bit where Euclidean modulo would differ", tags: 'chrome-only', () {
    // Values from Node: Math.abs(((p - q) % 360 + 540) % 360 - 180). A Euclidean
    // `%` gives the second number of each line instead.
    //   (-3, 34.8)      37.80000000000001   not 37.799999999999955
    //   (-331.3, 175.5) 146.8               not 146.79999999999995
    //   (52.5, 332.8)   79.69999999999999   not 79.70000000000005
    //   (-121.1, 153.1) 85.80000000000001   not 85.79999999999995
    //   (-31, 123.7)    154.7               not 154.70000000000005
    expect(angleGap(-3, 34.8), 37.80000000000001);
    expect(angleGap(-331.3, 175.5), 146.8);
    expect(angleGap(52.5, 332.8), 79.69999999999999);
    expect(angleGap(-121.1, 153.1), 85.80000000000001);
    expect(angleGap(-31, 123.7), 154.7);
  });
}
