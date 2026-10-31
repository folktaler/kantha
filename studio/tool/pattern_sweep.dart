/* Every pattern over every board 3–12 × 3–12, every box of test/solver/pattern_rules.dart and several seeds, judged by
   its rules beside a random arrangement of the same pieces; writes the pass-rate tables as Markdown. With --sheet, also
   draws a contact sheet per box (every pattern at 7 × 5, 8 × 8, 3 × 12 and 12 × 12, flat colours) into that folder.
   Run in studio/ (about ten minutes on 12 cores):
     dart run tool/pattern_sweep.dart <table.md> [--seeds 3] [--sheet <folder>] */
import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import '../test/solver/pattern_rules.dart';

typedef Job = ({LayoutKey key, int box, BoardSize size, int seed});

const _sheetSizes = [(rows: 7, cols: 5), (rows: 8, cols: 8), (rows: 3, cols: 12), (rows: 12, cols: 12)];

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/pattern_sweep.dart <table.md> [--seeds 3] [--sheet <folder>]');
    exit(64);
  }
  String? opt(String name) { final i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : null; }
  final seeds = int.parse(opt('--seeds') ?? '3'), sheet = opt('--sheet');
  final boxes = allBoxes();
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
        final bx = allBoxes();
        return [for (var j = w; j < jobs.length; j += workers) runCase(jobs[j].key, bx[jobs[j].box], jobs[j].size, jobs[j].seed)];
      }),
  ]);
  final cases = [for (final p in parts) ...p];
  stderr.writeln('solved in ${sw.elapsed.inSeconds} s');
  File(args.first).writeAsStringSync(table(cases, boxes, seeds));
  stdout.writeln('wrote ${args.first}');
  if (sheet != null) {
    Directory(sheet).createSync(recursive: true);
    for (final box in [boxes[0], boxes[4], boxes[6]]) {
      final path = '$sheet/contact-${box.name.toLowerCase().replaceAll(' ', '-')}.png';
      File(path).writeAsBytesSync(img.encodePng(contactSheet(cases, box.name)));
      stdout.writeln('wrote $path');
    }
  }
}

String _pc(int k, int n) => n == 0 ? '–' : '${(100 * k / n).round()}';
double _avg(Iterable<double> v) { final x = v.where((d) => !d.isNaN).toList(); return x.isEmpty ? double.nan : x.reduce((a, b) => a + b) / x.length; }
String _f(double v) => v.isNaN ? '–' : v.toStringAsFixed(2);
String _name(LayoutKey k) => patternName[k] ?? k.name;

String table(List<Case> cases, List<Box> boxes, int seeds) {
  final out = StringBuffer()
    ..writeln('# Pattern checks: pass rates')
    ..writeln()
    ..writeln('Every board $boardMin–$boardMax × $boardMin–$boardMax, ${boxes.length} boxes '
        '(${boxes.map((b) => '${b.name}: ${b.fabrics.length} cloths, ${b.pieces} pieces').join('; ')}), $seeds seeds. '
        'Rule: the pattern\'s own rule (test/solver/pattern_rules.dart). Apart: no two edge-adjacent squares of one cloth. '
        'Random: the same rules on a random arrangement of the same pieces. A case the box cannot fill, or one the rule '
        'cannot judge (no spread to rank), is left out of the rates.')
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln('| Pattern | Judged | Rule pass % | Random pass % | Margin (points) | Mean statistic | Random mean | Apart pass % | Random apart % | Worst size |')
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final key in layoutKeys) {
    final mine = [for (final c in cases) if (c.key == key && c.fills && c.solved!.rule.applies) c];
    final pass = mine.where((c) => c.solved!.rule.passes).length, rpass = mine.where((c) => c.random!.rule.passes).length;
    final ap = [for (final c in cases) if (c.key == key && c.fills && c.solved!.apartApplies) c];
    var worst = '', worstRate = 2.0;
    for (var r = boardMin; r <= boardMax; r++) {
      for (var col = boardMin; col <= boardMax; col++) {
        final at = mine.where((c) => c.size == (rows: r, cols: col)).toList();
        if (at.isEmpty) continue;
        final rate = at.where((c) => c.solved!.rule.passes).length / at.length;
        if (rate < worstRate) { worstRate = rate; worst = '$r × $col (${(100 * rate).round()}%)'; }
      }
    }
    out.writeln('| ${_name(key)} | ${mine.length} | ${_pc(pass, mine.length)} | ${_pc(rpass, mine.length)} | '
        '${mine.isEmpty ? '–' : (100 * (pass - rpass) / mine.length).round()} | ${_f(_avg(mine.map((c) => c.solved!.rule.stat)))} | '
        '${_f(_avg(mine.map((c) => c.random!.rule.stat)))} | ${_pc(ap.where((c) => c.solved!.apart).length, ap.length)} | '
        '${_pc(ap.where((c) => c.random!.apart).length, ap.length)} | $worst |');
  }
  out..writeln()..writeln('## Per box (rule pass %, all sizes)')..writeln()
    ..writeln('| Pattern | ${boxes.map((b) => b.name).join(' | ')} |')
    ..writeln('|---|${boxes.map((_) => '---').join('|')}|');
  for (final key in layoutKeys) {
    final cells = <String>[];
    for (final b in boxes) {
      final mine = [for (final c in cases) if (c.key == key && c.box == b.name) c];
      final filled = mine.where((c) => c.fills).toList(), judged = filled.where((c) => c.solved!.rule.applies).toList();
      cells.add(filled.isEmpty ? 'cannot fill' : judged.isEmpty ? 'n/a' : _pc(judged.where((c) => c.solved!.rule.passes).length, judged.length));
    }
    out.writeln('| ${_name(key)} | ${cells.join(' | ')} |');
  }
  for (final key in layoutKeys) {
    out..writeln()..writeln('## ${_name(key)}: rule pass % by board (rows down, columns across); random in brackets')..writeln()
      ..writeln('| Rows \\ Cols | ${[for (var c = boardMin; c <= boardMax; c++) c].join(' | ')} |')
      ..writeln('|---|${[for (var c = boardMin; c <= boardMax; c++) '---'].join('|')}|');
    for (var r = boardMin; r <= boardMax; r++) {
      final row = <String>[];
      for (var col = boardMin; col <= boardMax; col++) {
        final at = [for (final c in cases) if (c.key == key && c.size == (rows: r, cols: col) && c.fills && c.solved!.rule.applies) c];
        row.add('${_pc(at.where((c) => c.solved!.rule.passes).length, at.length)} (${_pc(at.where((c) => c.random!.rule.passes).length, at.length)})');
      }
      out.writeln('| $r | ${row.join(' | ')} |');
    }
    final fails = [for (final c in cases) if (c.key == key && c.fills && c.solved!.rule.applies && !c.solved!.rule.passes) c];
    if (fails.isNotEmpty) {
      out..writeln()..writeln('Failing cases (first 12 of ${fails.length}):')..writeln();
      for (final c in fails.take(12)) { out.writeln('- ${c.box}, ${c.size.rows} × ${c.size.cols}, seed ${c.seed}: ${c.solved!.rule.detail}'); }
    }
    final rep = [for (final c in cases) if (c.key == key && c.fills && c.solved!.apartApplies && !c.solved!.apart) c];
    if (rep.isNotEmpty) {
      out..writeln()..writeln('Same-cloth neighbours in ${rep.length} cases, e.g. '
          '${rep.take(6).map((c) => '${c.box} ${c.size.rows} × ${c.size.cols} seed ${c.seed}: ${c.solved!.repeats}').join('; ')}.');
    }
  }
  out..writeln()..writeln(diamondVsCentre(cases));
  return out.toString();
}

/* Diamond against Centre: how alike their target maps are, and whether each one's boards follow Centre's map. */
String diamondVsCentre(List<Case> cases) {
  final diamond = LayoutKey.values.asNameMap()['diamond'];
  if (diamond == null) return '';
  final out = StringBuffer()
    ..writeln('## Diamond against Centre')
    ..writeln()
    ..writeln('ρ(maps): Spearman ρ between the two target maps. Then the mean ρ of each one\'s solved lightness against '
        'Centre\'s map and against Diamond\'s map.')
    ..writeln()
    ..writeln('| Board | ρ(maps) | Centre vs Centre map | Diamond vs Centre map | Diamond vs Diamond map | Centre vs Diamond map |')
    ..writeln('|---|---|---|---|---|---|');
  final rhoMaps = <double>[];
  for (var r = boardMin; r <= boardMax; r++) {
    for (var c = boardMin; c <= boardMax; c++) {
      final g = (rows: r, cols: c);
      final tc = targetMap(LayoutKey.medallion, g), td = targetMap(diamond, g);
      final rm = spearman(tc.toList(), td.toList());
      rhoMaps.add(rm);
      double vs(LayoutKey k, List<double> t) => _avg([
            for (final x in cases)
              if (x.key == k && x.size == g && x.fills) spearman([for (final f in x.grid!) x.colours![f].l], t),
          ]);
      if (r == c || r == boardMin || c == boardMin || (r, c) == (7, 5)) {
        out.writeln('| $r × $c | ${_f(rm)} | ${_f(vs(LayoutKey.medallion, tc))} | ${_f(vs(diamond, tc))} | ${_f(vs(diamond, td))} | ${_f(vs(LayoutKey.medallion, td))} |');
      }
    }
  }
  out..writeln()..writeln('Mean ρ(maps) over all 100 boards: ${_f(_avg(rhoMaps))}; '
      'boards where |ρ(maps)| ≥ 0.7: ${rhoMaps.where((x) => x.abs() >= 0.7).length} of 100.');
  return out.toString();
}

img.Image contactSheet(List<Case> cases, String box) {
  const px = 16, gap = 24, label = 18, left = 8;
  final w = left + _sheetSizes.length * (12 * px + gap), h = layoutKeys.length * (12 * px + label + gap) + 40;
  final im = img.Image(width: w, height: h)..clear(img.ColorRgb8(239, 235, 221));
  final ink = img.ColorRgb8(40, 36, 30);
  img.drawString(im, 'Box: $box. Each panel: pattern, rows x columns, seed 1. Flat colours, as measured.', font: img.arial14, x: left, y: 10, color: ink);
  for (var p = 0; p < layoutKeys.length; p++) {
    final key = layoutKeys[p], y0 = 40 + p * (12 * px + label + gap);
    for (var s = 0; s < _sheetSizes.length; s++) {
      final g = _sheetSizes[s], x0 = left + s * (12 * px + gap);
      final c = cases.where((c) => c.key == key && c.box == box && c.size == g && c.seed == 1).firstOrNull;
      final verdict = c == null || !c.fills ? 'cannot fill' : c.solved!.rule.passes ? 'pass' : c.solved!.rule.applies ? 'FAIL' : 'n/a';
      img.drawString(im, '${_name(key)} ${g.rows}x${g.cols} $box: $verdict', font: img.arial14, x: x0, y: y0, color: ink);
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
