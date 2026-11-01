import 'dart:math' as math;
import 'fabrics.dart';
import 'geometry.dart';
import 'layouts.dart';
import 'solve_layout.dart';
import 'spec.dart';

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
    if (key == LayoutKey.chain && !s.fills) s = solveLayout(key, Base(p.pool, p.edge, _chainStock(p.stock)), members, Mount.none, seed);
    if (!s.fills || s.grid == null || s.rot == null) continue;
    out.add(StartLayout(key, [for (var i = 0; i < s.grid!.length; i++) StartCell(s.grid![i], hex[s.grid![i]], s.rot![i])]));
  }
  return out;
}

/* Chain makes every link of one cloth, which a box of one piece per cloth (the workshop's photos) cannot give. On the
   home page (owner, 1 November 2026) each cloth may then repeat up to the number of links on the start board. */
List<int> _chainStock(List<int> stock) {
  final links = fieldCells((layouts[LayoutKey.chain]!.rules[0]!.l! as LFromT).t, level1).where((v) => v == 0).length;
  return [for (final k in stock) math.max(k, links)];
}
