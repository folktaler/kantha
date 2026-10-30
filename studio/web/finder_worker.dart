import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:kantha_studio/finder/cv.dart';
import 'package:kantha_studio/finder/find_squares.dart';
import 'package:kantha_studio/finder/opencv_js.dart';
import 'package:web/web.dart' as web;

/* The square finder's Web Worker: OpenCV.js (opencv_finder.js, beside this file) loads when the worker
   starts, so a studio that never starts it never downloads it. Each message is {id, photo}, photo the
   file's bytes as an ArrayBuffer; each answer is JSON: the squares in the working picture's pixels, its
   size and scale, and the time taken. Compiled to web/finder_worker.js by tool/prepare_web.sh. */
@JS('self')
external web.DedicatedWorkerGlobalScope get _self;

@JS('importScripts')
external void _importScripts(JSString url);

@JS('cv')
external JSPromise<JSObject> get _cvLoaded;

extension type _Ask._(JSObject _) implements JSObject {
  external int get id;
  external JSArrayBuffer get photo;
}

void main() {
  _importScripts('opencv_finder.js'.toJS);
  final ready = _cvLoaded.toDart.then((m) {
    // Loaded and started: how long that took, from the worker's own start.
    _self.postMessage('{"type":"ready","ms":${_self.performance.now().round()}}'.toJS);
    return OpenCvJs(m);
  });
  // Listening at once: a message that came while OpenCV.js was starting waits for it rather than being lost.
  _self.onmessage = ((web.MessageEvent e) {
    final ask = e.data! as _Ask;
    unawaited(() async {
      try {
        await _find(await ready, ask);
      } catch (error) {
        _self.postMessage(jsonEncode({'id': ask.id, 'error': '$error'}).toJS);
      }
    }());
  }).toJS;
}

Future<void> _find(OpenCvJs cv, _Ask ask) async {
  final clock = Stopwatch()..start();
  final bitmap = await _self
      .createImageBitmap(web.Blob([ask.photo].toJS),
          // The file's own pixels, as OpenCV's imread reads them: no colour profile applied.
          web.ImageBitmapOptions(colorSpaceConversion: 'none', premultiplyAlpha: 'none'))
      .toDart;
  final canvas = web.OffscreenCanvas(bitmap.width, bitmap.height);
  final ctx = canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D;
  ctx.drawImage(bitmap, 0, 0);
  final rgba = ctx.getImageData(0, 0, bitmap.width, bitmap.height).data.toDart;
  final four = cv.fromRgba(rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes), bitmap.width,
      bitmap.height);
  final photo = cv.cvtColor(four, CvColour.rgbaToBgr);
  four.dispose();
  bitmap.close();
  final decodeMs = clock.elapsedMilliseconds;
  final f = findSquares(cv, photo);
  photo.dispose();
  _self.postMessage(jsonEncode({
    'id': ask.id, 'width': f.width, 'height': f.height, 'scale': f.scale, 'side': f.side,
    'squares': [for (final q in f.squares) q], 'fromLines': f.fromLines, 'outlineDropped': f.outlineDropped,
    'ringDropped': f.ringDropped, 'decodeMs': decodeMs, 'outlineMs': f.outlineMs, 'linesMs': f.linesMs,
    'totalMs': clock.elapsedMilliseconds,
  }).toJS);
}
