import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:kantha_studio/finder/cv.dart';
import 'package:kantha_studio/finder/find_squares.dart';
import 'package:kantha_studio/finder/group_squares.dart';
import 'package:kantha_studio/finder/opencv_js.dart';
import 'package:web/web.dart' as web;

/* The square finder's Web Worker: OpenCV.js (opencv_finder.js, beside this file) loads when the worker
   starts, so a studio that never starts it never downloads it. Answers are JSON. Compiled to
   web/finder_worker.js by tool/prepare_web.sh.
   - {id, photo, crops}: photo the file's bytes as an ArrayBuffer. The answer: the squares in the working
     picture's pixels, its size and scale, a group number per square (repeated cloths), and the time taken;
     with crops true, each square too, cut from the picture at pickedLongSide or less (never enlarged) and
     straightened, as RGB bytes in base64.
   - {id, cells}: cells, pictures of single squares (ArrayBuffers). The answer: a group number per picture,
     each measured on its middle 80 %. */
@JS('self')
external web.DedicatedWorkerGlobalScope get _self;

@JS('importScripts')
external void _importScripts(JSString url);

@JS('cv')
external JSPromise<JSObject> get _cvLoaded;

extension type _Ask._(JSObject _) implements JSObject {
  external int get id;
  external JSArrayBuffer? get photo;
  external bool? get crops;
  external JSArray<JSArrayBuffer>? get cells;
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
        final cv = await ready;
        await (ask.cells != null ? _group(cv, ask) : _find(cv, ask));
      } catch (error) {
        _self.postMessage(jsonEncode({'id': ask.id, 'error': '$error'}).toJS);
      }
    }());
  }).toJS;
}

/// The file's own pixels as BGR, as OpenCV's imread reads them: no colour profile applied.
Future<CvMat> _decode(OpenCvJs cv, JSArrayBuffer file) async {
  final bitmap = await _self
      .createImageBitmap(web.Blob([file].toJS),
          web.ImageBitmapOptions(colorSpaceConversion: 'none', premultiplyAlpha: 'none'))
      .toDart;
  final canvas = web.OffscreenCanvas(bitmap.width, bitmap.height);
  final ctx = canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D;
  ctx.drawImage(bitmap, 0, 0);
  final rgba = ctx.getImageData(0, 0, bitmap.width, bitmap.height).data.toDart;
  final four = cv.fromRgba(rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes), bitmap.width,
      bitmap.height);
  final bgr = cv.cvtColor(four, CvColour.rgbaToBgr);
  four.dispose();
  bitmap.close();
  return bgr;
}

Future<void> _find(OpenCvJs cv, _Ask ask) async {
  final clock = Stopwatch()..start();
  final photo = await _decode(cv, ask.photo!);
  final decodeMs = clock.elapsedMilliseconds;
  final f = findSquares(cv, photo);
  final findMs = clock.elapsedMilliseconds;
  final groups = groupsOf(cv, squareHistograms(cv, photo, f));
  final groupMs = clock.elapsedMilliseconds - findMs;
  final crops = ask.crops == true ? _crops(cv, photo, f) : null;
  photo.dispose();
  _self.postMessage(jsonEncode({
    'id': ask.id, 'width': f.width, 'height': f.height, 'scale': f.scale, 'side': f.side,
    'squares': [for (final q in f.squares) q], 'groups': groups, 'fromLines': f.fromLines,
    'outlineDropped': f.outlineDropped, 'ringDropped': f.ringDropped, 'decodeMs': decodeMs, 'outlineMs': f.outlineMs,
    'linesMs': f.linesMs, 'groupMs': groupMs, 'totalMs': findMs + groupMs, 'crops': ?crops,
  }).toJS);
}

/// Each square cut from the picture as the studio holds it (pickedLongSide on its long side at most, never
/// enlarged), straightened at its own size.
List<Map<String, Object>> _crops(OpenCvJs cv, CvMat photo, FoundSquares f) {
  const pickedLongSide = 2560; // lib/cloth/photo_source.dart; not imported, it brings Flutter with it
  final long = photo.rows > photo.cols ? photo.rows : photo.cols;
  final full = long > pickedLongSide ? cv.resizeArea(photo, pickedLongSide / long) : null;
  final picture = full ?? photo;
  final scale = f.scale * long / (full == null ? long : pickedLongSide);
  final out = <Map<String, Object>>[];
  for (final q in f.squares) {
    final side = cropSide(q, scale);
    final cell = cv.warpQuad(picture, Float32List.fromList([for (final v in q) v / scale]), side);
    final rgb = cv.cvtColor(cell, CvColour.bgrToRgb);
    out.add({'side': side, 'rgb': base64Encode(cv.bytes(rgb))});
    rgb.dispose();
    cell.dispose();
  }
  full?.dispose();
  return out;
}

Future<void> _group(OpenCvJs cv, _Ask ask) async {
  final clock = Stopwatch()..start();
  final hists = <LabHistograms>[];
  // An index over the JS array itself: a for-in over its toDart list made dart2js iterate every list in the finder
  // the slow, general way (measured 30 October 2026: the checker photo's line step 700 ms became 1,100 ms).
  final files = ask.cells!;
  for (var i = 0; i < files.length; i++) {
    final cell = await _decode(cv, files[i]);
    final m = cell.cols ~/ 10, n = cell.rows ~/ 10;
    final middle = cv.roi(cell, m, n, cell.cols - 2 * m, cell.rows - 2 * n);
    hists.add(labHistograms(cv, middle));
    middle.dispose();
    cell.dispose();
  }
  _self.postMessage(jsonEncode({'id': ask.id, 'groups': groupsOf(cv, hists), 'totalMs': clock.elapsedMilliseconds}).toJS);
}
