/* The finder on a phone: the same finder as the web's (lib/finder/finder_session.dart), on opencv_dart
   (lib/finder/opencv_native.dart), in an isolate of its own, as the web's runs in its Web Worker. One isolate for the
   app, started the first time the Add a piece sheet opens; it keeps the photo it was last asked about for the snaps
   and cuts after. It is handed the picture the sheet already read, as RGBA pixels, so its squares are in that
   picture's pixels. */
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image/image.dart' as img;
import '../finder/finder_session.dart';
import '../finder/opencv_native.dart';
import 'piece_finder.dart';
import 'prepare.dart' show PickedPhoto;

_IsolateFinder? _one;
PieceFinder? create() => _one ??= _IsolateFinder();

/* A finder in an isolate of its own, that gives up on an ask after `wait`. */
@visibleForTesting
PieceFinder isolateFinder({Duration wait = finderWait}) => _IsolateFinder(wait: wait);

class _IsolateFinder implements PieceFinder {
  _IsolateFinder({this.wait = finderWait}) {
    _warm();
  }

  /* The longest an ask waits for its answer. The isolate carries on past it: what it keeps serves the asks after. */
  final Duration wait;
  /* The isolate and its port, once started; null when it has gone (stopped, or it failed): the next ask starts
     another. */
  Future<(Isolate, SendPort, ReceivePort)>? _running;
  /* Done when the isolate last let go has exited, so a new one starts only then: one OpenCV session at a time. */
  Future<void> _exited = Future.value();
  final _waiting = <int, Completer<Object?>>{};
  int _next = 0;
  /* The working picture's size over the picture's, of the photo the isolate keeps. */
  double _scale = 1;

  /* Started now, so the first photo does not wait for it. A start that fails is tried again by the first ask. */
  void _warm() => unawaited(_started().then<void>((_) {}, onError: (Object _) {}));

  Future<(Isolate, SendPort, ReceivePort)> _started() {
    final running = _running;
    if (running != null) return running;
    final port = ReceivePort(), ready = Completer<SendPort>(), exited = Completer<void>();
    final before = _exited;
    _exited = exited.future;
    late final Future<(Isolate, SendPort, ReceivePort)> me;
    port.listen((m) {
      switch (m) {
        case SendPort p:
          ready.complete(p);
        case (int id, Object? answer):
          _waiting.remove(id)?.complete(answer);
        case (int id, String error, String stack):
          _waiting.remove(id)?.completeError(StateError('finder: $error'), StackTrace.fromString(stack));
        default: // it has exited (null), or failed outside an ask: whatever it held fails, and the next ask starts another
          if (m == null) {
            port.close();
            if (!exited.isCompleted) exited.complete();
          }
          if (identical(_running, me)) _gone();
          if (!ready.isCompleted) ready.completeError(StateError('finder: the isolate did not start'));
      }
    });
    me = () async {
      try {
        await before.timeout(wait, onTimeout: () {}); // one that never exits does not hold the finder up for good
        final isolate = await Isolate.spawn(_finderMain, port.sendPort,
            onExit: port.sendPort, onError: port.sendPort, debugName: 'finder');
        return (isolate, await ready.future, port);
      } catch (_) {
        port.close();
        if (!exited.isCompleted) exited.complete();
        if (identical(_running, me)) _running = null;
        rethrow;
      }
    }();
    return _running = me;
  }

  /* The isolate let go: every ask still waiting fails. It is killed, and goes with all it keeps once its OpenCV call
     in hand returns; its port closes when it has exited. */
  void _gone() {
    final running = _running;
    _running = null;
    unawaited(running?.then((r) => r.$1.kill(priority: Isolate.immediate), onError: (Object _) {}));
    for (final c in _waiting.values) {
      c.completeError(StateError('finder: the isolate has gone'));
    }
    _waiting.clear();
  }

  Future<Object?> _ask(String kind, Object? payload) async {
    final (_, send, _) = await _started();
    final id = ++_next, answer = Completer<Object?>();
    _waiting[id] = answer;
    send.send((id, kind, payload));
    try {
      return await answer.future.timeout(wait);
    } on TimeoutException {
      // Still busy with it, so the next ask would wait behind it: it goes, with what it kept, and another starts.
      stop();
      rethrow;
    } finally {
      _waiting.remove(id);
    }
  }

  @override
  Future<FinderAnswer> find(PickedPhoto photo, {double? cut}) async {
    var picture = photo.picture as img.Image;
    if (picture.format != img.Format.uint8 || picture.hasPalette) picture = picture.convert(format: img.Format.uint8);
    // The picture's own pixels, copied once to be handed over; made RGBA in the finder's isolate.
    _scale = 1;
    final Map<String, Object?> m;
    try {
      m = await _ask('find', (TransferableTypedData.fromList([picture.toUint8List()]), photo.width, photo.height,
          picture.numChannels, cut)) as Map<String, Object?>;
    } catch (_) {
      forget(); // nothing kept answers a snap or cut meant for another photo
      rethrow;
    }
    final scale = _scale = (m['scale']! as num).toDouble();
    final look = m['look'] as Map<String, Object?>?;
    return FinderAnswer(
      squares: [
        for (final q in m['squares']! as List) Float32List.fromList([for (final v in q as Float32List) v / scale]),
      ],
      groups: (m['groups']! as List).cast<int>(),
      tiny: m['tiny']! as int,
      look: look == null
          ? null
          : (
              boxSpread: (look['boxSpread']! as num).toDouble(),
              ringSpread: (look['ringSpread']! as num).toDouble(),
              ringVsBox: (look['ringVsBox']! as num).toDouble(),
              ringVsOutside: (look['ringVsOutside'] as num?)?.toDouble(),
            ),
    );
  }

  @override
  Future<Float32List?> snap(Offset at) async {
    final q = await _ask('snap', (at.dx * _scale, at.dy * _scale)) as Float32List?;
    return q == null ? null : Float32List.fromList([for (final v in q) v / _scale]);
  }

  @override
  Future<List<Uint8List>> cut(List<Float32List> squares) async {
    final out = await _ask('cut', [
      for (final q in squares) Float32List.fromList([for (final v in q) v * _scale]),
    ]) as List;
    return [for (final t in out) (t as TransferableTypedData).materialize().asUint8List()];
  }

  @override
  void forget() {
    final running = _running;
    if (running == null) return;
    unawaited(running.then((r) => r.$2.send((0, 'forget', null)), onError: (Object _) {}));
  }

  /* A find runs to its end once begun, so the isolate goes, with the photo it keeps, and another starts. */
  @override
  void stop() {
    _gone();
    _warm();
  }
}

/* The isolate: one FinderSession, answering each ask in turn. */
void _finderMain(SendPort out) {
  final asks = ReceivePort();
  out.send(asks.sendPort);
  final session = FinderSession(OpenCvNative());
  asks.listen((m) {
    final (int id, String kind, Object? payload) = m as (int, String, Object?);
    try {
      switch (kind) {
        case 'find':
          final (TransferableTypedData pixels, int width, int height, int channels, double? cut) =
              payload! as (TransferableTypedData, int, int, int, double?);
          var rgba = pixels.materialize().asUint8List();
          if (channels != 4) {
            rgba = img.Image.fromBytes(width: width, height: height, bytes: rgba.buffer, numChannels: channels)
                .getBytes(order: img.ChannelOrder.rgba);
          }
          out.send((id, session.find(rgba, width, height, groupCut: cut)));
        case 'snap':
          final (double x, double y) = payload! as (double, double);
          out.send((id, session.snap(x, y)));
        case 'cut':
          final cuts = session.cut((payload! as List).cast<Float32List>());
          out.send((id, [for (final (_, b) in cuts) TransferableTypedData.fromList([b])]));
        case 'forget':
          session.forget();
      }
    } catch (error, stack) {
      out.send((id, '$error', '$stack'));
    }
  });
}
