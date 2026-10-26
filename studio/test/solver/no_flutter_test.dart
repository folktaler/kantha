@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the solver imports nothing from Flutter, so tools and the web worker can run it', () {
    for (final f in Directory('lib/solver').listSync(recursive: true).whereType<File>()) {
      final text = f.readAsStringSync();
      expect(text.contains('package:flutter'), isFalse, reason: f.path);
      expect(RegExp('''["']dart:ui["']''').hasMatch(text), isFalse, reason: f.path);
    }
  });
}
