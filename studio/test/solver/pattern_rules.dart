/* The boxes the pattern rules (lib/solver/rules.dart, re-exported here) were tuned and checked on, read from the
   studio's files (the Sample box's photos, the 47 factory cloths and the tuning pool), and one case run on a box. Run
   in studio/. */
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:kantha_studio/data/numbers.dart' show busyOf, edgeOf;
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/hue.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/rules.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/solve.dart';

export 'package:kantha_studio/solver/rules.dart';

// ---- Boxes. ----

class Box {
  const Box(this.name, this.fabrics, {this.heldOut = false});
  final String name;
  final List<Fabric> fabrics;
  /* Never tuned on (see [heldOutBoxes]). */
  final bool heldOut;
  int get pieces => fabrics.fold(0, (a, f) => a + f.stock);

  /* The box with enough pieces for a board of n squares: each cloth's count times the least whole k that gives at least
     1.25 n pieces (k = 1 when the box already has them), so its proportions stay as they were. */
  ({Pool pool, List<double?> edge, List<int> stock, List<int> members}) forBoard(int n) {
    final k = math.max(1, (1.25 * n / pieces).ceil());
    final p = poolOf([for (final f in fabrics) Fabric(id: f.id, name: f.name, lab: f.lab, busy: f.busy, edge: f.edge,
        grain: f.grain, stock: f.stock * k)]);
    return (pool: p.pool, edge: p.edge, stock: p.stock, members: [for (var i = 0; i < fabrics.length; i++) i]);
  }
}
// ---- One case: a pattern, a box, a board, a seed. ----

class Case {
  Case(this.key, this.box, this.heldOut, this.size, this.seed, this.fills, this.why, this.solved, this.random, this.sorted,
      this.grid, this.colours, this.millis);
  final LayoutKey key;
  final String box;
  final bool heldOut;
  final BoardSize size;
  final int seed;
  /* False when the studio refuses to fill the pattern from this box (it fades the tile); then nothing is judged. */
  final bool fills;
  final String? why;
  final Judged? solved, random, sorted;
  final List<int>? grid;
  final List<Lab>? colours;
  final int millis;
  Outcome get outcome => fills ? solved!.rule.outcome : Outcome.cannot;
}

Case runCase(LayoutKey key, Box box, BoardSize g, int seed, {SolveOptions? options}) {
  final n = g.rows * g.cols, b = box.forBoard(n);
  final m = modelFor(key, ObjectiveInput(pool: b.pool, edge: b.edge, members: b.members, mount: Mount.none, stock: b.stock, size: g));
  Case refused(String why) => Case(key, box.name, box.heldOut, g, seed, false, why, null, null, null, null, null, 0);
  if (!m.fills) return refused(m.why?.name ?? 'refused');
  final prep = prepare(m.pool);
  final sw = Stopwatch()..start();
  final s = solve(m.obj, prep, b.stock, b.members, options ?? SolveOptions(seed: seed));
  final ms = sw.elapsedMilliseconds;
  if (s == null) return refused('no solve');
  final rand = randomGrid(b.stock, b.members, n, seed * 7919 + n);
  final sorted = sortedGrid(key, m, b.stock, b.members);
  return Case(key, box.name, box.heldOut, g, seed, true, null, judge(key, m, s.grid, b.stock, b.members, g),
      judge(key, m, rand, b.stock, b.members, g), sorted == null ? null : judge(key, m, sorted, b.stock, b.members, g),
      s.grid, b.pool.lab, ms);
}

/* The studio's pattern names, for the table (messages/en.json's titles). */
const Map<LayoutKey, String> patternName = {
  LayoutKey.contrast: 'Chess', LayoutKey.gradient: 'Gradient', LayoutKey.medallion: 'Centre', LayoutKey.wave: 'Wave',
  LayoutKey.framed: 'Border', LayoutKey.cross: 'Cross', LayoutKey.spectrum: 'Spectrum', LayoutKey.boro: 'Mixed',
  LayoutKey.blocks: 'Blocks', LayoutKey.medallionPrint: 'Ripple', LayoutKey.heart: 'Heart', LayoutKey.stripes: 'Stripes',
  LayoutKey.zigzag: 'Zigzag', LayoutKey.chain: 'Chain', LayoutKey.diamond: 'Diamond',
};

double _d(Object? v) => (v as num).toDouble();

/* The Sample box's pieces per cloth, as lib/data/sample_box.dart gives them (that file imports Flutter, so they are
   copied here; sample_box_test.dart holds the two equal). */
const List<int> samplePiecesHere = [12, 12, 34, 31, 12, 12, 40, 12, 12, 12];

const sampleFiles = ['red', 'navy', 'purple', 'turmeric', 'orange', 'dark-green', 'white', 'red-bandhani',
  'red-and-blue-block-print', 'teal-flower-print'];

/* The Sample box as a fresh install makes it: the ten photos in assets/sample/, measured by the studio's own measure,
   with [samplePiecesHere] pieces (lib/data/sample_box.dart). Run in studio/. */
Box sampleBox([List<int> pieces = samplePiecesHere]) => Box('Sample', [
      for (var k = 0; k < sampleFiles.length; k++)
        () {
          final m = measureBytes(File('assets/sample/${sampleFiles[k]}.jpg').readAsBytesSync());
          return Fabric(id: sampleFiles[k], name: sampleFiles[k], lab: m.lab, busy: busyOf(m.spread), edge: edgeOf(m.spread),
              grain: null, stock: pieces[k]);
        }(),
    ]);

/* The 47 factory cloths of tool/start_cloth.json, as measured from their photos on 26 October 2026. */
List<Fabric> startCloth() {
  final cloth = ((jsonDecode(File('tool/start_cloth.json').readAsStringSync()) as Map<String, dynamic>)['cloth'] as List)
      .cast<Map<String, dynamic>>();
  return [
    for (final c in cloth)
      Fabric(id: c['id'] as String, name: c['name'] as String, lab: (l: _d(c['lab'][0]), a: _d(c['lab'][1]), b: _d(c['lab'][2])),
          busy: c['busy'] as bool?, edge: c['edge'] == null ? null : _d(c['edge']), grain: null, stock: math.max(1, c['pieces'] as int)),
  ];
}

/* The tuning pool of 11 September 2026 (test/fixtures/solver/pool-2026-09-11.json), with its own counts. */
Box tuningBox() {
  final m = jsonDecode(File('test/fixtures/solver/pool-2026-09-11.json').readAsStringSync()) as Map<String, dynamic>;
  final lab = m['lab'] as List;
  return Box('Tuning pool', [
    for (var i = 0; i < lab.length; i++)
      Fabric(id: '${m['ids'][i]}', name: '${m['ids'][i]}', lab: (l: _d(lab[i][0]), a: _d(lab[i][1]), b: _d(lab[i][2])),
          busy: (m['busy'] as List)[i] as bool, edge: (m['edge'] as List)[i] == null ? null : _d((m['edge'] as List)[i]),
          grain: null, stock: (m['stock'] as List)[i] as int),
  ]);
}

double _hue180(Fabric f) { final x = hueOf(f.lab) % 360; return x > 180 ? x - 360 : x; }

List<Fabric> Function(List<Fabric>, int) _drawer(int seed) {
  final r = math.Random(seed);
  return (from, n) {
    final pick = List.of(from)..shuffle(r);
    return [for (final f in pick.take(n)) Fabric(id: f.id, name: f.name, lab: f.lab, busy: f.busy, edge: f.edge, grain: null,
        stock: 2 + r.nextInt(7))];
  };
}

/* Boxes drawn from the 47 factory cloths, each with 2–8 pieces of a cloth, seeded so every run draws the same:
   any colour (6, 12 and 20 cloths), a narrow lightness spread (8 cloths, L* 40–65) and warm hues only (10 cloths,
   hue −60° to 90°). All five were swept while tuning on 1 November 2026. */
List<Box> drawnBoxes() {
  final all = startCloth(), draw = _drawer(20261031);
  return [
    Box('Any 6', draw(all, 6)),
    Box('Any 12', draw(all, 12)),
    Box('Any 20', draw(all, 20)),
    Box('Narrow 8', draw([for (final f in all) if (f.lab.l >= 40 && f.lab.l <= 65) f], 8)),
    Box('Warm 10', draw([for (final f in all) if (chroma(f.lab) >= 10 && _hue180(f) >= -60 && _hue180(f) <= 90) f], 10)),
  ];
}

/* The held-out boxes, fixed on 1 November 2026 before any tuning of the audit's fixes and never tuned on: four boxes
   drawn afresh (seed 20261102, used nowhere else) from the 47 factory cloths, at every board size. Any 8 and Any 16
   (any colour), Mid 10 (L* 30–75) and Cool 10 (hue 120° to 300°, chroma 10 or more). The cloths themselves are not
   new: the 47 were in the tuning boxes too, so these test new boxes of known cloth, not new cloth. The 11 September
   2026 tuning (~/kantha canvas/reports/sweep-2026-09-11.md) used only the tuning pool at 5 × 7. */
List<Box> heldOutBoxes() {
  final all = startCloth(), draw = _drawer(20261102);
  double h360(Fabric f) => ((hueOf(f.lab) % 360) + 360) % 360;
  return [
    Box('Held Any 8', draw(all, 8), heldOut: true),
    Box('Held Any 16', draw(all, 16), heldOut: true),
    Box('Held Mid 10', draw([for (final f in all) if (f.lab.l >= 30 && f.lab.l <= 75) f], 10), heldOut: true),
    Box('Held Cool 10', draw([for (final f in all) if (chroma(f.lab) >= 10 && h360(f) >= 120 && h360(f) <= 300) f], 10), heldOut: true),
  ];
}

/* The boxes tuning may look at. */
List<Box> tuningBoxes() => [sampleBox(), tuningBox(), Box('All 47', startCloth()), ...drawnBoxes()];

List<Box> allBoxes() => [...tuningBoxes(), ...heldOutBoxes()];
