@Tags(['chrome-only'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart' show getCrc32; // a top-level function in archive 4.3.0: getCrc32(List<int>, [int crc = 0]) → int
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/measure/named_colours.dart';
import '../fixtures/fixtures.g.dart' as g;

/* A PNG that is only a header saying it is w × h, then IEND: enough for the size check, never decoded.
   (image 4.10.1's startDecode returns null if the bytes end before IEND, so the header alone reads as not-an-image.) */
Uint8List pngHeaderOnly(int w, int h) {
  final ihdr = BytesBuilder()
    ..add(ascii.encode('IHDR'))
    ..add([w >> 24, w >> 16 & 255, w >> 8 & 255, w & 255, h >> 24, h >> 16 & 255, h >> 8 & 255, h & 255, 8, 2, 0, 0, 0]);
  final body = ihdr.toBytes(), crc = getCrc32(body);
  return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, ...body, crc >> 24, crc >> 16 & 255, crc >> 8 & 255, crc & 255, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);
}

void main() {
  // The snapshots, a fixed answer sheet: test/fixtures/measure/recorded.json and named-colours.json were recorded
  // once from the TypeScript colour measure and culori (commit 6d3fb2b), before the Dart port replaced them.
  final recorded = jsonDecode(g.measureRecorded) as List;

  for (final r in recorded) {
    final file = r['file'] as String, centre = r['centre'] as bool;
    test('$file (${centre ? 'centre' : 'whole'}) measures as the snapshot holds it', () {
      // The Dart side always gets the file as stored, EXIF and all, and turns it
      // upright itself; for rotated.jpg the snapshot's number was taken from the
      // upright pixels (r['upright'] — see Task 3), so the two are comparable.
      final m = measureBytes(base64Decode(g.pictures[file]!), centre: centre);
      final tol = file.endsWith('.jpg') ? 0.6 : 0.2;
      final want = (r['lab'] as List).map((x) => (x as num).toDouble()).toList();
      expect((m.lab.l - want[0]).abs(), lessThanOrEqualTo(tol), reason: 'L* ${m.lab.l} vs ${want[0]}');
      expect((m.lab.a - want[1]).abs(), lessThanOrEqualTo(tol), reason: 'a* ${m.lab.a} vs ${want[1]}');
      expect((m.lab.b - want[2]).abs(), lessThanOrEqualTo(tol), reason: 'b* ${m.lab.b} vs ${want[2]}');
      expect((m.spread - (r['spread'] as num)).abs(), lessThanOrEqualTo(tol), reason: 'spread ${m.spread} vs ${r['spread']}');
      expect(m.name, r['name']);
      expect((m.width - (r['width'] as int)).abs(), lessThanOrEqualTo(1));
      expect((m.height - (r['height'] as int)).abs(), lessThanOrEqualTo(1));
    });
  }

  test('the colour name is the one the part is called after', () {
    expect(colourName((l: 37.8, a: -6.3, b: -4.6)), 'darkslategray');
    expect(colourName((l: 100, a: 0, b: 0)), 'white');
    expect(colourName((l: 0, a: 0, b: 0)), 'black');
  });

  test("the named colours are the snapshot's, in the snapshot's order", () {
    final want = jsonDecode(g.namedColours) as Map<String, dynamic>;
    expect(namedColours.keys.toList(), want.keys.toList());
    for (final k in want.keys) { expect(namedColours[k], want[k]); }
  });

  test('a photograph far past the size the cropper sends is refused before it is decoded', () {
    expect(() => measureBytes(pngHeaderOnly(6000, 6000)), throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'pixelLimit')));
  });

  test('a file that is not a picture is refused', () {
    expect(() => measureBytes(Uint8List.fromList(utf8.encode('not a picture'))),
        throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'notAnImage')));
  });

  test('a phone photo turned on its side by EXIF is measured upright', () {
    // rotated.jpg is 640 × 480 stored, orientation 6: upright it is 480 wide, 640 tall.
    final m = measureBytes(base64Decode(g.pictures['rotated.jpg']!), centre: false);
    expect(m.height, greaterThan(m.width));
  });

  test('a picture cut off before its pixels is refused, not thrown raw', () {
    final whole = base64Decode(g.pictures['rotated.jpg']!);
    final cut = Uint8List.sublistView(whole, 0, 600);
    expect(() => measureBytes(cut), throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'notAnImage')));
  });
}
