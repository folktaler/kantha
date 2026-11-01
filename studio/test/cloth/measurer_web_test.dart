@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/measurer_web.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:web/web.dart' as web;
import '../fixtures/fixtures.g.dart' as g;

/* The measure's worker (web/measure_worker.js; tool/prepare_web.sh compiles it and copies it beside this file) reads
   every colour exactly as measureImage did on the page: the same L*a*b*, name, spread and measured size, number for
   number, on every one of the measure's fixtures (a 3000 px check among them), from the solid copy preparePhoto hands
   it as from the crop itself. */
void main() {
  RGBA rgbaOf(Uint8List file) {
    final picture = img.decodeImage(file)!.convert(format: img.Format.uint8, numChannels: 4);
    return (pixels: Uint8List.fromList(picture.toUint8List()), width: picture.width, height: picture.height);
  }

  Measured onPage(RGBA p) => measureImage(img.Image.fromBytes(width: p.width, height: p.height,
      bytes: p.pixels.buffer, bytesOffset: p.pixels.offsetInBytes, numChannels: 4));

  Uint8List solid(Uint8List rgba) {
    final s = Uint8List.fromList(rgba);
    for (var i = 3; i < s.length; i += 4) {
      s[i] = 255;
    }
    return s;
  }

  test('a photo measured in the worker, from its solid copy, reads as the crop did on the page, number for number',
      () async {
    final measure = measurerAt('measure_worker.js');
    expect(g.pictures.length, greaterThanOrEqualTo(10));
    for (final MapEntry(:key, :value) in g.pictures.entries) {
      final p = rgbaOf(base64Decode(value));
      expect((await measure(solid(p.pixels), p.width, p.height)).toJson(), onPage(p).toJson(), reason: key);
    }
  });

  test('the pixels are handed over, not copied: the buffer the caller gave is empty after', () async {
    final measure = measurerAt('measure_worker.js');
    final p = rgbaOf(base64Decode(g.pictures['noise.png']!));
    final handed = solid(p.pixels);
    await measure(handed, p.width, p.height);
    expect(handed.lengthInBytes, 0);
  });

  test('with no worker to load, MeasurerGone, so the caller measures in place; and the next is tried again', () async {
    final measure = measurerAt('no-such-worker.js');
    final p = rgbaOf(base64Decode(g.pictures['noise.png']!));
    await expectLater(measure(solid(p.pixels), p.width, p.height), throwsA(isA<MeasurerGone>()));
    await expectLater(measure(solid(p.pixels), p.width, p.height), throwsA(isA<MeasurerGone>()));
  });

  test('a worker that does not answer within the wait: MeasurerGone, and the next measure is not kept behind it',
      () async {
    // Busy for 5 s with a first ask of width 1; answers any other at once.
    const script = '''
postMessage('{"type":"ready"}');
onmessage = (e) => {
  if (e.data.width === 1) { const until = Date.now() + 5000; while (Date.now() < until) {} }
  postMessage(JSON.stringify({id: e.data.id, error: 'notAnImage'}));
};
''';
    final url = web.URL.createObjectURL(web.Blob(<JSAny>[script.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript')));
    addTearDown(() => web.URL.revokeObjectURL(url));
    final measure = measurerAt(url, wait: const Duration(seconds: 1));
    await expectLater(measure(Uint8List(4), 1, 1), throwsA(isA<MeasurerGone>()));
    final watch = Stopwatch()..start();
    await expectLater(measure(Uint8List(8), 2, 1), throwsA(isA<MeasureError>()));
    expect(watch.elapsedMilliseconds, lessThan(1000), reason: 'a fresh worker answered, not the busy one');
  });
}

typedef RGBA = ({Uint8List pixels, int width, int height});
