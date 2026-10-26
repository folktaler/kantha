import 'dart:convert';
import 'package:kantha_studio/solver/hue.dart';
import '../fixtures/fixtures.g.dart' as g;

/* The snapshots, a fixed answer sheet: test/fixtures/solver/recorded.json, pool-2026-09-11.json and js-math.json
   were recorded once from the TypeScript solver under Node 22 (commit 6d3fb2b), before the Dart port replaced it. */

final Map<String, dynamic> recorded = jsonDecode(g.solverRecorded) as Map<String, dynamic>;
final Map<String, dynamic> poolFixture = jsonDecode(g.pool) as Map<String, dynamic>;
final Map<String, dynamic> jsMath = jsonDecode(g.jsMath) as Map<String, dynamic>;

double d(Object? v) => (v as num).toDouble();
List<double> ds(Object? v) => [for (final x in v as List) d(x)];
List<int> ints(Object? v) => [for (final x in v as List) (x as num).toInt()];
Lab lab(Object? v) { final l = v as List; return (l: d(l[0]), a: d(l[1]), b: d(l[2])); }
List<Lab> poolLab() => [for (final x in poolFixture['lab'] as List) lab(x)];
