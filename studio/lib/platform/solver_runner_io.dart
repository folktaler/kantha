import 'dart:async';
import 'dart:isolate';
import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import 'solver_runner.dart';

SolverRunner create() => _IsolateRunner();

/* Each solve in an isolate of its own, spawned, so it can say each step and be stopped (killed). */
class _IsolateRunner implements SolverRunner {
  Base? _base;
  /* Each solve out, from its ask; its isolate once spawned. */
  final _out = <Completer<LayoutSolve>, Isolate?>{};

  @override
  void setPool(Base base) => _base = base;

  @override
  Future<LayoutSolve> solve(BoardSize? size, LayoutKey layout, List<int> members, Mount mount, int seed,
      {void Function(int done, int of)? onStep}) async {
    final base = _base!, port = ReceivePort(), done = Completer<LayoutSolve>();
    _out[done] = null;
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(_solveIn, (port.sendPort, base, layout, members, mount, seed, size, onStep != null),
          onExit: port.sendPort, onError: port.sendPort);
    } catch (_) {
      _out.remove(done);
      port.close();
      rethrow;
    }
    // Stopped while it was spawned: it goes as it arrives.
    if (!_out.containsKey(done)) {
      isolate.kill(priority: Isolate.immediate);
      port.close();
      return done.future;
    }
    _out[done] = isolate;
    port.listen((m) {
      switch (m) {
        case (int d, int of):
          onStep?.call(d, of);
          return;
        case LayoutSolve r:
          if (!done.isCompleted) done.complete(r);
        case [final Object? error, final Object? stack]:
          if (!done.isCompleted) done.completeError(error ?? 'solver isolate failed', StackTrace.fromString('$stack'));
        default: // the isolate has gone, answered or not
          if (!done.isCompleted) done.complete(const LayoutSolve(false, null, null));
      }
      _out.remove(done);
      port.close();
    });
    return done.future;
  }

  @override
  void stop() {
    for (final MapEntry(key: done, value: isolate) in _out.entries.toList()) {
      isolate?.kill(priority: Isolate.immediate);
      if (!done.isCompleted) done.complete(const LayoutSolve(false, null, null));
    }
    _out.clear();
  }

  @override
  void dispose() => stop();
}

void _solveIn((SendPort, Base, LayoutKey, List<int>, Mount, int, BoardSize?, bool) a) {
  final (out, base, layout, members, mount, seed, size, steps) = a;
  out.send(solveLayout(layout, base, members, mount, seed, size: size,
      onStep: steps ? (d, of) => out.send((d, of)) : null));
}
