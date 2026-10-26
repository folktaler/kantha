/* The pool across to the solver's Web Worker, as JSON. */
import 'dart:convert';
import 'score.dart';
import 'solve_layout.dart';

String baseToJson(Base b) => jsonEncode({
      'lab': [for (final l in b.pool.lab) [l.l, l.a, l.b]],
      'lightness': b.pool.lightness, 'busy': b.pool.busy, 'visualWeight': b.pool.visualWeight,
      'grain': b.pool.grain, 'coherence': b.pool.coherence, 'edge': b.edge, 'stock': b.stock,
    });

Base baseFromJson(Map<String, dynamic> m) {
  double d(Object? v) => (v as num).toDouble();
  List<double?> maybe(Object? v) => v == null ? const [] : [for (final x in v as List) x == null ? null : d(x)];
  return Base(
    Pool(
      lab: [for (final l in m['lab'] as List) (l: d(l[0]), a: d(l[1]), b: d(l[2]))],
      lightness: [for (final x in m['lightness'] as List) d(x)],
      busy: [for (final x in m['busy'] as List) x as bool],
      visualWeight: m['visualWeight'] == null ? null : [for (final x in m['visualWeight'] as List) d(x)],
      grain: m['grain'] == null ? null : maybe(m['grain']), coherence: m['coherence'] == null ? null : maybe(m['coherence']),
    ),
    maybe(m['edge']),
    [for (final x in m['stock'] as List) x as int],
  );
}
