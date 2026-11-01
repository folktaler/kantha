/* The colour measure off the page's thread (web/measure_worker.js), one worker for the page, started with the first
   photo she picks. On the web there is one thread for the page, so measureImage there held the studio still, about
   2.6 s for a photo's crop on this Mac, 10.8 s at 4 × CPU (1 November 2026), and nothing on the screen could move.
   The worker runs the same measureImage on the same pixels, so a cloth measures the same as it did. A worker that did
   not load (offline, the file gone) or broke is not asked again: the measure runs in place, as it did before. */
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image/image.dart' as img;
import '../measure/measure.dart';
import '../platform/release.dart' show pageBase, releaseFile;

_Measurer? _one;
_Measurer get _measurer => _one ??= _Measurer(releaseFile('measure_worker.js', pageBase()).toString());

/* Starts the worker now, so it has loaded by the time a crop is measured. */
void warmMeasurer() => _measurer;

/* `rgba` (width × height RGBA pixels) measured by measureImage in the worker; in place when there is none. Throws
   MeasureError as measureImage does. */
Future<Measured> measureRgba(Uint8List rgba, int width, int height) => _measurer.measure(rgba, width, height);

/* A measurer whose worker is the script at `url`; with `orInPlace` false, one whose worker failed says so rather than
   measuring in place, so a test knows the worker answered. */
@visibleForTesting
Future<Measured> Function(Uint8List rgba, int width, int height) measurerAt(String url, {bool orInPlace = true}) =>
    _Measurer(url, orInPlace: orInPlace).measure;

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external _Worker(JSString url);
  external void postMessage(JSAny? message, [JSArray<JSAny>? transfer]);
  external set onmessage(JSFunction f);
  external set onerror(JSFunction f);
}

extension type _Message._(JSObject _) implements JSObject {
  external JSAny? get data;
}

class _Measurer {
  _Measurer(String url, {this.orInPlace = true}) : _worker = _Worker(url.toJS) {
    _worker.onmessage = ((_Message e) {
      final m = jsonDecode((e.data! as JSString).toDart) as Map<String, dynamic>;
      if (m['type'] == 'ready') return;
      final w = _waiting.remove(m['id']);
      if (w == null) return;
      final error = m['error'] as String?;
      if (error == null) {
        w.done.complete(Measured.fromJson(m['measured'] as Map<String, dynamic>));
      } else if (error == 'notAnImage' || error == 'pixelLimit') {
        w.done.completeError(MeasureError(error));
      } else {
        // The worker could not measure it (out of memory, say): measured in place, as before.
        _fallBack(w);
      }
    }).toJS;
    // A worker that did not load or broke: what it held is measured in place, and so is every later photo.
    _worker.onerror = ((JSObject _) {
      _dead = true;
      final out = _waiting.values.toList();
      _waiting.clear();
      out.forEach(_fallBack);
    }).toJS;
  }

  final bool orInPlace;

  void _fallBack(_Ask w) => orInPlace ? w.done.complete(_inPlace(w.rgba, w.width, w.height))
      : w.done.completeError(StateError('the measure worker failed'));

  final _Worker _worker;
  final _waiting = <int, _Ask>{};
  var _next = 0;
  var _dead = false;

  Future<Measured> measure(Uint8List rgba, int width, int height) {
    if (_dead) return orInPlace ? _inPlace(rgba, width, height) : Future.error(StateError('the measure worker failed'));
    final id = ++_next, ask = _Ask(rgba, width, height);
    _waiting[id] = ask;
    // A copy is handed over, so the caller keeps its pixels (a cloth whose add fails is added again).
    final pixels = Uint8List.fromList(rgba).buffer.toJS;
    _worker.postMessage(JSObject()
      ..['id'] = id.toJS
      ..['pixels'] = pixels
      ..['width'] = width.toJS
      ..['height'] = height.toJS, [pixels].toJS);
    return ask.done.future;
  }
}

class _Ask {
  _Ask(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width, height;
  final done = Completer<Measured>();
}

Future<Measured> _inPlace(Uint8List rgba, int width, int height) async =>
    measureImage(img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, bytesOffset: rgba.offsetInBytes,
        numChannels: 4));
