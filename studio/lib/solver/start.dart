import 'dart:math' as math;
import 'fabrics.dart';
import 'geometry.dart';
import 'layouts.dart';
import 'solve_layout.dart';
import 'compile.dart';
import 'score.dart' show Pool;

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
    var s = solveLayout(key, base, members, Mount.none, seed);
    if (key == LayoutKey.chain && (!s.fills || s.grid == null)) {
      s = solveLayout(key, Base(p.pool, p.edge, chainStartStock(p.pool, members, p.stock)), members, Mount.none, seed);
    }
    if (!s.fills || s.grid == null || s.rot == null) continue;
    out.add(StartLayout(key, [for (var i = 0; i < s.grid!.length; i++) StartCell(s.grid![i], hex[s.grid![i]], s.rot![i])]));
  }
  return out;
}

/* Chain makes every link of one cloth, which a box of one piece per cloth (the workshop's photos) cannot give. On the
   home page (owner, 1 November 2026) the cloth its links are made of (compile.dart oneClothOf) may then repeat once for
   each link on the start board; every other cloth keeps its own pieces. */
List<int> chainStartStock(Pool pool, List<int> members, List<int> stock) {
  final spec = layouts[LayoutKey.chain]!, out = [...stock];
  for (final MapEntry(key: z, value: r) in spec.rules.entries) {
    if (r.oneCloth == null) continue;
    final (:squares, :cloth) = oneClothOf(spec, z, pool, members, level1);
    if (cloth >= 0) out[cloth] = math.max(out[cloth], squares.length);
  }
  return out;
}
