/* Colour difference and hue in CAM16 (Li et al. 2017, "Comprehensive color solutions: CAM16, CAT16, and CAM16-UCS",
   Color Research & Application 42(6)), the model material_color_utilities ships, under its sRGB viewing conditions
   (D65 white, background L* 50, average surround). One metric for every colour difference: CAM16-UCS ΔE′, the
   Euclidean distance in J′a′b′, which was fitted to large as well as small differences; CIEDE2000 was fitted to small
   ones only. Lightness stays CIE L* everywhere (it was fitted to Munsell value). */
import 'dart:math' as math;
import 'package:material_color_utilities/material_color_utilities.dart';
import 'hue.dart';

typedef Ucs = ({double j, double a, double b, double hue, double c});

double _finv(double t) => t > 6 / 29 ? t * t * t : 3 * (6 / 29) * (6 / 29) * (t - 4 / 29);

/* A CIELAB colour (D65) in CAM16-UCS, with its CAM16 hue angle h (degrees, 0–360) and CAM16 chroma C. */
Ucs ucsOf(Lab lab) {
  final wp = ColorUtils.whitePointD65();
  final fy = (lab.l + 16) / 116, fx = fy + lab.a / 500, fz = fy - lab.b / 200;
  final c = Cam16.fromXyzInViewingConditions(wp[0] * _finv(fx), wp[1] * _finv(fy), wp[2] * _finv(fz), ViewingConditions.sRgb);
  return (j: c.jstar, a: c.astar, b: c.bstar, hue: c.hue, c: c.chroma);
}

/* A cloth has a hue to speak of from CAM16 chroma 11.5: the same 13 of the 90 cloths (the Sample box, the tuning
   pool and the 47 factory cloths) fall below it as fell below the CIELAB chroma 10 it replaces, which was a design
   choice with no published source. */
const double minChroma = 11.5;
bool coloured(Lab lab) => ucsOf(lab).c >= minChroma;

/* CAM16-UCS ΔE′ (Li et al. 2017, eq. 13 with K_L = 1): lightness, colourfulness and hue together. Not
   Cam16.distance, which adds a power correction (1.41 ΔE′^0.63) from a different paper. */
double deUcs(Ucs p, Ucs q) {
  final dj = p.j - q.j, da = p.a - q.a, db = p.b - q.b;
  return math.sqrt(dj * dj + da * da + db * db);
}

/* The same distance with lightness left out (a′b′ only): "is this cloth that colour", whatever its lightness, as
   Heart, Blocks and the colour families ask. */
double chromaUcs(Ucs p, Ucs q) {
  final da = p.a - q.a, db = p.b - q.b;
  return math.sqrt(da * da + db * db);
}

/* The ends of the spectrum locus in CAM16 hue under these viewing conditions: 380 nm at 331.8°, 700 nm at 19.3°
   (CIE 1931 2° chromaticities at Y 20, converted once with Cam16.fromXyzInViewingConditions). Between them, the long way
   round through 0°, lie the purples, which no single wavelength makes: the one place a hue circle has no spectral
   order to break. */
const double violetEnd = 331.8, redEnd = 19.3;

/* Where Spectrum cuts the hue circle into a line: inside the purples (violetEnd to redEnd + 360), at the middle of the
   widest stretch of that arc holding none of the given hues. */
double purpleCut(Iterable<double> hues) {
  const lo = violetEnd, hi = redEnd + 360;
  final inArc = <double>[for (final h in hues) () { final x = ((h % 360) + 360) % 360; return x < lo ? x + 360 : x; }()]
      .where((x) => x > lo && x < hi).toList()..sort();
  final edges = [lo, ...inArc, hi];
  var cut = (lo + hi) / 2, widest = -1.0;
  for (var k = 0; k + 1 < edges.length; k++) {
    final w = edges[k + 1] - edges[k];
    if (w > widest) { widest = w; cut = (edges[k] + edges[k + 1]) / 2; }
  }
  return cut % 360;
}

/* A hue as a position on the line cut at `cut`: from `cut` − 360 (just past the cut, the reds) up to `cut` (the blues
   and violets before it). Lower is warmer. */
double hueOnLine(double h, double cut) { final x = ((h % 360) + 360) % 360; return x > cut ? x - 360 : x; }
