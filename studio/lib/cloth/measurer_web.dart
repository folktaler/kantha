/* The colour measure off the page's thread (web/measure_worker.js), one worker for the page, started with the first
   photo she picks. On the web there is one thread for the page, so measureImage there held the studio still (628 ms
   at most at 4 × CPU for a 1344 px crop, 1 November 2026), and nothing on the screen could move. The worker runs the
   same measureImage on the same pixels, so a cloth measures the same as it did. Where the worker cannot (it did not
   load, broke, or did not answer within measureWait), MeasurerGone says so, and the caller measures in place, as
   before (prepare_web.dart). */
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../measure/measure.dart';
import '../platform/release.dart' show pageBase, releaseFile;
import '../platform/worker_web.dart';

/* The longest a measure waits for the worker once the worker has begun it (time in its turn is not counted); past it
   that crop alone is measured in place, and the worker carries on with the rest. */
const measureWait = Duration(seconds: 30);

/* The worker could not measure: the caller measures in place. */
class MeasurerGone implements Exception {
  const MeasurerGone(this.why);
  final Object why;
  @override
  String toString() => 'MeasurerGone: $why';
}

PageWorker? _one;
PageWorker get _worker => _one ??= PageWorker(releaseFile('measure_worker.js', pageBase()).toString());

/* Starts the worker now, so it has loaded by the time a crop is measured. */
void warmMeasurer() => _worker.warm();

/* `rgba` (width × height RGBA pixels) measured by measureImage in the worker. Its buffer is handed over, not copied (a
   crop is up to 2500 × 2500 × 4 bytes, on old phones too): afterwards it is empty. Throws MeasureError as measureImage
   does, or MeasurerGone. */
Future<Measured> measureRgba(Uint8List rgba, int width, int height) => _measure(_worker, rgba, width, height, measureWait);

/* measureRgba by the worker at `url`, waiting `wait`. */
@visibleForTesting
Future<Measured> Function(Uint8List rgba, int width, int height) measurerAt(String url, {Duration wait = measureWait}) {
  final worker = PageWorker(url);
  return (rgba, width, height) => _measure(worker, rgba, width, height, wait);
}

Future<Measured> _measure(PageWorker worker, Uint8List rgba, int width, int height, Duration wait) async {
  // The whole buffer goes: a view of part of one is copied first, so only its own pixels go.
  final whole = rgba.offsetInBytes == 0 && rgba.lengthInBytes == rgba.buffer.lengthInBytes ? rgba : Uint8List.fromList(rgba);
  final pixels = whole.buffer.toJS;
  final Object? answer;
  try {
    // Sent once: the buffer goes with it, so a measure in place after reads the caller's own pixels, never this.
    answer = await worker.ask((id) => JSObject()
      ..['id'] = id.toJS
      ..['pixels'] = pixels
      ..['width'] = width.toJS
      ..['height'] = height.toJS, transfer: [pixels], wait: wait, from: WaitFrom.begin);
  } on TimeoutException catch (e) {
    throw MeasurerGone(e);
  } on WorkerGone catch (e) {
    throw MeasurerGone(e);
  }
  final m = answer! as Map<String, dynamic>;
  return switch (m['error']) {
    null => Measured.fromJson(m['measured'] as Map<String, dynamic>),
    'notAnImage' || 'pixelLimit' => throw MeasureError(m['error'] as String),
    // The worker could not measure it (out of memory, say).
    _ => throw MeasurerGone('${m['why'] ?? m['error']}'),
  };
}
