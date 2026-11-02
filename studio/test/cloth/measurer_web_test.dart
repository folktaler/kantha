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

  // A stand-in that says it has begun each ask, then is busy: `ms` per ask, 5 s for one 1 px wide.
  String busy(int ms) => '''
postMessage('{"type":"ready"}');
onmessage = (e) => {
  postMessage(JSON.stringify({type: 'begin', id: e.data.id}));
  const until = Date.now() + (e.data.width === 1 ? 5000 : $ms); while (Date.now() < until) {}
  postMessage(JSON.stringify({id: e.data.id, error: 'notAnImage'}));
};
''';
  String urlOf(String script) {
    final url = web.URL.createObjectURL(web.Blob(<JSAny>[script.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript')));
    addTearDown(() => web.URL.revokeObjectURL(url));
    return url;
  }

  test('time waiting its turn is not counted: 3 measures of 0.6 s each, a wait of 1 s, all answered', () async {
    final measure = measurerAt(urlOf(busy(600)), wait: const Duration(seconds: 1));
    final all = [for (var i = 0; i < 3; i++) measure(Uint8List(8), 2, 1)];
    for (final m in all) {
      await expectLater(m, throwsA(isA<MeasureError>()), reason: 'answered by the worker, not given up');
    }
  });

  test('one the worker does not finish within the wait goes alone (MeasurerGone, to be measured in place); the one '
      'behind it is not given up with it, but after a wait of its own', () async {
    final measure = measurerAt(urlOf(busy(100)), wait: const Duration(seconds: 1));
    final watch = Stopwatch()..start();
    final slow = measure(Uint8List(4), 1, 1);
    var nextGone = Duration.zero;
    final next = measure(Uint8List(8), 2, 1).catchError((Object e) {
      nextGone = watch.elapsed;
      throw e;
    });
    await expectLater(slow, throwsA(isA<MeasurerGone>()));
    final slowGone = watch.elapsed;
    await expectLater(next, throwsA(isA<MeasurerGone>()));
    expect(nextGone - slowGone, greaterThan(const Duration(milliseconds: 800)), reason: 'one at a time, never all at once');
  });

  test('a worker stuck on one: only that one is measured in place; the 3 behind it, never begun, are asked again of a '
      'new worker, from fresh pixels, and answered', () async {
    const stuck = '''
postMessage('{"type":"ready"}');
onmessage = (e) => {
  postMessage(JSON.stringify({type: 'begin', id: e.data.id}));
  if (e.data.width === 1) { while (true) {} }
  postMessage(JSON.stringify({id: e.data.id, error: 'notAnImage'}));
};
''';
    final measure = measurerAt(urlOf(stuck), wait: const Duration(milliseconds: 500));
    var fresh = 0;
    Uint8List again() {
      fresh++;
      return Uint8List(8);
    }
    final first = measure(Uint8List(4), 1, 1, again: () => Uint8List(4));
    final behind = [for (var i = 0; i < 3; i++) measure(Uint8List(8), 2, 1, again: again)];
    await expectLater(first, throwsA(isA<MeasurerGone>()), reason: 'the one it was stuck on: measured in place');
    for (final m in behind) {
      await expectLater(m, throwsA(isA<MeasureError>()), reason: 'answered by the new worker');
    }
    expect(fresh, 3, reason: 'each sent again from its own pixels afresh');
  });
}

typedef RGBA = ({Uint8List pixels, int width, int height});
