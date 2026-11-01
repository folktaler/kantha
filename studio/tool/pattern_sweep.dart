/* Every pattern over every board 3–12 × 3–12, every box of test/solver/pattern_rules.dart and several seeds, judged by
   its rules beside two baselines (a random and a sorted arrangement of the same pieces); writes the tables as
   Markdown. The unit is a pattern on one box at one board size: its outcome is the outcome most of its seeds give, so
   the seeds measure how steady a unit is and do not count as more data. Pass rates carry Wilson 95% intervals over
   the units the box can make. The held-out boxes are reported apart.
   With --sheet, also draws a contact sheet for the Sample, Any 12 and Narrow 8 boxes (every pattern at 7 × 5, 8 × 8,
   3 × 12 and 12 × 12, seed 1, flat colours) into that folder, and writes there grids.json, those panels' colours, for
   a before-and-after sheet. Run in studio/:
     dart run tool/pattern_sweep.dart <table.md> [--seeds 3] [--sheet <folder>] [--only tuning|held-out] */
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import '../test/solver/pattern_rules.dart';

typedef Job = ({LayoutKey key, int box, BoardSize size, int seed});

const _sheetSizes = [(rows: 7, cols: 5), (rows: 8, cols: 8), (rows: 3, cols: 12), (rows: 12, cols: 12)];
const _sheetBoxes = ['Sample', 'Any 12', 'Narrow 8'];

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/pattern_sweep.dart <table.md> [--seeds 3] [--sheet <folder>] [--only tuning|held-out]');
    exit(64);
  }
  String? opt(String name) { final i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : null; }
  final seeds = int.parse(opt('--seeds') ?? '3'), sheet = opt('--sheet'), only = opt('--only');
  List<Box> boxesNow() => switch (only) { 'tuning' => tuningBoxes(), 'held-out' => heldOutBoxes(), _ => allBoxes() };
  final boxes = boxesNow();
  final jobs = <Job>[
    for (final key in layoutKeys)
      for (var b = 0; b < boxes.length; b++)
        for (var r = boardMin; r <= boardMax; r++)
          for (var c = boardMin; c <= boardMax; c++)
            for (var s = 1; s <= seeds; s++) (key: key, box: b, size: (rows: r, cols: c), seed: s),
  ];
  final workers = Platform.numberOfProcessors;
  final sw = Stopwatch()..start();
  stderr.writeln('${jobs.length} cases on $workers workers');
  final parts = await Future.wait([
    for (var w = 0; w < workers; w++)
      Isolate.run(() {
        final bx = boxesNow();
        return [for (var j = w; j < jobs.length; j += workers) runCase(jobs[j].key, bx[jobs[j].box], jobs[j].size, jobs[j].seed)];
      }),
  ]);
  final cases = [for (final p in parts) ...p];
  stderr.writeln('solved in ${sw.elapsed.inSeconds} s');
  File(args.first).writeAsStringSync(table(cases, boxes, seeds));
  stdout.writeln('wrote ${args.first}');
  if (sheet != null) {
    Directory(sheet).createSync(recursive: true);
    for (final name in _sheetBoxes) {
      if (!boxes.any((b) => b.name == name)) continue;
      final path = '$sheet/contact-${name.toLowerCase().replaceAll(' ', '-')}.png';
      File(path).writeAsBytesSync(img.encodePng(contactSheet(cases, name)));
      stdout.writeln('wrote $path');
    }
    File('$sheet/grids.json').writeAsStringSync(jsonEncode([
      for (final c in cases)
        if (c.seed == 1 && _sheetBoxes.contains(c.box) && _sheetSizes.contains(c.size))
          {'key': c.key.name, 'box': c.box, 'rows': c.size.rows, 'cols': c.size.cols, 'verdict': _verdict(c),
            'hex': c.fills ? [for (final f in c.grid!) hexOf(c.colours![f])] : null},
    ]));
  }
}

String _verdict(Case c) => !c.fills ? 'cannot fill' : switch (c.solved!.rule.outcome) {
      Outcome.pass => 'pass', Outcome.fail => 'FAIL', Outcome.cannot => 'cannot' };
String _name(LayoutKey k) => patternName[k] ?? k.name;
String _pc(int k, int n) => n == 0 ? '–' : '${(100 * k / n).round()}';
String _ci(int k, int n) { if (n == 0) return '–'; final w = wilson(k, n); return '${_pc(k, n)} [${(100 * w.lo).round()}–${(100 * w.hi).round()}]'; }

/* One unit: a pattern on a box at a board size, over its seeds. */
class Unit {
  Unit(this.cases);
  final List<Case> cases;
  Outcome _major(Outcome Function(Case) of) {
    final n = {for (final o in Outcome.values) o: cases.where((c) => of(c) == o).length};
    if (n[Outcome.cannot]! * 2 > cases.length) return Outcome.cannot;
    return n[Outcome.pass]! * 2 > cases.length - n[Outcome.cannot]! ? Outcome.pass : Outcome.fail;
  }
  Outcome get solved => _major((c) => c.outcome);
  Outcome get random => _major((c) => c.fills ? c.random!.rule.outcome : Outcome.cannot);
  Outcome? get sorted => cases.any((c) => c.fills && c.sorted == null) ? null
      : _major((c) => c.fills ? c.sorted!.rule.outcome : Outcome.cannot);
  bool get steady => cases.every((c) => c.outcome == cases.first.outcome);
  bool? get apart => cases.any((c) => c.fills && c.solved!.apartApplies) ? cases.every((c) => !c.fills || c.solved!.apart) : null;
  bool? get sortedApart => cases.any((c) => c.fills && c.sorted != null && c.sorted!.apartApplies)
      ? cases.every((c) => !c.fills || c.sorted == null || c.sorted!.apart) : null;
  bool get refused => cases.every((c) => !c.fills);
}

Map<(LayoutKey, String, BoardSize), Unit> unitsOf(List<Case> cases) {
  final by = <(LayoutKey, String, BoardSize), List<Case>>{};
  for (final c in cases) { (by[(c.key, c.box, c.size)] ??= []).add(c); }
  return {for (final e in by.entries) e.key: Unit(e.value)};
}

String _summary(String title, List<Unit> all) {
  final out = StringBuffer()
    ..writeln('## $title')
    ..writeln()
    ..writeln('| Pattern | Units | Pass | Fail | Cannot (refused + rule) | Pass % of makeable [95% CI] | Random pass % | Sorted pass % | '
        'Margin over sorted (points) | Apart % | Sorted apart % | Steady over seeds % |')
    ..writeln('|---|---|---|---|---|---|---|---|---|---|---|---|');
  for (final key in layoutKeys) {
    final u = [for (final x in all) if (x.cases.first.key == key) x];
    final judged = u.where((x) => x.solved != Outcome.cannot).toList();
    final pass = judged.where((x) => x.solved == Outcome.pass).length;
    final refused = u.where((x) => x.refused).length, cannot = u.length - judged.length;
    final rpass = judged.where((x) => x.random == Outcome.pass).length;
    final sorts = judged.map((x) => x.sorted).toList();
    final spass = sorts.any((s) => s == null) ? null : sorts.where((s) => s == Outcome.pass).length;
    final ap = [for (final x in judged) if (x.apart != null) x.apart!];
    final sap = [for (final x in judged) if (x.sortedApart != null) x.sortedApart!];
    out.writeln('| ${_name(key)} | ${u.length} | $pass | ${judged.length - pass} | $cannot ($refused + ${cannot - refused}) | '
        '${_ci(pass, judged.length)} | ${_pc(rpass, judged.length)} | ${spass == null ? '–' : _pc(spass, judged.length)} | '
        '${spass == null || judged.isEmpty ? '–' : (100 * (pass - spass) / judged.length).round()} | '
        '${_pc(ap.where((a) => a).length, ap.length)} | ${_pc(sap.where((a) => a).length, sap.length)} | ${_pc(judged.where((x) => x.steady).length, judged.length)} |');
  }
  return out.toString();
}

String table(List<Case> cases, List<Box> boxes, int seeds) {
  final units = unitsOf(cases);
  final tuning = [for (final u in units.values) if (!u.cases.first.heldOut) u];
  final held = [for (final u in units.values) if (u.cases.first.heldOut) u];
  final out = StringBuffer()
    ..writeln('# Pattern checks: outcomes')
    ..writeln()
    ..writeln('Every board $boardMin–$boardMax × $boardMin–$boardMax, ${boxes.length} boxes '
        '(${boxes.map((b) => '${b.name}${b.heldOut ? ' (held out)' : ''}: ${b.fabrics.length} cloths, ${b.pieces} pieces').join('; ')}), '
        '$seeds seeds. A unit is one pattern on one box at one board size; its outcome is its seeds\' majority. '
        'Cannot: the studio refuses the box (refused), or no arrangement of its pieces could meet the rule (rule). '
        'Pass % is of the units the box can make, with a Wilson 95% interval. Random and sorted: the same rules on a '
        'random and on a sorted arrangement of the same pieces (test/solver/pattern_rules.dart). Apart: no two '
        'edge-adjacent squares of one cloth, every seed. Solve time: median ${_medianMs(cases)} ms a case.')
    ..writeln()
    ..writeln(_summary('Tuning boxes', tuning))
    ..writeln(_summary('Held-out boxes (never tuned on)', held))
    ..writeln('## Per box (pass % of makeable units, with their number; "cannot" when it can make none)')
    ..writeln()
    ..writeln('| Pattern | ${boxes.map((b) => b.name).join(' | ')} |')
    ..writeln('|---|${boxes.map((_) => '---').join('|')}|');
  for (final key in layoutKeys) {
    final cells = <String>[];
    for (final b in boxes) {
      final u = [for (final x in units.values) if (x.cases.first.key == key && x.cases.first.box == b.name) x];
      final judged = u.where((x) => x.solved != Outcome.cannot).toList();
      cells.add(judged.isEmpty ? 'cannot' : '${_pc(judged.where((x) => x.solved == Outcome.pass).length, judged.length)} (${judged.length})');
    }
    out.writeln('| ${_name(key)} | ${cells.join(' | ')} |');
  }
  for (final key in layoutKeys) {
    final fails = [for (final c in cases) if (c.key == key && c.outcome == Outcome.fail) c];
    final cannot = [for (final c in cases) if (c.key == key && c.fills && c.outcome == Outcome.cannot) c];
    final rep = [for (final c in cases) if (c.key == key && c.fills && c.solved!.apartApplies && !c.solved!.apart) c];
    if (fails.isEmpty && cannot.isEmpty && rep.isEmpty) continue;
    out..writeln()..writeln('## ${_name(key)}')..writeln();
    if (fails.isNotEmpty) {
      out.writeln('Failing cases (first 12 of ${fails.length}):');
      for (final c in fails.take(12)) { out.writeln('- ${c.box}, ${c.size.rows} × ${c.size.cols}, seed ${c.seed}: ${c.solved!.rule.detail}'); }
    }
    if (cannot.isNotEmpty) {
      out.writeln('${fails.isEmpty ? '' : '\n'}Cases the box cannot make by the rule (first 6 of ${cannot.length}):');
      for (final c in cannot.take(6)) { out.writeln('- ${c.box}, ${c.size.rows} × ${c.size.cols}: ${c.solved!.rule.detail}'); }
    }
    if (rep.isNotEmpty) {
      out.writeln('\nSame-cloth neighbours in ${rep.length} cases, e.g. '
          '${rep.take(6).map((c) => '${c.box} ${c.size.rows} × ${c.size.cols} seed ${c.seed}: ${c.solved!.repeats}').join('; ')}.');
    }
  }
  out..writeln()..writeln(diamondVsCentre());
  return out.toString();
}

int _medianMs(List<Case> cases) {
  final ms = [for (final c in cases) if (c.fills) c.millis]..sort();
  return ms.isEmpty ? 0 : ms[ms.length ~/ 2];
}

double _avg(Iterable<double> v) { final x = v.where((d) => !d.isNaN).toList(); return x.isEmpty ? double.nan : x.reduce((a, b) => a + b) / x.length; }
String _f(double v) => v.isNaN ? '–' : v.toStringAsFixed(2);

/* Diamond against Centre: how alike their target maps are. */
String diamondVsCentre() {
  final rhoMaps = <double>[];
  for (var r = boardMin; r <= boardMax; r++) {
    for (var c = boardMin; c <= boardMax; c++) {
      final g = (rows: r, cols: c);
      rhoMaps.add(spearman(targetMap(LayoutKey.medallion, g).toList(), targetMap(LayoutKey.diamond, g).toList()));
    }
  }
  return '## Diamond against Centre\n\nSpearman ρ between the two target maps, mean over all 100 boards: '
      '${_f(_avg(rhoMaps))}; boards where |ρ| ≥ 0.7: ${rhoMaps.where((x) => x.abs() >= 0.7).length} of 100.';
}

img.Image contactSheet(List<Case> cases, String box) {
  const px = 16, gap = 24, label = 18, left = 8;
  final w = left + _sheetSizes.length * (12 * px + gap) + 60, h = layoutKeys.length * (12 * px + label + gap) + 40;
  final im = img.Image(width: w, height: h)..clear(img.ColorRgb8(239, 235, 221));
  final ink = img.ColorRgb8(40, 36, 30);
  img.drawString(im, 'Box: $box. Each panel: pattern, rows x columns, seed 1. Flat colours, as measured.', font: img.arial14, x: left, y: 10, color: ink);
  for (var p = 0; p < layoutKeys.length; p++) {
    final key = layoutKeys[p], y0 = 40 + p * (12 * px + label + gap);
    for (var s = 0; s < _sheetSizes.length; s++) {
      final g = _sheetSizes[s], x0 = left + s * (12 * px + gap);
      final c = cases.where((c) => c.key == key && c.box == box && c.size == g && c.seed == 1).firstOrNull;
      img.drawString(im, '${_name(key)} ${g.rows}x${g.cols}: ${c == null ? '–' : _verdict(c)}', font: img.arial14, x: x0, y: y0, color: ink);
      if (c == null || !c.fills) continue;
      for (var i = 0; i < c.grid!.length; i++) {
        final hex = int.parse(hexOf(c.colours![c.grid![i]]).substring(1), radix: 16);
        final x = x0 + (i % g.cols) * px, y = y0 + label + (i ~/ g.cols) * px;
        img.fillRect(im, x1: x, y1: y, x2: x + px - 2, y2: y + px - 2, color: img.ColorRgb8(hex >> 16, (hex >> 8) & 255, hex & 255));
      }
    }
  }
  return im;
}
