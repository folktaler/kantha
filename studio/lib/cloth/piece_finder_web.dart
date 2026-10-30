/* The finder's worker (web/finder_worker.js), one for the page, started the first time the Add a piece sheet opens. It
   is handed the picture the sheet already read, as RGBA pixels, so its squares are in that picture's pixels. */
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:web/web.dart' as web;
import '../platform/canvas_web.dart';
import '../platform/release.dart' show pageBase, releaseFile;
import 'piece_finder.dart';
import 'prepare.dart' show PickedPhoto;

_WorkerFinder? _one;
PieceFinder? create() => _one ??= _WorkerFinder();

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

class _WorkerFinder implements PieceFinder {
  _WorkerFinder() {
    _worker.onmessage = ((_Message e) {
      final data = e.data;
      if (data.isA<JSString>()) {
        final m = jsonDecode((data! as JSString).toDart) as Map<String, dynamic>;
        if (m['type'] == 'ready') return;
        final w = _waiting.remove(m['id']);
        if (m['error'] != null) {
          w?.completeError(StateError('finder: ${m['error']}'));
        } else {
          w?.complete(m);
        }
      } else {
        final o = data! as JSObject;
        _waiting.remove((o['id']! as JSNumber).toDartInt)?.complete(o);
      }
    }).toJS;
    // A worker that did not load (offline, the file gone) or broke: whatever it held fails, and so does every later
    // ask; the sheet falls back to the crop.
    _worker.onerror = ((JSObject _) {
      _dead = true;
      final out = _waiting.values.toList();
      _waiting.clear();
      for (final w in out) {
        w.completeError(StateError('finder worker failed'));
      }
    }).toJS;
  }

  final _worker = _Worker(releaseFile('finder_worker.js', pageBase()).toString().toJS);
  final _waiting = <int, Completer<Object?>>{};
  var _next = 0;
  var _dead = false;
  /* The working picture's size over the picture's, of the photo the worker keeps. */
  double _scale = 1;

  Future<Object?> _ask(JSObject message, [List<JSArrayBuffer> transfer = const []]) {
    if (_dead) return Future.error(StateError('finder worker failed'));
    final id = ++_next, done = Completer<Object?>();
    _waiting[id] = done;
    message['id'] = id.toJS;
    _worker.postMessage(message, transfer.toJS);
    return done.future;
  }

  @override
  Future<FinderAnswer> find(PickedPhoto photo) async {
    final picture = photo.picture as web.ImageBitmap;
    final (canvas, context) = canvasOf(photo.width, photo.height);
    context.drawImage(picture, 0, 0);
    final pixels = context.getImageData(0, 0, photo.width, photo.height).data.toDart.buffer.toJS;
    release(canvas);
    final m = await _ask(JSObject()
      ..['pixels'] = pixels
      ..['width'] = photo.width.toJS
      ..['height'] = photo.height.toJS, [pixels]) as Map<String, dynamic>;
    final scale = _scale = (m['scale'] as num).toDouble();
    return FinderAnswer(
      squares: [
        for (final q in m['squares'] as List) Float32List.fromList([for (final v in q as List) (v as num) / scale]),
      ],
      groups: (m['groups'] as List).cast<int>(),
      tiny: m['tiny'] as int,
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
    if (_dead) return;
    _worker.postMessage(JSObject()
      ..['id'] = 0.toJS
      ..['forget'] = true.toJS);
  }
}
