import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/cam16.dart';
import 'package:kantha_studio/solver/hue.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
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

  group('CAM16 (cam16.dart)', () {
    Lab sRgb(int r, int g, int b) {
      final l = ColorUtils.labFromArgb(ColorUtils.argbFromRgb(r, g, b));
      return (l: l[0], a: l[1], b: l[2]);
    }

    test('a CIELAB colour gets the hue material_color_utilities gives its sRGB value', () {
      for (final (r, g, b) in [(0, 0, 255), (0, 0, 128), (255, 0, 0), (255, 165, 0), (0, 128, 128)]) {
        expect(ucsOf(sRgb(r, g, b)).hue, closeTo(Cam16.fromInt(ColorUtils.argbFromRgb(r, g, b)).hue, 1e-6));
      }
    });

    test('blue and navy sit with the cool hues, not past red as CIELAB unwrapped at 290° put them', () {
      final cut = purpleCut([for (final c in [sRgb(0, 0, 255), sRgb(0, 0, 128), sRgb(255, 0, 0), sRgb(255, 165, 0)]) ucsOf(c).hue]);
      double line(Lab c) => hueOnLine(ucsOf(c).hue, cut);
      expect(line(sRgb(0, 0, 255)), greaterThan(line(sRgb(0, 128, 128))));
      expect(line(sRgb(0, 0, 128)), greaterThan(line(sRgb(255, 165, 0))));
      expect(line(sRgb(255, 0, 0)), lessThan(line(sRgb(255, 165, 0))));
    });

    test('the cut falls in the purples, in the middle of the widest stretch with no hue of the box', () {
      expect(purpleCut([]), closeTo((331.8 + 379.3) / 2, 1e-9));
      expect(purpleCut([340, 350, 100]), closeTo((350 + 379.3) / 2 - 360, 1e-9));
      expect(purpleCut([335, 375]), closeTo(355, 1e-9));
    });

    test('ΔE′ is the Euclidean distance in J′a′b′, and a′b′ leaves lightness out', () {
      final p = ucsOf(sRgb(255, 0, 0)), q = ucsOf(sRgb(255, 165, 0));
      expect(deUcs(p, q), closeTo(38.88, 0.01));
      expect(chromaUcs(p, q), closeTo(33.91, 0.01));
      expect(chromaUcs(ucsOf((l: 30, a: 0, b: 0)), ucsOf((l: 80, a: 0, b: 0))), lessThan(1));
    });
  });
}
