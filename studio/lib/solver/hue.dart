import 'dart:math' as math;
import 'js_math.dart';

typedef Lab = ({double l, double a, double b});

class Ciede2000 {
  const Ciede2000(this.dL, this.dC, this.dH, this.dE, this.dEChroma);
  final double dL, dC, dH, dE, dEChroma;
}

const double _rad = math.pi / 180;
const double _pow25_7 = 6103515625.0; // 25 ** 7, exact

double _hueAngle(double b, double aPrime) {
  if (aPrime == 0 && b == 0) return 0;
  final h = math.atan2(b, aPrime) / _rad;
  return h < 0 ? h + 360 : h;
}

Ciede2000 ciede2000(Lab lab1, Lab lab2) {
  final l1 = lab1.l, a1 = lab1.a, b1 = lab1.b;
  final l2 = lab2.l, a2 = lab2.a, b2 = lab2.b;

  final cbar = (jsHypot2(a1, b1) + jsHypot2(a2, b2)) / 2;
  final cbar7 = math.pow(cbar, 7.0).toDouble();
  final g = 0.5 * (1 - math.sqrt(cbar7 / (cbar7 + _pow25_7)));

  final a1p = (1 + g) * a1;
  final a2p = (1 + g) * a2;
  final c1p = jsHypot2(a1p, b1);
  final c2p = jsHypot2(a2p, b2);
  final h1p = _hueAngle(b1, a1p);
  final h2p = _hueAngle(b2, a2p);

  final dLp = l2 - l1;
  final dCp = c2p - c1p;

  final product = c1p * c2p;
  var dhp = 0.0;
  if (product != 0) {
    dhp = h2p - h1p;
    if (dhp > 180) {
      dhp -= 360;
    } else if (dhp < -180) {
      dhp += 360;
    }
  }
  final dHp = 2 * math.sqrt(product) * math.sin((dhp / 2) * _rad);

  final lbarp = (l1 + l2) / 2;
  final cbarp = (c1p + c2p) / 2;

  var hbarp = h1p + h2p;
  if (product != 0) {
    if ((h1p - h2p).abs() <= 180) {
      hbarp = (h1p + h2p) / 2;
    } else if (h1p + h2p < 360) {
      hbarp = (h1p + h2p + 360) / 2;
    } else {
      hbarp = (h1p + h2p - 360) / 2;
    }
  }

  final t = 1
      - 0.17 * math.cos((hbarp - 30) * _rad)
      + 0.24 * math.cos(2 * hbarp * _rad)
      + 0.32 * math.cos((3 * hbarp + 6) * _rad)
      - 0.20 * math.cos((4 * hbarp - 63) * _rad);

  final q = (hbarp - 275) / 25;
  final dTheta = 30 * math.exp(-(q * q));
  final cbarp7 = math.pow(cbarp, 7.0).toDouble();
  final rc = 2 * math.sqrt(cbarp7 / (cbarp7 + _pow25_7));
  final lm50 = lbarp - 50, lm50sq = lm50 * lm50;
  final sl = 1 + (0.015 * lm50sq) / math.sqrt(20 + lm50sq);
  final sc = 1 + 0.045 * cbarp;
  final sh = 1 + 0.015 * cbarp * t;
  final rt = -math.sin(2 * dTheta * _rad) * rc;

  final l = dLp / sl, c = dCp / sc, h = dHp / sh;
  return Ciede2000(dLp, dCp, dHp, math.sqrt(l * l + c * c + h * h + rt * c * h),
      math.sqrt(math.max(0.0, c * c + h * h + rt * c * h)));
}

double hueOf(Lab lab) => math.atan2(lab.b, lab.a) * 180 / math.pi;
double chroma(Lab lab) => jsHypot2(lab.a, lab.b);
double angleGap(double p, double q) => ((((p - q).remainder(360)) + 540).remainder(360) - 180).abs();
double chromaDistance(Lab a, Lab b) => ciede2000(a, b).dEChroma;
