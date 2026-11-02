import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/measure/measure.dart';
import 'package:web/web.dart' as web;

/* The colour measure's Web Worker, so measuring a photo does not hold the page still: the same measureImage the page
   ran, on the same pixels. Compiled to web/measure_worker.js by tool/prepare_web.sh.
   - {id, pixels, width, height}: the picture as RGBA bytes (an ArrayBuffer). As it begins one, {type: begin, id};
     the answer, as JSON: {id, measured} (Measured.toJson), or {id, error}, a MeasureError's key or 'failed'. */
@JS('self')
external web.DedicatedWorkerGlobalScope get _self;

extension type _Ask._(JSObject _) implements JSObject {
  external int get id;
  external JSArrayBuffer get pixels;
  external int get width;
  external int get height;
}

void main() {
  _self.onmessage = ((web.MessageEvent e) {
    final ask = e.data! as _Ask;
    // Begun: the page's wait for this one starts now, not while it waited its turn.
    _self.postMessage('{"type":"begin","id":${ask.id}}'.toJS);
    String answer;
    try {
      final pixels = ask.pixels.toDart;
      final m = measureImage(img.Image.fromBytes(width: ask.width, height: ask.height, bytes: pixels, numChannels: 4));
      answer = jsonEncode({'id': ask.id, 'measured': m.toJson()});
    } on MeasureError catch (error) {
      answer = jsonEncode({'id': ask.id, 'error': error.key});
    } on Object catch (error) {
      answer = jsonEncode({'id': ask.id, 'error': 'failed', 'why': '$error'});
    }
    _self.postMessage(answer.toJS);
  }).toJS;
  // Loaded and listening: a later error is a measure's, not a missing worker.
  _self.postMessage('{"type":"ready"}'.toJS);
}
