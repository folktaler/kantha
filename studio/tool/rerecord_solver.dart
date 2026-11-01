/* Re-records the named templates in test/fixtures/solver/recorded.json from this Dart solver, when a template's
   objective changes by the owner's decision (Chess, Spectrum, Blocks and Heart, 1 November 2026). Every other
   template's record, from the TypeScript solver, is left as it is. A run's objective, fill and anchors are written as
   compile gives them; its solves are dealt with Node's recorded colour differences (the file's 'ciede') in place of
   this platform's, as solve_parity_test.dart's gate deals them, so the record does not hang on platform maths
   (Spectrum's hue angles excepted, as there). The start panels of those templates are dealt again too. Run in studio/,
   then tool/fixtures_to_dart.dart:
     dart run tool/rerecord_solver.dart contrast spectrum blocks heart */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/hue.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/solve.dart';
import 'package:kantha_studio/solver/start.dart';
import 'package:kantha_studio/solver/threads.dart';
import '../test/support/spread.dart';

double _d(Object? v) => (v as num).toDouble();
List<int> _ints(Object? v) => [for (final x in v as List) (x as num).toInt()];

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/rerecord_solver.dart <template> …');
    exit(64);
  }
  final keys = {for (final a in args) LayoutKey.values.byName(a).name};
  const path = 'test/fixtures/solver/recorded.json';
  final rec = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final poolJson = jsonDecode(File('test/fixtures/solver/pool-2026-09-11.json').readAsStringSync()) as Map<String, dynamic>;
  final labs = <Lab>[for (final l in poolJson['lab'] as List) (l: _d(l[0]), a: _d(l[1]), b: _d(l[2]))];
  final pool = Pool(lab: labs, lightness: [for (final x in poolJson['lightness'] as List) _d(x)],
      busy: [for (final b in poolJson['busy'] as List) b as bool]);
  final edge = [for (final e in poolJson['edge'] as List) e == null ? null : _d(e)];
  final n = labs.length;
  final dc = Float64List(n * n), dh = Float64List(n * n);
  for (final e in rec['ciede'] as List) {
    final k = (e['p'] as int) * n + (e['q'] as int);
    dc[k] = _d(e['dEChroma']);
    dh[k] = _d(e['dH']).abs();
  }
  List<num>? list(List<num>? v) => v?.toList();
  var runs = 0;
  for (final c in rec['cases'] as List) {
    for (final run in (c['runs'] as List).cast<Map<String, dynamic>>()) {
      if (!keys.contains(run['layout'])) continue;
      final input = ObjectiveInput(pool: pool, edge: edge, members: _ints(c['members']),
          mount: Mount.values.byName(run['mount'] as String), stock: _ints(c['stock']));
      final m = modelFor(LayoutKey.values.byName(run['layout'] as String), input);
      final o = m.obj;
      run['fills'] = m.fills;
      run['why'] = m.why?.name;
      run['anchors'] = {for (final e in m.anchors.entries) '${e.key}': e.value};
      run['obj'] = {
        'seamLTarget': list(o.seamLTarget), 'seamL': list(o.seamL), 'seamDE': list(o.seamDE), 'seamFrame': list(o.seamFrame),
        'boundary': list(o.boundary), 'targetL': list(o.targetL), 'wL': list(o.wL), 'targetHue': list(o.targetHue),
        'wHue': list(o.wHue), 'hueExclude': o.hueExclude?.toList(), 'targetColour': list(o.targetColour),
        'wColour': list(o.wColour),
        'perimeter': o.perimeter == null ? null : {'groundL': o.perimeter!.groundL, 'clearance': o.perimeter!.clearance,
            'weight': o.perimeter!.weight, 'cells': o.perimeter!.cells.toList()},
      };
      run['poolLightness'] = m.pool.lightness;
      final p = prepare(m.pool, o.distance);
      final prep = run['layout'] == 'spectrum' ? p
          : Prepared(p.n, p.de, p.dl, dh, dc, p.l, p.vw, p.busy, p.hue, p.grain, p.coherence);
      for (final s in (run['solves'] as List).cast<Map<String, dynamic>>()) {
        final got = solve(o, prep, input.stock, input.members, SolveOptions(seed: s['seed'] as int));
        if (got == null) {
          s..['grid'] = null..['rot'] = null..['total'] = null..['breakdown'] = null..['threads'] = null;
          continue;
        }
        final rot = orient(got.grid, o, prep).toList();
        s
          ..['grid'] = got.grid
          ..['rot'] = rot
          ..['total'] = got.total
          ..['breakdown'] = score(got.grid, o, prep, rot).toMap()
          ..['threads'] = [for (final t in rankThreads(got.grid, pool.lab).take(recommend)) t.thread.key];
      }
      runs++;
    }
  }
  // The start panels: the pool's pieces spread to 105, as small_test.dart deals them.
  final stock = spread([for (final s in poolJson['stock'] as List) s as int]);
  final hexByIndex = [for (final h in rec['hex'] as List) h['hex'] as String];
  final fabrics = [
    for (var i = 0; i < n; i++)
      Fabric(id: (poolJson['ids'] as List)[i] as String, name: '', lab: labs[i], busy: (poolJson['busy'] as List)[i] as bool,
          edge: edge[i], grain: null, stock: stock[i]),
  ];
  final dealt = {for (final l in layoutsFrom(fabrics)) l.key.name: l};
  final start = (rec['start'] as List).cast<Map<String, dynamic>>();
  start.removeWhere((e) => keys.contains(e['key']) && dealt[e['key']] == null);
  for (final e in start) {
    if (keys.contains(e['key'])) e['cells'] = [for (final c in dealt[e['key']]!.cells) {'hex': hexByIndex[c.fabric], 'rot': c.rot}];
  }
  File(path).writeAsStringSync(jsonEncode(rec));
  stdout.writeln('re-recorded $runs runs and the start panels of ${keys.join(', ')}');
}
