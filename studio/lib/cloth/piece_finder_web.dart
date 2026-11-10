/* The finder's worker (web/finder_worker.js), one for the page, started the first time the Add a piece sheet opens. It
   is handed the picture the sheet already read, as RGBA pixels, so its squares are in that picture's pixels. */
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:web/web.dart' as web;
import '../platform/canvas_web.dart';
import '../platform/release.dart' show pageBase, releaseFile;
import '../platform/worker_web.dart';
import 'piece_finder.dart';
import 'prepare.dart' show PickedPhoto;

_WorkerFinder? _one;
PieceFinder? create() => _one ??= _WorkerFinder(releaseFile('finder_worker.js', pageBase()).toString());

/* A finder whose worker is the script at `url`, that gives up on an ask after `wait`. */
@visibleForTesting
PieceFinder finderAt(String url, {Duration wait = finderWait}) => _WorkerFinder(url, wait: wait);

class _WorkerFinder implements PieceFinder {
  _WorkerFinder(String url, {this.wait = finderWait}) : _worker = PageWorker(url) {
    _worker.warm();
  }

  /* A worker that did not load (offline, the file gone) or broke: whatever it held fails, and the sheet falls back to
     the crop; the next ask starts another (worker_web.dart). */
  final PageWorker _worker;
  final Duration wait;
  /* The working picture's size over the picture's, of the photo the worker keeps. */
  double _scale = 1;

  /* A worker that never answers (OpenCV.js still loading on a slow line, or stuck) does not hold the sheet. The worker
     carries on: what it is loading or keeps (OpenCV.js, the photo) serves the asks after. An answer with an error
     fails. */
  Future<Object?> _ask(JSObject message, [List<JSArrayBuffer> transfer = const []]) async {
    final a = await _worker.ask((id) => message..['id'] = id.toJS, transfer: transfer, wait: wait);
    if (a case {'error': final Object error}) throw StateError('finder: $error');
    return a;
  }

  @override
  Future<FinderAnswer> find(PickedPhoto photo, {double? cut}) async {
    final picture = photo.picture as web.ImageBitmap;
    final (canvas, context) = canvasOf(photo.width, photo.height);
    context.drawImage(picture, 0, 0);
    final pixels = context.getImageData(0, 0, photo.width, photo.height).data.toDart.buffer.toJS;
    release(canvas);
    final m = await _ask(JSObject()
      ..['pixels'] = pixels
      ..['width'] = photo.width.toJS
      ..['height'] = photo.height.toJS
      ..['groupCut'] = cut?.toJS, [pixels]) as Map<String, dynamic>;
    final scale = _scale = (m['scale'] as num).toDouble();
    return FinderAnswer(
      squares: [
        for (final q in m['squares'] as List) Float32List.fromList([for (final v in q as List) (v as num) / scale]),
      ],
      groups: (m['groups'] as List).cast<int>(),
      tiny: m['tiny'] as int,
      look: switch (m['look']) {
        final Map<String, dynamic> l => (
            boxSpread: (l['boxSpread'] as num).toDouble(),
            ringSpread: (l['ringSpread'] as num).toDouble(),
            ringVsBox: (l['ringVsBox'] as num).toDouble(),
            ringVsOutside: (l['ringVsOutside'] as num?)?.toDouble(),
          ),
        _ => null,
      },
    );
  }

  @override
  Future<Float32List?> snap(Offset at) async {
    final m = await _ask(JSObject()..['snap'] = [(at.dx * _scale).toJS, (at.dy * _scale).toJS].toJS) as Map<String, dynamic>;
    final q = m['square'] as List?;
    return q == null ? null : Float32List.fromList([for (final v in q) (v as num) / _scale]);
  }

  @override
  Future<List<Uint8List>> cut(List<Float32List> squares) async {
    final o = await _ask(JSObject()
      ..['cut'] = [
        for (final q in squares) [for (final v in q) (v * _scale).toJS].toJS,
      ].toJS) as JSObject;
    final rgba = (o['rgba']! as JSArray<JSArrayBuffer>).toDart;
    return [for (final b in rgba) b.toDart.asUint8List()];
  }

  @override
  void forget() {
    if (!_worker.running) return;
    _worker.post(JSObject()
      ..['id'] = 0.toJS
      ..['forget'] = true.toJS);
  }

  /* A find runs to its end in the worker once begun, so the worker goes, with the photo it keeps, and another starts
     (OpenCV.js loads again, from the browser's cache). */
  @override
  void stop() => _worker.restart();
}
