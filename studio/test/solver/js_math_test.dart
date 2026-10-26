@Tags(['chrome-only'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/js_math.dart';
import 'recorded.dart';

void main() {
  test('Math.hypot, exactly as V8 gives it, on 2000 pairs and 2000 triples', () {
    for (final r in jsMath['hypot2'] as List) {
      expect(jsHypot2(d(r[0]), d(r[1])), d(r[2]), reason: '$r');
    }
    for (final r in jsMath['hypot3'] as List) {
      expect(jsHypot3(d(r[0]), d(r[1]), d(r[2])), d(r[3]), reason: '$r');
    }
  });

  test('Math.hypot at its edges', () {
    expect(jsHypot2(0, 0), 0);
    expect(jsHypot2(double.infinity, double.nan), double.infinity);
    expect(jsHypot2(3, double.nan).isNaN, isTrue);
    expect(jsHypot2(-3, 4), 5);
  });

  test('Math.round rounds half toward +∞, and the half just below it down', () {
    expect(jsRound(2.5), 3);
    expect(jsRound(-2.5), -2);
    expect(jsRound(0.49999999999999994), 0);
    expect(jsRound(-0.6), -1);
  });

  test('the seeded generator deals the recorded numbers', () {
    final r = rng(20260910);
    expect([r(), r(), r(), r(), r()], [0.4009142939466983, 0.10119960084557533, 0.5016654541250318, 0.9260954414494336, 0.25074659124948084]);
    final q = rng(4294967295);
    expect([q(), q(), q()], [0.2356804204173386, 0.18786314339376986, 0.13482548762112856]);
  });

  test('a number reads as JavaScript writes it', () {
    expect(jsNum(25.0), '25');
    expect(jsNum(0.5), '0.5');
    expect(jsNum(-3), '-3');
    expect(jsNum(1234), '1234');
    expect(jsNum(-0.0), '0');
    expect(jsNum(9007199254740992.0), '9007199254740992');
    expect(jsNum(1152921504606846976.0), '1152921504606847000'); // 2^60, as Node prints it
    expect(jsNum(1e21), '1e+21');
  });

  test('Math.round on NaN and the infinities', () {
    expect(jsRoundD(double.nan).isNaN, isTrue);
    expect(jsRoundD(double.infinity), double.infinity);
    expect(jsRoundD(double.negativeInfinity), double.negativeInfinity);
    expect(jsRoundD(2.5), 3.0);
    expect(jsRound(double.nan), 0);
    expect(jsRound(double.infinity), 0);
    expect(jsRound(double.negativeInfinity), 0);
  });

  test('the platform maths, compared to V8 — reported, not required', () {
    // The solver's parity tests (Task 5) are the gate. This says where a
    // mismatch would come from if they ever fail on one platform.
    var off = 0;
    for (final r in jsMath['atan2'] as List) { if (atan2Of(d(r[0]), d(r[1])) != d(r[2])) off++; }
    for (final r in jsMath['sin'] as List) { if (sinOf(d(r[0])) != d(r[1])) off++; }
    for (final r in jsMath['cos'] as List) { if (cosOf(d(r[0])) != d(r[1])) off++; }
    for (final r in jsMath['exp'] as List) { if (expOf(d(r[0])) != d(r[1])) off++; }
    for (final r in jsMath['pow'] as List) { if (powOf(d(r[0]), d(r[1])) != d(r[2])) off++; }
    // ignore: avoid_print
    print('platform maths differing from V8 in the last bit: $off of 10000');
  });
}
