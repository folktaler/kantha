@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/* Spec 2026-10-07, decision 1: the demo box goes from the app — no Box 0, no demo rule, no demo name,
   and its photos are not in the bundle. */
void main() {
  test('nothing in the app is about a demo box', () {
    final pattern = RegExp(r'demo|box ?0', caseSensitive: false);
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) found.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(found, isEmpty);
  });

  test('the app ships no Box 0 photos', () {
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('box0')));
    expect(Directory('assets/box0').existsSync(), isFalse);
  });
}
