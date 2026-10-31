@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/cloth/piece_finder_web.dart';
import 'package:kantha_studio/cloth/prepare.dart';
import 'package:web/web.dart' as web;

/* The web finder's own wait (piece_finder_web.dart), with a stand-in worker: one that hangs on a 1-pixel-wide picture
   and answers any other at once. */
void main() {
  const script = '''
onmessage = (e) => {
  if (e.data.width === 1) { for (;;) {} }
  postMessage(JSON.stringify({id: e.data.id, scale: 1, squares: [], groups: [], tiny: 0}));
};
''';

  Future<PickedPhoto> photo(int width) async {
    final pixels = web.ImageData(width.toJS, 2);
    final bitmap = await web.window.createImageBitmap(pixels).toDart;
    return PickedPhoto(Uint8List(0), width, 2, bitmap);
  }

  test('a find that times out stops the worker: the next find is answered on its own time', () async {
    final url = web.URL.createObjectURL(web.Blob(<JSAny>[script.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript')));
    const wait = Duration(seconds: 2);
    final finder = finderAt(url, wait: wait);
    final stuck = Stopwatch()..start();
    await expectLater(finder.find(await photo(1)), throwsA(isA<TimeoutException>()));
    expect(stuck.elapsed, greaterThanOrEqualTo(wait));
    final next = Stopwatch()..start();
    final answer = await finder.find(await photo(2));
    expect(answer.squares, isEmpty);
    // A fresh worker: well inside the wait, not behind the hung job.
    expect(next.elapsed, lessThan(wait));
    web.URL.revokeObjectURL(url);
  });
}
