@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/layouts.dart';
import '../../tool/start_panels.dart';
import '../fixtures/fixtures.g.dart' as g;
import '../support/studio_fixture.dart' show spread;

void main() {
  test('the start panels: templates the sample cloth can fill, 35 squares each, photos at the site\'s /studio-start/', () {
    final p = jsonDecode(g.pool) as Map<String, dynamic>;
    final stock = spread([for (final s in p['stock'] as List) s as int]);
    final labs = p['lab'] as List;
    final json = jsonEncode({'source': 'test', 'cloth': [
      for (var i = 0; i < labs.length; i++) {'id': 'KF-${i + 1}', 'name': 'KF-${i + 1} cloth', 'lab': labs[i],
        'busy': (p['busy'] as List)[i], 'edge': (p['edge'] as List)[i], 'grain': null, 'pieces': stock[i], 'inBox': stock[i],
        'photo': 'KF-${i + 1}.jpg'},
    ]});
    final out = startPanels(json);
    final layouts = out['layouts']! as List;
    expect(layouts, isNotEmpty);
    for (final l in layouts.cast<Map<String, Object?>>()) {
      expect(LayoutKey.values.map((k) => k.name), contains(l['key']));
      expect((l['icon']! as List).length, 35);
      final cells = (l['cells']! as List).cast<Map<String, Object?>>();
      expect(cells.length, 35);
      expect(cells.every((c) => (c['img']! as String).startsWith('/studio-start/KF-')), isTrue);
    }
  });

  test('every photo the start cloth names is in test/fixtures/start-cloth', () {
    final cloth = (jsonDecode(File('tool/start_cloth.json').readAsStringSync()) as Map<String, dynamic>)['cloth'] as List;
    expect(cloth, hasLength(47));
    for (final c in cloth.cast<Map<String, dynamic>>()) {
      if (c['photo'] == null) continue;
      expect(File('test/fixtures/start-cloth/${c['photo']}').existsSync(), isTrue, reason: '${c['photo']}');
    }
  });
}
