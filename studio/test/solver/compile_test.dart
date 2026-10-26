@Tags(['chrome-only'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'recorded.dart';

Pool fixturePool() => Pool(lab: poolLab(), lightness: ds(poolFixture['lightness']),
    busy: [for (final b in poolFixture['busy'] as List) b as bool]);
List<double?> fixtureEdge() => [for (final e in poolFixture['edge'] as List) e == null ? null : d(e)];

void expectSame(List<num>? got, Object? want, String what) {
  if (want == null) { expect(got, isNull, reason: what); return; }
  final w = want as List;
  expect(got, isNotNull, reason: what);
  expect(got!.length, w.length, reason: what);
  for (var i = 0; i < w.length; i++) {
    final x = w[i] is bool ? ((w[i] as bool) ? 1 : 0) : d(w[i]);
    expect((got[i] - x).abs(), lessThanOrEqualTo(1e-12), reason: '$what[$i]');
  }
}

void main() {
  final pool = fixturePool(), edge = fixtureEdge();
  for (final c in recorded['cases'] as List) {
    group('${c['name']}', () {
      for (final run in c['runs'] as List) {
        test('${run['layout']} on ${run['mount']} compiles to the objective in the snapshot', () {
          final m = modelFor(LayoutKey.values.byName(run['layout'] as String), ObjectiveInput(
              pool: pool, edge: edge, members: ints(c['members']), mount: Mount.values.byName(run['mount'] as String),
              stock: ints(c['stock'])));
          expect(m.fills, run['fills']);
          expect(m.why?.name, run['why']);
          expect({for (final e in m.anchors.entries) '${e.key}': e.value}, run['anchors']);
          final o = run['obj'] as Map<String, dynamic>;
          expectSame(m.obj.seamLTarget, o['seamLTarget'], 'seamLTarget');
          expectSame(m.obj.seamL, o['seamL'], 'seamL');
          expectSame(m.obj.seamDE, o['seamDE'], 'seamDE');
          expectSame(m.obj.seamFrame, o['seamFrame'], 'seamFrame');
          expectSame(m.obj.boundary, o['boundary'], 'boundary');
          expectSame(m.obj.targetL, o['targetL'], 'targetL');
          expectSame(m.obj.wL, o['wL'], 'wL');
          expectSame(m.obj.targetHue, o['targetHue'], 'targetHue');
          expectSame(m.obj.wHue, o['wHue'], 'wHue');
          expectSame(m.obj.hueExclude?.map((b) => b ? 1 : 0).toList(), o['hueExclude'], 'hueExclude');
          expectSame(m.obj.targetColour, o['targetColour'], 'targetColour');
          expectSame(m.obj.wColour, o['wColour'], 'wColour');
          final per = o['perimeter'] as Map<String, dynamic>?;
          if (per == null) {
            expect(m.obj.perimeter, isNull);
          } else {
            expect(m.obj.perimeter!.groundL, d(per['groundL']));
            expectSame(m.obj.perimeter!.cells, per['cells'], 'perimeter.cells');
          }
          expectSame(m.pool.lightness, run['poolLightness'], 'pool lightness');
        });
      }
    });
  }
}
