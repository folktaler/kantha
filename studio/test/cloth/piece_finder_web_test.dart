@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/cloth/piece_finder_web.dart';
import 'package:kantha_studio/cloth/prepare.dart';
import 'package:web/web.dart' as web;

/* The web finder's own wait (piece_finder_web.dart), with a stand-in worker that is busy for 3 seconds with its first
   ask (as OpenCV.js loading on a slow line is) and answers each ask after at once. */
void main() {
  const script = '''
let first = true;
onmessage = (e) => {
  if (first) { first = false; const until = Date.now() + 3000; while (Date.now() < until) {} }
  postMessage(JSON.stringify({id: e.data.id, scale: 1, squares: [], groups: [], tiny: e.data.width}));
};
''';

  Future<PickedPhoto> photo(int width) async {
    final pixels = web.ImageData(width.toJS, 2);
    final bitmap = await web.window.createImageBitmap(pixels).toDart;
    return PickedPhoto(Uint8List(0), width, 2, bitmap);
  }

  test('a find that times out leaves the worker running: the next find is answered, by the same worker', () async {
    final url = web.URL.createObjectURL(web.Blob(<JSAny>[script.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript')));
    final finder = finderAt(url, wait: const Duration(seconds: 2));
    await expectLater(finder.find(await photo(1)), throwsA(isA<TimeoutException>()));
    // Asked while the worker is still busy with the first: answered once it is free, its own answer, not the first's.
    final answer = await finder.find(await photo(2));
    expect(answer.tiny, 2);
    web.URL.revokeObjectURL(url);
  });
}
