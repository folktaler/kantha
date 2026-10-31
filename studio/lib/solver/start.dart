import 'fabrics.dart';
import 'geometry.dart';
import 'layouts.dart';
import 'solve_layout.dart';

class StartCell {
  const StartCell(this.fabric, this.hex, this.rot);
  final int fabric;
  final String hex;
  final int rot;
}

class StartLayout {
  const StartLayout(this.key, this.cells);
  final LayoutKey key;
  final List<StartCell> cells;
}

/* Every template solved from the given cloth as the studio solves them; one it cannot fill is left out. */
List<StartLayout> layoutsFrom(List<Fabric> fabrics, {int seed = 20260929}) {
  if (fabrics.isEmpty) return const [];
  final p = poolOf(fabrics);
  final base = Base(p.pool, p.edge, p.stock);
  final members = [for (var i = 0; i < fabrics.length; i++) i];
  final hex = [for (final f in fabrics) hexOf(f.lab)];
  final out = <StartLayout>[];
  for (final key in layoutKeys) {
    final s = solveLayout(key, base, members, Mount.none, seed);
    if (!s.fills || s.grid == null || s.rot == null) continue;
    out.add(StartLayout(key, [for (var i = 0; i < s.grid!.length; i++) StartCell(s.grid![i], hex[s.grid![i]], s.rot![i])]));
  }
  return out;
}
