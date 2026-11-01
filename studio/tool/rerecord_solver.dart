/* Re-records the named templates (or `all`) in test/fixtures/solver/recorded.json from this Dart solver, when a
   template's objective changes (Chess, Spectrum, Blocks and Heart, 1 November 2026; every template the same day, when
   the colour difference became CAM16-UCS and the lightness fit squared). Run on the Dart VM, it also writes the
   colour tables the solves read ('cam16': each pair's ΔE′ and a′b′ distance; 'cam16Hue': each cloth's hue), so
   solve_parity_test.dart's gate can deal them in place of another platform's maths (Spectrum excepted, whose targets
   compile computes from hue itself). The start panels of those templates are dealt again too. Run in studio/, then
   tool/fixtures_to_dart.dart:
     dart run tool/rerecord_solver.dart all */
import 'dart:convert';
import 'dart:io';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/families.dart';
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
  final keys = args.contains('all') ? {for (final k in LayoutKey.values) k.name} : {for (final a in args) LayoutKey.values.byName(a).name};
  const path = 'test/fixtures/solver/recorded.json';
  final rec = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final poolJson = jsonDecode(File('test/fixtures/solver/pool-2026-09-11.json').readAsStringSync()) as Map<String, dynamic>;
  final labs = <Lab>[for (final l in poolJson['lab'] as List) (l: _d(l[0]), a: _d(l[1]), b: _d(l[2]))];
  final pool = Pool(lab: labs, lightness: [for (final x in poolJson['lightness'] as List) _d(x)],
      busy: [for (final b in poolJson['busy'] as List) b as bool]);
  final edge = [for (final e in poolJson['edge'] as List) e == null ? null : _d(e)];
  final n = labs.length;
  final tables = prepare(pool, Distance.cam16Ucs);
  rec['cam16'] = [for (var p = 0; p < n; p++) for (var q = 0; q < n; q++) {'p': p, 'q': q, 'de': tables.de[p * n + q], 'dc': tables.dc[p * n + q]}];
  rec['cam16Hue'] = tables.hue;
  // The colour families (families_test.dart), by the same CAM16 measure.
  for (final f in (rec['families'] as List).cast<Map<String, dynamic>>()) {
    final all = [for (var i = 0; i < n; i++) i];
    final got = colourFamilies(labs, f['case'] == 'pool' ? all : all.sublist(0, 12), 3);
    f['result'] = got == null ? null : {'medoids': got.medoids, 'family': got.family};
  }
  List<num>? list(List<num>? v) => v?.toList();
  var runs = 0;
  // Every template has its runs in every case, one per mount, with the seeds of the case's first run: the templates
  // added after the TypeScript (stripes, zigzag, chain, diamond) get theirs here the first time.
  for (final c in (rec['cases'] as List).cast<Map<String, dynamic>>()) {
    final list = (c['runs'] as List).cast<Map<String, dynamic>>();
    final seeds = [for (final s in (list.first['solves'] as List).cast<Map<String, dynamic>>()) s['seed']];
    for (final k in LayoutKey.values) {
      if (!keys.contains(k.name) || list.any((r) => r['layout'] == k.name)) continue;
      for (final mount in Mount.values) {
        c['runs'].add(<String, dynamic>{'layout': k.name, 'mount': mount.name, 'solves': [for (final s in seeds) {'seed': s}]});
      }
    }
  }
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
        'wColour': list(o.wColour), 'hueCut': o.hueCut,
        'perimeter': o.perimeter == null ? null : {'groundL': o.perimeter!.groundL, 'clearance': o.perimeter!.clearance,
            'weight': o.perimeter!.weight, 'cells': o.perimeter!.cells.toList()},
      };
      run['poolLightness'] = m.pool.lightness;
      final prep = prepare(m.pool, o.distance);
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
