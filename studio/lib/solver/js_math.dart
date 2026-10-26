/* The few places JavaScript's arithmetic is not Dart's, written out so the solver
   deals in the browser exactly what the TypeScript dealt, and on a phone as close
   to it as the phone's own maths allows. */
import 'dart:math' as math;

/* Math.hypot as V8 computes it (src/builtins/math.tq): the largest magnitude
   scales the rest, their squares are Kahan-summed, then sqrt and scale back.
   sqrt(a*a + b*b) differs from it in the last bit often enough to change a solve. */
double jsHypot2(double a, double b) {
  final x = a.abs(), y = b.abs();
  var max = 0.0;
  if (!x.isNaN && x > max) max = x;
  if (!y.isNaN && y > max) max = y;
  if (max == double.infinity) return double.infinity;
  if (x.isNaN || y.isNaN) return double.nan;
  if (max == 0) return 0;
  var sum = 0.0, comp = 0.0;
  var n = x / max, s = n * n - comp, p = sum + s;
  comp = (p - sum) - s; sum = p;
  n = y / max; s = n * n - comp; p = sum + s;
  comp = (p - sum) - s; sum = p;
  return math.sqrt(sum) * max;
}

double jsHypot3(double a, double b, double c) {
  final x = a.abs(), y = b.abs(), z = c.abs();
  var max = 0.0;
  if (!x.isNaN && x > max) max = x;
  if (!y.isNaN && y > max) max = y;
  if (!z.isNaN && z > max) max = z;
  if (max == double.infinity) return double.infinity;
  if (x.isNaN || y.isNaN || z.isNaN) return double.nan;
  if (max == 0) return 0;
  var sum = 0.0, comp = 0.0;
  for (final v in [x, y, z]) {
    final n = v / max, s = n * n - comp, p = sum + s;
    comp = (p - sum) - s; sum = p;
  }
  return math.sqrt(sum) * max;
}

/* Math.round: the nearest integer, a half going up (toward +∞). */
double jsRoundD(double x) {
  if (!x.isFinite) return x; // NaN and ±Infinity pass through, as Math.round gives them
  final f = x.floorToDouble();
  return x - f >= 0.5 ? f + 1 : f;
}

/* The same as an int. An int cannot hold NaN or ±Infinity, so those give 0 here
   rather than throwing; a caller that must see them uses jsRoundD. */
int jsRound(double x) {
  final r = jsRoundD(x);
  return r.isFinite ? r.toInt() : 0;
}

/* The solver's rng: a 32-bit linear congruential generator, the same sequence on every platform. */
double Function() rng(int seed) {
  var s = seed & 0xFFFFFFFF;
  return () {
    s = (s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return s / 4294967296;
  };
}

/* String(n) in JavaScript: a whole number has no ".0". */
String jsNum(num v) {
  if (v == 0) return '0'; // -0 too (checked first: on the web every whole number `is int`)
  if (v is int) return '$v';
  final s = '$v'; // Dart writes a whole double below 1e21 in full, with a trailing ".0"
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/* The platform's own functions, named so the parity report above can call them. */
double atan2Of(double y, double x) => math.atan2(y, x);
double sinOf(double x) => math.sin(x);
double cosOf(double x) => math.cos(x);
double expOf(double x) => math.exp(x);
double powOf(double x, double y) => math.pow(x, y).toDouble();
