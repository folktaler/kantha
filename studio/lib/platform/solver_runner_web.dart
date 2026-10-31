import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import '../solver/wire.dart';
import 'release.dart';
import 'solver_runner.dart';

SolverRunner create() => _WorkerRunner();

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external _Worker(JSString url);
  external void postMessage(JSAny? message);
  external set onmessage(JSFunction f);
  external set onerror(JSFunction f);
  external void terminate();
}

extension type _Message._(JSObject _) implements JSObject {
  external JSAny? get data;
}

class _WorkerRunner implements SizedSolverRunner {
  _WorkerRunner() {
    _worker.onmessage = ((_Message e) {
      _heard = true;
      final m = jsonDecode((e.data! as JSString).toDart) as Map<String, dynamic>;
      if (m['type'] == 'ready') return;
      _waiting.remove(m['id'])?.complete(LayoutSolve(m['fills'] as bool,
          (m['grid'] as List?)?.cast<int>(), (m['rot'] as List?)?.cast<int>()));
    }).toJS;
    // A worker that failed to load (solver_worker.js missing from the build) or crashed:
    // every solve still out answers "no arrangement", so the board stops solving and says so.
    // One that never said a word (it says "ready" as it starts) did not load: every later solve
    // fails at once too. One that has spoken keeps going; only the solves it held are lost.
    _worker.onerror = ((JSObject _) {
      if (!_heard) _dead = true;
      final out = _waiting.values.toList();
      _waiting.clear();
      for (final w in out) { w.complete(const LayoutSolve(false, null, null)); }
    }).toJS;
  }
  final _worker = _Worker(releaseFile('solver_worker.js', pageBase()).toString().toJS);
  final _waiting = <int, Completer<LayoutSolve>>{};
  var _next = 0;
  var _dead = false, _heard = false;

  @override
  void setPool(Base base) => _worker.postMessage('{"type":"pool","base":${baseToJson(base)}}'.toJS);

  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) =>
      _send(layout, members, mount, seed, null);

  @override
  Future<LayoutSolve> solveOn(BoardSize size, LayoutKey layout, List<int> members, Mount mount, int seed) =>
      _send(layout, members, mount, seed, size);

  Future<LayoutSolve> _send(LayoutKey layout, List<int> members, Mount mount, int seed, BoardSize? size) {
    if (_dead) return Future.value(const LayoutSolve(false, null, null));
    final id = ++_next, done = Completer<LayoutSolve>();
    _waiting[id] = done;
    _worker.postMessage(jsonEncode({'type': 'solve', 'id': id, 'layout': layout.name, 'members': members,
        'mount': mount.name, 'seed': seed, if (size != null) 'rows': size.rows, if (size != null) 'cols': size.cols}).toJS);
    return done.future;
  }

  @override
  void dispose() => _worker.terminate();
}
