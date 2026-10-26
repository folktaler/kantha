/* The home page's stacked panels, solved from the workshop's 47 sample photos by the studio's own
   solver when the site is built (spec decision 3; 2026-10-07 decision 6). The site serves the photos at
   /studio-start/ (copies are in test/fixtures/start-cloth/); their measured values are tool/start_cloth.json.
   Run in studio/, with the file to write, the home page's start-layouts.json:
     dart run tool/start_panels.dart <path to start-layouts.json> */
import 'dart:convert';
import 'dart:io';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/icons.dart';
import 'package:kantha_studio/solver/start.dart';

const _seed = 20260929;

Map<String, Object> startPanels(String json) {
  double d(Object? v) => (v as num).toDouble();
  final cloth = ((jsonDecode(json) as Map<String, dynamic>)['cloth'] as List).cast<Map<String, dynamic>>()
      .where((c) => (c['pieces'] as int) > 0).toList();
  final fabrics = [
    for (final c in cloth)
      Fabric(id: c['id'] as String, name: c['name'] as String, lab: (l: d(c['lab'][0]), a: d(c['lab'][1]), b: d(c['lab'][2])),
          busy: c['busy'] as bool?, edge: c['edge'] == null ? null : d(c['edge']),
          grain: c['grain'] == null ? null : (angle: d(c['grain']['angle']), coherence: d(c['grain']['coherence'])),
          stock: c['pieces'] as int),
  ];
  return {
    'source': 'studio/tool/start_panels.dart, from studio/tool/start_cloth.json',
    'seed': _seed,
    'layouts': [
      for (final l in layoutsFrom(fabrics, seed: _seed))
        {
          'key': l.key.name,
          'icon': layoutIconLevels(l.key),
          'cells': [
            for (final c in l.cells)
              {'hex': c.hex, 'img': cloth[c.fabric]['photo'] == null ? null : '/studio-start/${cloth[c.fabric]['photo']}', 'rot': c.rot},
          ],
        },
    ],
  };
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/start_panels.dart <path to start-layouts.json>');
    exit(64);
  }
  final out = startPanels(File('tool/start_cloth.json').readAsStringSync());
  File(args.single).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(out)}\n');
  stdout.writeln('wrote ${(out['layouts']! as List).length} start panels');
}
