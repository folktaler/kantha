/* A template's icon as grey levels: one
   level per square, row by row. A level g is drawn rgb(g, round(g·0.985), round(g·0.93)). */
import 'geometry.dart';
import 'js_math.dart';
import 'layouts.dart';
import 'spec.dart';

double _value(LayoutKey key, int r, int c) {
  if (key == LayoutKey.medallionPrint) return 1 - Ramps.printMedallion(r, c, level1);
  if (key == LayoutKey.spectrum) return 0.25 + 0.5 * ((200 - Ramps.spectrumHue(0, c, level1)) / 180);
  if (key == LayoutKey.contrast) return (r + c) % 2 == 0 ? 1 : 0.05;
  if (key == LayoutKey.boro) return ((r * 7 + c * 3) % 5) / 4;
  if (key == LayoutKey.gradient) return Ramps.gradientT(r, c, level1);
  final spec = layouts[key]!, z = spec.zones[r * a4.cols + c], rule = spec.rules[z];
  if (rule?.colour != null) return 0.3;
  if (rule?.family != null) return z < 3 ? const [0.2, 0.55, 0.85][z] : 0.5;
  final l = rule?.l;
  if (l is LFromT) return l.t(r, c, level1);
  return 0.95;
}

List<int> layoutIconLevels(LayoutKey key) => [
      for (var r = 0; r < a4.rows; r++)
        for (var c = 0; c < a4.cols; c++) jsRound(28 + _value(key, r, c).clamp(0.0, 1.0) * 200),
    ];
