import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:material_color_utilities/material_color_utilities.dart';
import '../solver/geometry.dart' show maxLongSide;
import '../solver/hue.dart';
import '../solver/js_math.dart';
import 'named_colours.dart';

/* A cloth's colour, measured on the device: the centre 60 % of the square, 6 % in from each side of that, the
   average taken in XYZ D65 and turned into L*a*b*, how much the lightness varies,
   and the nearest CSS colour name. */
const double _centreFraction = 0.6, _featureInset = 0.06;

class Measured {
  const Measured({required this.lab, required this.name, required this.spread, required this.width, required this.height});
  final Lab lab;
  final String name;
  final double spread;
  final int width, height;
}

class MeasureError implements Exception {
  const MeasureError(this.key);
  final String key; // 'notAnImage' | 'pixelLimit'
  @override
  String toString() => 'MeasureError($key)';
}

/* Each 8-bit channel's XYZ (0–100) on its own. XYZ is linear in the linearised
   channels, so a pixel's XYZ is the sum of its three parts — the same sums
   ColorUtils.xyzFromArgb does, without making a list for every pixel. */
final List<List<double>> _xyzR = [for (var v = 0; v < 256; v++) ColorUtils.xyzFromArgb(ColorUtils.argbFromRgb(v, 0, 0))];
final List<List<double>> _xyzG = [for (var v = 0; v < 256; v++) ColorUtils.xyzFromArgb(ColorUtils.argbFromRgb(0, v, 0))];
final List<List<double>> _xyzB = [for (var v = 0; v < 256; v++) ColorUtils.xyzFromArgb(ColorUtils.argbFromRgb(0, 0, v))];

/* CIE's f(t), from ColorUtils.lstarFromY, which is 116·f(Y/100) − 16. */
double _labF(double t) => (ColorUtils.lstarFromY(t * 100) + 16) / 116;

Lab labFromXyz(double x, double y, double z) {
  final wp = ColorUtils.whitePointD65();
  final fx = _labF(x / wp[0]), fy = _labF(y / wp[1]), fz = _labF(z / wp[2]);
  return (l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz));
}

Lab _labOfPacked(int rgb) {
  final r = rgb >> 16 & 255, g = rgb >> 8 & 255, b = rgb & 255;
  return labFromXyz(_xyzR[r][0] + _xyzG[g][0] + _xyzB[b][0], _xyzR[r][1] + _xyzG[g][1] + _xyzB[b][1],
      _xyzR[r][2] + _xyzG[g][2] + _xyzB[b][2]);
}

final List<(String, Lab)> _named = [for (final e in namedColours.entries) (e.key, _labOfPacked(e.value))];

String colourName(Lab lab) {
  var best = _named.first.$1;
  var far = double.infinity;
  for (final (name, c) in _named) {
    final dl = lab.l - c.l, da = lab.a - c.a, db = lab.b - c.b;
    final d = math.sqrt(dl * dl + da * da + db * db);
    if (d < far) { far = d; best = name; }
  }
  return best;
}

double _round1(double v) => double.parse(v.toStringAsFixed(1));

Measured measureBytes(Uint8List bytes, {bool centre = true}) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) throw const MeasureError('notAnImage');
  final img.DecodeInfo? info;
  try {
    info = decoder.startDecode(bytes);
  } catch (_) {
    throw const MeasureError('notAnImage');
  }
  if (info == null || info.width == 0 || info.height == 0) throw const MeasureError('notAnImage');
  if (info.width * info.height > maxLongSide * maxLongSide * 4) throw const MeasureError('pixelLimit');
  final img.Image? decoded;
  try {
    decoded = decoder.decode(bytes);
  } catch (_) {
    // a truncated or damaged file: the decoder throws rather than returning null
    throw const MeasureError('notAnImage');
  }
  if (decoded == null) throw const MeasureError('notAnImage');
  return measureImage(decoded, centre: centre);
}

/* The measured square: the centre 60 % of the picture, 6 % in from each side of that. */
({int left, int top, int width, int height}) _box(img.Image image, bool centre) {
  final w = image.width, h = image.height;
  final keep = centre ? _centreFraction : 1.0;
  final innerW = jsRound(w * keep), innerH = jsRound(h * keep);
  final left = jsRound((w - innerW) / 2 + innerW * _featureInset);
  final top = jsRound((h - innerH) / 2 + innerH * _featureInset);
  return (left: left, top: top, width: math.max(1, math.min(w - left, jsRound(innerW * (1 - _featureInset * 2)))),
      height: math.max(1, math.min(h - top, jsRound(innerH * (1 - _featureInset * 2)))));
}

/* Its pixels, read in place. */
Iterable<img.Pixel> _region(img.Image image, ({int left, int top, int width, int height}) r) sync* {
  final it = image.getRange(r.left, r.top, r.width, r.height);
  while (it.moveNext()) { yield it.current; }
}

Measured measureImage(img.Image picture, {bool centre = true}) {
  // Plain 8-bit RGB first: a greyscale picture has no g or b to read, a palette picture
  // has indexes, not colours, and the package cannot crop a 4-bit one on a pixel boundary.
  final full = img.bakeOrientation(picture.convert(format: img.Format.uint8, numChannels: 3));
  // The colour is the mean of every pixel in linear light, taken before any resizing: a resize filters the
  // gamma-encoded values, which darkens fine light-and-dark texture (a 1-pixel black-and-white check 3000 pixels
  // square measured L* 59.9 instead of 76.1).
  var x = 0.0, y = 0.0, z = 0.0, n = 0;
  for (final p in _region(full, _box(full, centre))) {
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    x += _xyzR[r][0] + _xyzG[g][0] + _xyzB[b][0];
    y += _xyzR[r][1] + _xyzG[g][1] + _xyzB[b][1];
    z += _xyzR[r][2] + _xyzG[g][2] + _xyzB[b][2];
    n++;
  }
  // The spread of lightness, a measure of texture whose busy and edge cut-offs were set on pictures of at most
  // maxLongSide, is read as before from the picture brought down to that size.
  var image = full;
  if (math.max(image.width, image.height) > maxLongSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxLongSide, interpolation: img.Interpolation.cubic)
        : img.copyResize(image, height: maxLongSide, interpolation: img.Interpolation.cubic);
  }
  final box = _box(image, centre), ls = <double>[];
  for (final p in _region(image, box)) {
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    ls.add(ColorUtils.lstarFromY(_xyzR[r][1] + _xyzG[g][1] + _xyzB[b][1]));
  }
  final m = ls.length;
  final mean = labFromXyz(x / n, y / n, z / n);
  var sum = 0.0;
  for (var i = 0; i < m; i++) { sum += ls[i]; }
  final avg = sum / m;
  var sq = 0.0;
  for (var i = 0; i < m; i++) { final d = ls[i] - avg; sq += d * d; }
  return Measured(
    lab: (l: _round1(mean.l), a: _round1(mean.a), b: _round1(mean.b)),
    name: colourName(mean),
    spread: _round1(math.sqrt(sq / m)),
    width: box.width, height: box.height,
  );
}
