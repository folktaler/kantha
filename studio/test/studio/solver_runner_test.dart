import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/solver_runner.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/solver/wire.dart';
import '../fixtures/fixtures.g.dart' as g;

/* The demo pool fixture as a Base, without the database (so this also runs in Chrome). */
Base fixtureBase() {
  final m = jsonDecode(g.pool) as Map<String, dynamic>;
  final labs = m['lab'] as List, edge = m['edge'] as List;
  final p = poolOf([
    for (var i = 0; i < labs.length; i++)
      Fabric(id: 'KF-${i + 1}', name: 'KF-${i + 1}',
          lab: (l: (labs[i][0] as num).toDouble(), a: (labs[i][1] as num).toDouble(), b: (labs[i][2] as num).toDouble()),
          busy: (m['busy'] as List)[i] as bool, edge: edge[i] == null ? null : (edge[i] as num).toDouble(),
          grain: i.isEven ? (angle: i * 5.0, coherence: 0.5) : null, stock: (m['stock'] as List)[i] as int),
  ]);
  return Base(p.pool, p.edge, p.stock);
}

void main() {
  test('the pool crosses to the worker and back unchanged, so the worker solves what the isolate would', () {
    final b = fixtureBase();
    final back = baseFromJson(jsonDecode(baseToJson(b)) as Map<String, dynamic>);
    expect(baseToJson(back), baseToJson(b));
    final members = [for (var i = 0; i < b.stock.length; i++) i];
    final here = solveLayout(LayoutKey.contrast, b, members, Mount.none, 7);
    final there = solveLayout(LayoutKey.contrast, back, members, Mount.none, 7);
    expect(there.fills, here.fills);
    expect(there.grid, here.grid);
    expect(there.rot, here.rot);
  });

  test('every part of the pool crosses, visual weight too', () {
    final b = fixtureBase();
    final weighted = Base(Pool(lab: b.pool.lab, lightness: b.pool.lightness, busy: b.pool.busy,
        visualWeight: [for (var i = 0; i < b.stock.length; i++) i / 10], grain: b.pool.grain, coherence: b.pool.coherence),
        b.edge, b.stock);
    expect(baseFromJson(jsonDecode(baseToJson(weighted)) as Map<String, dynamic>).pool.visualWeight, weighted.pool.visualWeight);
    expect(baseFromJson(jsonDecode(baseToJson(b)) as Map<String, dynamic>).pool.visualWeight, isNull);
  });

  test('on a phone the solver runs in an isolate and answers as solveLayout does', () async {
    final b = fixtureBase(), runner = createSolverRunner()..setPool(b);
    addTearDown(runner.dispose);
    final members = [for (var i = 0; i < b.stock.length; i++) i];
    final s = await runner.solve(LayoutKey.wave, members, Mount.frame, 11);
    final direct = solveLayout(LayoutKey.wave, b, members, Mount.frame, 11);
    expect(s.fills, direct.fills);
    expect(s.grid, direct.grid);
    expect(s.rot, direct.rot);
    expect(s.grid, hasLength(cells));
  }, testOn: 'vm');
}
