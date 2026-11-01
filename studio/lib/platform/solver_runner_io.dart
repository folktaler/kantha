import 'dart:async';
import 'dart:isolate';
import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import 'solver_runner.dart';

SolverRunner create() => _IsolateRunner();

/* Each solve in an isolate of its own. A stepped one is spawned, so it can say each step and be stopped (killed). */
class _IsolateRunner implements SteppedSolverRunner {
  Base? _base;
  final _running = <Isolate, Completer<LayoutSolve>>{};

  @override
  void setPool(Base base) => _base = base;
  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) {
    final base = _base!;
    return Isolate.run(() => solveLayout(layout, base, members, mount, seed));
  }
  @override
  Future<LayoutSolve> solveOn(BoardSize size, LayoutKey layout, List<int> members, Mount mount, int seed) {
    final base = _base!;
    return Isolate.run(() => solveLayout(layout, base, members, mount, seed, size: size));
  }

  @override
  Future<LayoutSolve> solveStepped(BoardSize? size, LayoutKey layout, List<int> members, Mount mount, int seed,
      void Function(int done, int of) onStep) async {
    final base = _base!, port = ReceivePort(), done = Completer<LayoutSolve>();
    final isolate = await Isolate.spawn(_solveIn, (port.sendPort, base, layout, members, mount, seed, size),
        onExit: port.sendPort, onError: port.sendPort);
    _running[isolate] = done;
    port.listen((m) {
      switch (m) {
        case (int d, int of):
          onStep(d, of);
          return;
        case LayoutSolve r:
          if (!done.isCompleted) done.complete(r);
        case [final Object? error, final Object? stack]:
          if (!done.isCompleted) done.completeError(error ?? 'solver isolate failed', StackTrace.fromString('$stack'));
        default: // the isolate has gone, answered or not
          if (!done.isCompleted) done.complete(const LayoutSolve(false, null, null));
      }
      _running.remove(isolate);
      port.close();
    });
    return done.future;
  }

  @override
  void stop() {
    for (final MapEntry(key: isolate, value: done) in _running.entries.toList()) {
      isolate.kill(priority: Isolate.immediate);
      if (!done.isCompleted) done.complete(const LayoutSolve(false, null, null));
    }
    _running.clear();
  }

  @override
  void dispose() => stop();
}

void _solveIn((SendPort, Base, LayoutKey, List<int>, Mount, int, BoardSize?) a) {
  final (out, base, layout, members, mount, seed, size) = a;
  out.send(solveLayout(layout, base, members, mount, seed, size: size, onStep: (d, of) => out.send((d, of))));
}
