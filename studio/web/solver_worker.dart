import 'dart:convert';
import 'dart:js_interop';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/solver/wire.dart';

/* The solver's Web Worker: the pool once, then one solve per message. Compiled to
   web/solver_worker.js by tool/prepare_web.sh. */
@JS('self')
external _Scope get _self;

extension type _Scope._(JSObject _) implements JSObject {
  external set onmessage(JSFunction f);
  external void postMessage(JSAny? message);
}

extension type _Message._(JSObject _) implements JSObject {
  external JSAny? get data;
}

void main() {
  Base? base;
  _self.onmessage = ((_Message e) {
    final m = jsonDecode((e.data! as JSString).toDart) as Map<String, dynamic>;
    if (m['type'] == 'pool') { base = baseFromJson(m['base'] as Map<String, dynamic>); return; }
    final b = base;
    if (b == null) return;
    final s = solveLayout(LayoutKey.values.byName(m['layout'] as String), b, (m['members'] as List).cast<int>(),
        Mount.values.byName(m['mount'] as String), m['seed'] as int);
    _self.postMessage(jsonEncode({'id': m['id'], 'fills': s.fills, 'grid': s.grid, 'rot': s.rot}).toJS);
  }).toJS;
  // Loaded and listening: the studio knows from this that a later error is a solve's, not a missing worker.
  _self.postMessage('{"type":"ready"}'.toJS);
}
