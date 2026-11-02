/* A Web Worker the page asks things of, by number: the solver's, the finder's and the measure's (web/solver_worker.js,
   finder_worker.js, measure_worker.js). Each says "ready" as it starts. An answer is the message with the ask's number: a JSON string, or an object with an
   `id` (the finder's pixels).
   - One that never said a word before an error did not load (offline, the file gone): what it held fails, and the
     next ask starts another, so a stop's new worker that failed to load does not end the work for good.
   - One that has spoken and then errs keeps going; only what it held fails.
   - `restart` ends it, with all it held (each fails with WorkerStopped), and starts another: the only way to stop
     work a worker has begun. */
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external _Worker(JSString url);
  external void postMessage(JSAny? message, [JSArray<JSAny>? transfer]);
  external set onmessage(JSFunction f);
  external set onerror(JSFunction f);
  external void terminate();
}

extension type _Message._(JSObject _) implements JSObject {
  external JSAny? get data;
}

/* The worker cannot answer the ask: it failed, or it was let go. */
sealed class WorkerGone implements Exception {
  const WorkerGone();
}

/* The worker failed (did not load, or broke) while it held the ask, or the ask could not be sent to it. */
final class WorkerFailed extends WorkerGone {
  const WorkerFailed(this.url, [this.why]);
  final String url;
  final Object? why;
  @override
  String toString() => 'WorkerFailed: $url${why == null ? '' : ': $why'}';
}

/* The ask was let go: by restart, or by dispose. */
final class WorkerStopped extends WorkerGone {
  const WorkerStopped();
}

/* When an ask's wait starts.
   - ready: once the worker has said "ready" (the finder's, once OpenCV.js has loaded), so a worker started again does
     not spend the find's wait loading. Until then the load has a wait of its own, so one that never loads still ends.
   - begin: once the worker says it has begun that ask ({"type":"begin","id"}: the measure's), or the ask before it has
     ended, so time in the queue is not counted, and a worker stuck on one lets the next go after a wait of its own,
     one at a time, never all at once. */
enum WaitFrom { ready, begin }

class _Ask {
  _Ask(this.wait, this.from);
  final done = Completer<Object?>();
  final Duration? wait;
  final WaitFrom from;
  Timer? timer;
}

class PageWorker {
  /* `onStart`, after each worker starts, before anything is asked of it (the solver's pool). `onNote`, for a JSON
     message that answers no ask (the solver's steps): true when it took it. */
  PageWorker(this.url, {this.onStart, this.onNote});
  final String url;
  final void Function()? onStart;
  final bool Function(Map<String, dynamic> m)? onNote;

  _Worker? _worker;
  var _heard = false, _disposed = false;
  final _waiting = <int, _Ask>{};
  var _next = 0;

  bool get running => _worker != null;

  /* Starts one now, if none runs, so it has loaded by the time it is asked. */
  void warm() {
    if (_worker == null && !_disposed) _start();
  }

  void _start() {
    final w = _worker = _Worker(url.toJS);
    _heard = false;
    w.onmessage = ((_Message e) {
      if (!identical(w, _worker)) return;
      _heard = true;
      final data = e.data;
      if (data.isA<JSString>()) {
        final m = jsonDecode((data! as JSString).toDart) as Map<String, dynamic>;
        switch (m['type']) {
          case 'ready':
            for (final a in _waiting.values) {
              if (a.from == WaitFrom.ready) _time(a, again: true);
            }
            return;
          case 'begin':
            final a = _waiting[m['id']];
            if (a != null) _time(a, again: true); // begun now: its wait is counted from here
            return;
        }
        if (onNote?.call(m) ?? false) return;
        _answer(m['id'], m);
      } else {
        final o = data! as JSObject;
        _answer((o['id']! as JSNumber).toDartInt, o);
      }
    }).toJS;
    w.onerror = ((JSObject _) {
      if (!identical(w, _worker)) return;
      if (!_heard) {
        w.terminate();
        _worker = null;
      }
      _failAll(WorkerFailed(url));
    }).toJS;
    onStart?.call();
  }

  void _answer(Object? id, Object answer) {
    final a = _waiting.remove(id);
    if (a == null) return;
    a.timer?.cancel();
    a.done.complete(answer);
    if (a.from == WaitFrom.begin) _nextBegins();
  }

  /* The ask's wait starts now (`again`: afresh); past it, it fails with TimeoutException, alone: the worker carries
     on. */
  void _time(_Ask a, {bool again = false}) {
    final wait = a.wait;
    if (wait == null || (a.timer != null && !again)) return;
    a.timer?.cancel();
    a.timer = Timer(wait, () {
      _waiting.removeWhere((_, x) => identical(x, a));
      a.done.completeError(TimeoutException('the worker did not answer', wait));
      if (a.from == WaitFrom.begin) _nextBegins();
    });
  }

  /* The ask before has ended: the first waiting in turn begins now, as far as its wait goes. */
  void _nextBegins() {
    for (final a in _waiting.values) {
      if (a.from == WaitFrom.begin) return _time(a);
    }
  }

  void _failAll(WorkerGone e) {
    final out = _waiting.values.toList();
    _waiting.clear();
    for (final a in out) {
      a.timer?.cancel();
      a.done.completeError(e);
    }
  }

  /* A message that has no answer; to a worker that runs, or to one started for it. Nothing once disposed. */
  void post(JSAny message, [List<JSAny> transfer = const []]) {
    if (_disposed) return;
    warm();
    _worker!.postMessage(message, transfer.toJS);
  }

  /* `message(id)` sent, and its answer: a Map for JSON, else the object. Fails with WorkerGone (WorkerFailed when it
     could not be sent either: a buffer already handed over is not sent twice), or, past `wait` counted from `from`,
     TimeoutException. */
  Future<Object?> ask(JSAny Function(int id) message,
      {List<JSAny> transfer = const [], Duration? wait, WaitFrom from = WaitFrom.ready}) {
    if (_disposed) return Future.error(const WorkerStopped());
    final id = ++_next, a = _Ask(wait, from);
    _waiting[id] = a;
    try {
      post(message(id), transfer);
    } catch (e) {
      _waiting.remove(id);
      return Future.error(WorkerFailed(url, e));
    }
    switch (from) {
      case WaitFrom.ready:
        _time(a); // the load's wait, until "ready"; the ask's own, after
      case WaitFrom.begin:
        if (!_waiting.values.any((x) => x.from == WaitFrom.begin && !identical(x, a))) _time(a); // first in turn
    }
    return a.done.future;
  }

  /* Ends the worker and all it held (each ask fails with WorkerStopped), and starts another. */
  void restart() {
    if (_disposed) return;
    _worker?.terminate();
    _worker = null;
    _failAll(const WorkerStopped());
    _start();
  }

  /* Ends the worker; what it held is dropped, unanswered, and nothing is asked of it again. */
  void dispose() {
    _disposed = true;
    _worker?.terminate();
    _worker = null;
    for (final a in _waiting.values) {
      a.timer?.cancel();
    }
    _waiting.clear();
  }
}
