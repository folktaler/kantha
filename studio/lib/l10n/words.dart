import '../downloads/paper.dart';
import '../solver/compile.dart';
import '../solver/geometry.dart';
import '../solver/js_math.dart';
import '../solver/layouts.dart';
import 'app_localizations.dart';
import 'keyed.g.dart';

/* The lookups made by building a key. */
extension Words on L {
  String layoutTitle(LayoutKey k) => plainByKey(this, 'canvas.layouts.${k.name}.title')!;
  String layoutName(LayoutKey k) => plainByKey(this, 'canvas.layouts.${k.name}.name')!;
  String mountName(Mount m) => plainByKey(this, 'canvas.mounts.${m.name}.name')!;
  String stitchColour(String key) => plainByKey(this, 'canvas.stitchColours.$key')!;
  String notFillable(Unfillable u) => plainByKey(this, 'canvas.notFillable.${u.name}')!;
  String paperName(Paper p) => switch (p) { Paper.a4 => canvasPaperA4, Paper.letter => canvasPaperLetter };

  /* Written here, not in en.json: the unit
     after a length on the board ("4 cm"). */
  String cm(num v) => '${jsNum(v)} cm';
}
