@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/theme.dart';

/* The page before the studio is drawn (web/index.html's loading screen and its body, and the installed app's splash from
   web/manifest.json) is on the studio's own canvas colour, so nothing jumps colour when the studio comes in. */
void main() {
  final canvas = '#${(PhonePalette.canvas.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  test('the loading screen and the page under it are the canvas colour', () {
    final html = File('web/index.html').readAsStringSync();
    final loading = RegExp(r'\.loading \{[^}]*background: (#[0-9A-Fa-f]{6});').firstMatch(html);
    final body = RegExp(r'<body style="background: (#[0-9A-Fa-f]{6})">').firstMatch(html);
    expect(loading?[1]?.toUpperCase(), canvas, reason: '#loading');
    expect(body?[1]?.toUpperCase(), canvas, reason: 'the body');
  });

  test("the installed app's splash and its bar are the canvas colour", () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    expect((manifest['background_color'] as String).toUpperCase(), canvas);
    expect((manifest['theme_color'] as String).toUpperCase(), canvas);
  });
}
