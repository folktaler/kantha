/* A cloth as the solver sees it. Her cloths come from the shelf already measured. */
import 'package:material_color_utilities/material_color_utilities.dart';
import 'hue.dart';
import 'score.dart';

class Fabric {
  const Fabric({required this.id, required this.name, required this.lab, required this.busy, required this.edge,
      required this.grain, required this.stock});
  final String id, name;
  final Lab lab;
  final bool? busy;
  final double? edge;
  final ({double angle, double coherence})? grain;
  final int stock;
}

({Pool pool, List<double?> edge, List<int> stock}) poolOf(List<Fabric> fabrics) => (
      pool: Pool(
        lab: [for (final f in fabrics) f.lab],
        lightness: [for (final f in fabrics) f.lab.l],
        busy: [for (final f in fabrics) f.busy == true],
        grain: [for (final f in fabrics) f.grain?.angle],
        coherence: [for (final f in fabrics) f.grain?.coherence],
      ),
      edge: [for (final f in fabrics) f.edge],
      stock: [for (final f in fabrics) f.stock],
    );

/* A cloth's colour as #rrggbb, for a chip or a square with no photo. Within one
   step per channel of what culori gave (test/solver/small_test.dart). */
String hexOf(Lab lab) {
  final argb = ColorUtils.argbFromLab(lab.l, lab.a, lab.b);
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
