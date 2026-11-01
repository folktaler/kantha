@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/measurer_web.dart';
import 'package:kantha_studio/measure/measure.dart';
import '../fixtures/fixtures.g.dart' as g;

/* The measure's worker (web/measure_worker.js; tool/prepare_web.sh compiles it and copies it beside this file) reads
   every colour exactly as measureImage did on the page: the same L*a*b*, name, spread and measured size, number for
   number, on every one of the measure's fixtures (a 3000 px check among them). */
void main() {
  RGBA rgbaOf(Uint8List file) {
    final picture = img.decodeImage(file)!.convert(format: img.Format.uint8, numChannels: 4);
    return (pixels: Uint8List.fromList(picture.toUint8List()), width: picture.width, height: picture.height);
  }

  Measured onPage(RGBA p) => measureImage(img.Image.fromBytes(width: p.width, height: p.height,
      bytes: p.pixels.buffer, bytesOffset: p.pixels.offsetInBytes, numChannels: 4));

  void same(Measured a, Measured b, String what) {
    expect(a.toJson(), b.toJson(), reason: what);
  }

  test('a photo measured in the worker reads as it did on the page, number for number', () async {
    final measure = measurerAt('measure_worker.js', orInPlace: false);
    expect(g.pictures.length, greaterThanOrEqualTo(10));
    for (final MapEntry(:key, :value) in g.pictures.entries) {
      final p = rgbaOf(base64Decode(value));
      same(await measure(p.pixels, p.width, p.height), onPage(p), key);
    }
  });

  test('the pixels handed in stay with the caller', () async {
    final measure = measurerAt('measure_worker.js', orInPlace: false);
    final p = rgbaOf(base64Decode(g.pictures['noise.png']!));
    final kept = Uint8List.fromList(p.pixels);
    await measure(p.pixels, p.width, p.height);
    expect(p.pixels, kept);
  });

  test('with no worker to load, the photo is measured on the page, as before', () async {
    final measure = measurerAt('no-such-worker.js');
    final p = rgbaOf(base64Decode(g.pictures['noise.png']!));
    same(await measure(p.pixels, p.width, p.height), onPage(p), 'in place');
  });
}

typedef RGBA = ({Uint8List pixels, int width, int height});
