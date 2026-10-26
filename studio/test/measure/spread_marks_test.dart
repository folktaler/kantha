@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/numbers.dart';
import 'package:kantha_studio/measure/measure.dart';

void main() {
  // The photos are always in the repo: a missing directory is a broken path, not an absent fixture.
  final dir = Directory('test/fixtures/start-cloth');
  final cloth = ((jsonDecode(File('tool/start_cloth.json').readAsStringSync()) as Map<String, dynamic>)['cloth'] as List)
      .cast<Map<String, dynamic>>();
  double spreadOf(Map<String, dynamic> c) => measureBytes(File('${dir.path}/${c['photo']}').readAsBytesSync()).spread;

  test('every one of the 47 recorded photos has a busy mark, set by hand or by the measure', () {
    expect(dir.existsSync(), isTrue, reason: '${dir.path} is missing');
    expect(cloth, hasLength(47));
    for (final c in cloth) {
      expect(c['busy'], isA<bool>(), reason: '${c['photo']}');
      expect(c['busyBy'], anyOf('hand', 'measure'), reason: '${c['photo']}');
    }
  });

  test('spread 10 separates the hand-marked prints from the hand-marked plains, but for the exceptions noted', () {
    final wrong = <String>[];
    for (final c in cloth.where((c) => c['busyBy'] == 'hand')) {
      final spread = spreadOf(c);
      final agrees = busyOf(spread) == c['busy'];
      final note = c['busyNote'] as String?;
      // An exception says why; a mark the spread agrees with needs no note.
      if (agrees == (note != null && note.isNotEmpty)) {
        wrong.add('${c['name']}: spread $spread, marked ${c['busy']}, note ${note ?? 'none'}');
      }
    }
    expect(wrong, isEmpty);
  });

  test('data consistency: each measured busy mark is busyOf the photo\'s spread', () {
    for (final c in cloth.where((c) => c['busyBy'] == 'measure')) {
      expect(c['busy'], busyOf(spreadOf(c)), reason: '${c['photo']}');
    }
  });
}
