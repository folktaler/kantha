@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/numbers.dart';
import 'package:kantha_studio/measure/measure.dart';

void main() {
  test('spread 10 separates the hand-marked prints from the hand-marked plains among the 47 recorded photos', () {
    // The photos are always in the repo: a missing directory is a broken path, not an absent fixture.
    final dir = Directory('test/fixtures/start-cloth');
    expect(dir.existsSync(), isTrue, reason: '${dir.path} is missing');
    final cloth = (jsonDecode(File('tool/start_cloth.json').readAsStringSync()) as Map<String, dynamic>)['cloth'] as List;
    final wrong = <String>[];
    for (final c in cloth.cast<Map<String, dynamic>>()) {
      if (c['busy'] == null || c['photo'] == null) continue;
      final m = measureBytes(File('${dir.path}/${c['photo']}').readAsBytesSync());
      if (busyOf(m.spread) != (c['busy'] as bool)) wrong.add('${c['name']}: spread ${m.spread}, marked ${c['busy']}');
    }
    expect(wrong, isEmpty);
  });
}
