import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import '../solver/wire.dart';
import 'release.dart';
import 'solver_runner.dart';
import 'worker_web.dart';

SolverRunner create() => _WorkerRunner();

/* The solver's worker (web/solver_worker.js). A worker that failed to load or broke answers "no arrangement" for each
   solve it held, so the board stops solving and says so; the next solve starts another (worker_web.dart). */
class _WorkerRunner implements SolverRunner {
  _WorkerRunner() {
    _worker = PageWorker(releaseFile('solver_worker.js', pageBase()).toString(), onStart: _sendPool, onNote: _step)..warm();
  }
  late final PageWorker _worker;
  final _steps = <int, void Function(int done, int of)>{};
  /* The pool as last sent, for each worker started after a stop or a failed load. */
  String? _pool;

  void _sendPool() {
    final pool = _pool;
    if (pool != null) _worker.post(pool.toJS);
  }

  bool _step(Map<String, dynamic> m) {
    if (m['type'] != 'step') return false;
    _steps[m['id']]?.call(m['done'] as int, m['of'] as int);
    return true;
  }

  @override
  void setPool(Base base) {
    _pool = '{"type":"pool","base":${baseToJson(base)}}';
    _worker.running ? _sendPool() : _worker.warm();
  }

  @override
  Future<LayoutSolve> solve(BoardSize? size, LayoutKey layout, List<int> members, Mount mount, int seed,
      {void Function(int done, int of)? onStep}) async {
    int? asked;
    try {
      final m = await _worker.ask((id) {
        asked = id;
        if (onStep != null) _steps[id] = onStep;
        return jsonEncode({'type': 'solve', 'id': id, 'layout': layout.name, 'members': members, 'mount': mount.name,
            'seed': seed, 'steps': onStep != null, if (size != null) 'rows': size.rows, if (size != null) 'cols': size.cols})
            .toJS;
      }) as Map<String, dynamic>;
      return LayoutSolve(m['fills'] as bool, (m['grid'] as List?)?.cast<int>(), (m['rot'] as List?)?.cast<int>());
    } on WorkerGone {
      return const LayoutSolve(false, null, null);
    } finally {
      _steps.remove(asked);
    }
  }

  /* A solve runs to its end in the worker once begun, so the worker goes, with every solve it held (each answers no
     arrangement), and another starts with the pool. */
  @override
  void stop() => _worker.restart();

  @override
  void dispose() => _worker.dispose();
}
