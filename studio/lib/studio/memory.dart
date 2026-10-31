import 'package:flutter/foundation.dart';
import '../solver/geometry.dart';
import '../solver/layouts.dart';

const _keep = Object();

/* The arrangement she last saw on each template, per box, for this visit. Going
   back to a template shows it again, under the name and mount it had; pressing
   the template already showing deals a new one. An arrangement she saved carries
   the design it was saved as, so saving again saves over that design. */
@immutable
class Arrangement {
  const Arrangement({required this.grid, required this.rot, required this.seed, required this.name, required this.mount,
      this.savedId, this.savedGrid});
  final List<int> grid, rot;
  final int? seed;
  final String name;
  final Mount mount;
  final String? savedId, savedGrid;

  Arrangement copyWith({List<int>? grid, List<int>? rot, Object? seed = _keep, String? name, Mount? mount,
          Object? savedId = _keep, Object? savedGrid = _keep}) =>
      Arrangement(grid: grid ?? this.grid, rot: rot ?? this.rot, seed: seed == _keep ? this.seed : seed as int?,
          name: name ?? this.name, mount: mount ?? this.mount,
          savedId: savedId == _keep ? this.savedId : savedId as String?,
          savedGrid: savedGrid == _keep ? this.savedGrid : savedGrid as String?);

  @override
  bool operator ==(Object other) => other is Arrangement && listEquals(other.grid, grid) && listEquals(other.rot, rot) &&
      other.seed == seed && other.name == name && other.mount == mount && other.savedId == savedId && other.savedGrid == savedGrid;
  @override
  int get hashCode => Object.hash(Object.hashAll(grid), Object.hashAll(rot), seed, name, mount, savedId, savedGrid);
}

typedef Memory = Map<String, Arrangement>;

/* Per box and template, and per board size on Level 2: an arrangement is only ever shown again on its own size. */
String keyOf(int? box, LayoutKey layout, [BoardSize? size]) =>
    '${box ?? 'none'}:${layout.name}${size == null || size == level1 ? '' : ':${size.rows}x${size.cols}'}';
Memory remember(Memory m, String key, Arrangement a) => {...m, key: a};
Arrangement? recall(Memory m, String key) => m[key];
/* A design she deleted: every arrangement saved as it still shows, but is no longer saved. */
Memory forget(Memory m, String designId) =>
    {for (final e in m.entries) e.key: e.value.savedId == designId ? e.value.copyWith(savedId: null, savedGrid: null) : e.value};
