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

/* The worker failed (did not load, or broke) while it held the ask. */
class WorkerFailed implements Exception {
  const WorkerFailed(this.url);
  final String url;
  @override
  String toString() => 'WorkerFailed: $url';
}

/* The ask was let go by restart. */
class WorkerStopped implements Exception {
  const WorkerStopped();
}

class PageWorker {
  /* `onStart`, after each worker starts, before anything is asked of it (the solver's pool). `onNote`, for a JSON
     message that answers no ask (the solver's steps): true when it took it. */
  PageWorker(this.url, {this.onStart, this.onNote});
  final String url;
  final void Function()? onStart;
  final bool Function(Map<String, dynamic> m)? onNote;

  _Worker? _worker;
  var _heard = false;
  final _waiting = <int, Completer<Object?>>{};
  var _next = 0;

  bool get running => _worker != null;

  /* Starts one now, if none runs, so it has loaded by the time it is asked. */
  void warm() {
    if (_worker == null) _start();
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
        if (m['type'] == 'ready') return;
        if (onNote?.call(m) ?? false) return;
        _waiting.remove(m['id'])?.complete(m);
      } else {
        final o = data! as JSObject;
        _waiting.remove((o['id']! as JSNumber).toDartInt)?.complete(o);
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

  void _failAll(Object e) {
    final out = _waiting.values.toList();
    _waiting.clear();
    for (final w in out) {
      w.completeError(e);
    }
  }

  /* A message that has no answer; to a worker that runs, or to one started for it. */
  void post(JSAny message, [List<JSAny> transfer = const []]) {
    warm();
    _worker!.postMessage(message, transfer.toJS);
  }

  /* `message(id)` sent, and its answer: a Map for JSON, else the object. Fails with WorkerFailed, WorkerStopped, or,
     past `wait`, TimeoutException (the worker carries on). */
  Future<Object?> ask(JSAny Function(int id) message, {List<JSAny> transfer = const [], Duration? wait}) {
    final id = ++_next, done = Completer<Object?>();
    _waiting[id] = done;
    post(message(id), transfer);
    if (wait == null) return done.future;
    return done.future.timeout(wait, onTimeout: () {
      _waiting.remove(id);
      throw TimeoutException('the worker did not answer', wait);
    });
  }

  /* Ends the worker and all it held, and starts another. */
  void restart() {
    _worker?.terminate();
    _worker = null;
    _failAll(const WorkerStopped());
    _start();
  }

  /* Ends the worker; what it held is dropped, unanswered. */
  void dispose() {
    _worker?.terminate();
    _worker = null;
    _waiting.clear();
  }
}
