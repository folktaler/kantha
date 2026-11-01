@Tags(['chrome-only'])
library;

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/solve.dart';
import 'package:kantha_studio/solver/threads.dart';
import 'compile_test.dart' show fixturePool, fixtureEdge;
import 'recorded.dart';

void expectClose(Object? got, Object? want, String what) {
  if (want is Map) {
    final g = got as Map;
    expect(g.keys.toSet(), want.keys.toSet(), reason: what);
    for (final k in want.keys) { expectClose(g[k], want[k], '$what.$k'); }
  } else if (want is num) {
    expect(((got as num) - want).abs(), lessThanOrEqualTo(1e-9), reason: what);
  } else {
    expect(got, want, reason: what);
  }
}

void main() {
  final pool = fixturePool(), edge = fixtureEdge();
  // Chrome's Math.atan2/sin/cos/exp/pow are not bit-identical to the Dart VM that recorded the
  // fixtures (Task 4 measured 932 of 10000 inputs against Node), so on the web a
  // different arrangement may come back: annealing from last-bit-different tables lands in another
  // local minimum, better or worse. One that differs passes only if it is whole, from the box's own
  // cloth, within stock, a local minimum of the solver's own moves, and the recorded arrangement still
  // scores as recorded (controller ruling, 6 Oct). The counts are printed, not required; the exactness
  // of the port is proven by the group below, which takes the platform's maths out of the solve.
  final platform = kIsWeb ? 'WEB' : 'VM';
  var matched = 0, differed = 0;
  tearDownAll(() {
    // ignore: avoid_print
    print('$platform: $matched arrangements match the record, $differed differ '
        '(of ${matched + differed} solved)');
  });

  for (final c in recorded['cases'] as List) {
    group('${c['name']}', () {
      for (final run in c['runs'] as List) {
        for (final s in run['solves'] as List) {
          test('${run['layout']} on ${run['mount']}, seed ${s['seed']}: the same arrangement, turns and score', () {
            final input = ObjectiveInput(pool: pool, edge: edge, members: ints(c['members']),
                mount: Mount.values.byName(run['mount'] as String), stock: ints(c['stock']));
            final key = LayoutKey.values.byName(run['layout'] as String);
            final m = modelFor(key, input);
            final prep = prepare(m.pool);
            final got = solve(m.obj, prep, input.stock, input.members, SolveOptions(seed: s['seed'] as int));
            if (s['grid'] == null) { expect(got, isNull); return; }
            final recordedGrid = ints(s['grid']);
            if (!listEquals(got!.grid, recordedGrid)) {
              differed++;
              // ignore: avoid_print
              print('$platform: ${c['name']} ${run['layout']} ${run['mount']} seed ${s['seed']} differs; '
                  'score ${got.total} against ${s['total']}');
              expect(got.grid, hasLength(cells), reason: 'shape');
              expect(got.grid.every(input.members.contains), isTrue, reason: 'only the box\'s own cloth');
              expect(withinStock(got.grid, input.stock), isTrue, reason: 'no cloth used more than it is in stock');
              expect((score(recordedGrid, m.obj, prep).total - d(s['total'])).abs(), lessThanOrEqualTo(1e-9),
                  reason: 'the recorded arrangement still scores as recorded');
              expect(isLocalMinimum(got.grid, m.obj, prep, input.stock, input.members), isTrue,
                  reason: 'no single move of the solver improves it');
              return;
            }
            expect(got.grid, recordedGrid, reason: 'grid');
            final rot = orient(got.grid, m.obj, prep).toList();
            expect(rot, ints(s['rot']), reason: 'rot');
            expect((got.total - d(s['total'])).abs(), lessThanOrEqualTo(1e-9), reason: 'total');
            expectClose(score(got.grid, m.obj, prep, rot).toMap(), s['breakdown'], 'breakdown');
            expect([for (final t in rankThreads(got.grid, pool.lab).take(recommend)) t.thread.key], s['threads']);
            matched++;
          });
        }
      }
    });
  }

  // The gate that proves the solver is the same on every platform: the same solves with the colour tables the Dart VM
  // computed when the fixtures were recorded (recorded.json 'cam16' and 'cam16Hue') in place of this platform's, so
  // the search is free of platform maths and must deal exactly what was recorded. Spectrum is left out: compile sets
  // its hue targets from hue itself, on this platform.
  group('with the recorded colour tables the solver deals every recorded arrangement', () {
    final n = pool.lab.length;
    final de = Float64List(n * n), dc = Float64List(n * n);
    for (final e in recorded['cam16'] as List) {
      final k = (e['p'] as int) * n + (e['q'] as int);
      de[k] = d(e['de']);
      dc[k] = d(e['dc']);
    }
    final hue = ds(recorded['cam16Hue']);
    for (final c in recorded['cases'] as List) {
      for (final run in c['runs'] as List) {
        if (run['layout'] == 'spectrum') continue;
        for (final s in run['solves'] as List) {
          if (s['grid'] == null) continue;
          test('${c['name']} ${run['layout']} on ${run['mount']}, seed ${s['seed']}', () {
            final input = ObjectiveInput(pool: pool, edge: edge, members: ints(c['members']),
                mount: Mount.values.byName(run['mount'] as String), stock: ints(c['stock']));
            final key = LayoutKey.values.byName(run['layout'] as String);
            final m = modelFor(key, input);
            final p = prepare(m.pool);
            final prep = Prepared(p.n, de, p.dl, dc, p.l, p.vw, p.busy, hue, p.grain, p.coherence);
            final got = solve(m.obj, prep, input.stock, input.members, SolveOptions(seed: s['seed'] as int))!;
            expect(got.grid, ints(s['grid']), reason: 'grid');
            expect((got.total - d(s['total'])).abs(), lessThanOrEqualTo(1e-9), reason: 'total');
            final rot = orient(got.grid, m.obj, prep).toList();
            expect(rot, ints(s['rot']), reason: 'rot');
            expectClose(score(got.grid, m.obj, prep, rot).toMap(), s['breakdown'], 'breakdown');
            // rankThreads() works from this platform's own tables, as the app will.
            expect([for (final t in rankThreads(got.grid, pool.lab).take(recommend)) t.thread.key], s['threads'],
                reason: 'threads');
          });
        }
      }
    }
  });
}
