@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/data/numbers.dart' show edgeOf;
import 'package:kantha_studio/measure/measure.dart';
import '../../tool/measure_start_cloth.dart' show measuredPhotos;

/* The 14 photos of cloth on the floor carry no busy mark, so spread_marks_test passes them by. Each is cropped to the
   cloth (tool/crop_cloth.py), so a wrong photo or cut-away cloth shows here as another size or another colour. */
const _floorShot = {
  'KF-35.jpg': (292, 294), 'KF-36.jpg': (315, 284), 'KF-37.jpg': (379, 371), 'KF-38.jpg': (327, 318),
  'KF-39.jpg': (293, 293), 'KF-40.jpg': (376, 352), 'KF-41.jpg': (338, 335), 'KF-42.jpg': (301, 303),
  'KF-43.jpg': (311, 308), 'KF-44.jpg': (387, 369), 'KF-45.jpg': (326, 317), 'KF-46.jpg': (358, 388),
  'KF-47.jpg': (347, 341), 'KF-48.jpg': (311, 298),
};

/* tool/measure_start_cloth.dart wrote these colours and edges from these photos, rounded, so they agree to well within
   0.5 and to 0.0005 (a spread of 0.1). */
const _maxDeltaE = 0.5;

void main() {
  final json = jsonDecode(File('tool/start_cloth.json').readAsStringSync()) as Map<String, dynamic>;
  final cloth = (json['cloth'] as List).cast<Map<String, dynamic>>();
  final measured = measuredPhotos(json['source'] as String);

  test('the 14 floor-shot photos decode at their recorded size', () {
    for (final MapEntry(key: photo, value: (w, h)) in _floorShot.entries) {
      final p = img.decodeJpg(File('test/fixtures/start-cloth/$photo').readAsBytesSync());
      expect(p, isNotNull, reason: photo);
      expect((p!.width, p.height), (w, h), reason: photo);
    }
  });

  test('every photo measured again since it was cropped measures within $_maxDeltaE of its colour and at its edge', () {
    expect(measured, hasLength(32));
    expect(measured, containsAll(_floorShot.keys));
    for (final c in cloth.where((c) => measured.contains(c['photo']))) {
      final m = measureBytes(File('test/fixtures/start-cloth/${c['photo']}').readAsBytesSync());
      final r = (c['lab'] as List).cast<num>();
      final d = sqrt(pow(m.lab.l - r[0], 2) + pow(m.lab.a - r[1], 2) + pow(m.lab.b - r[2], 2));
      expect(d, lessThanOrEqualTo(_maxDeltaE), reason: '${c['photo']}: measured ${m.lab}, recorded $r');
      expect(c['edge'] as num, closeTo(edgeOf(m.spread), 0.0005), reason: '${c['photo']}: spread ${m.spread}');
    }
  });
}
