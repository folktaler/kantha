@Tags(['chrome-only'])
library;

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/fabrics.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/icons.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/score.dart';
import 'package:kantha_studio/solver/solve.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/solver/start.dart';
import 'compile_test.dart' show fixturePool, fixtureEdge;
import '../support/spread.dart';
import 'recorded.dart';

int channel(String hex, int i) => int.parse(hex.substring(1 + 2 * i, 3 + 2 * i), radix: 16);

void main() {
  test('a cloth reads as the colour in the snapshot, within one step per channel', () {
    for (final h in recorded['hex'] as List) {
      final got = hexOf(lab(h['lab'])), want = h['hex'] as String;
      for (var i = 0; i < 3; i++) {
        expect((channel(got, i) - channel(want, i)).abs(), lessThanOrEqualTo(1), reason: '$got vs $want');
      }
    }
  });

  test("the start page's layouts: the same templates, the same cloth in the same places, turned the same", () {
    final labs = poolLab();
    final hexByIndex = [for (final h in recorded['hex'] as List) h['hex'] as String];
    final stock = spread(ints(poolFixture['stock']));
    final fabrics = [
      for (var i = 0; i < labs.length; i++)
        Fabric(id: (poolFixture['ids'] as List)[i] as String, name: '', lab: labs[i],
            busy: (poolFixture['busy'] as List)[i] as bool,
            edge: (poolFixture['edge'] as List)[i] == null ? null : d((poolFixture['edge'] as List)[i]),
            grain: null, stock: stock[i]),
    ];
    final got = layoutsFrom(fabrics);
    final want = recorded['start'] as List;
    expect([for (final l in got) l.key.name], [for (final l in want) l['key']]);
    final p = poolOf(fabrics);
    final members = [for (var i = 0; i < fabrics.length; i++) i];
    for (var k = 0; k < want.length; k++) {
      final cells = want[k]['cells'] as List;
      final gotHex = [for (final c in got[k].cells) hexByIndex[c.fabric]];
      final wantHex = [for (final c in cells) c['hex'] as String];
      if (!listEquals(gotHex, wantHex)) {
        // This platform's maths dealt a different arrangement (controller ruling, 6 Oct): it passes only
        // if it is whole, from this box, within stock, and a local minimum of the solver's own moves
        // (the start fixture records no total to re-score against).
        final m = modelFor(got[k].key, ObjectiveInput(pool: p.pool, edge: p.edge, members: members,
            mount: Mount.none, stock: p.stock));
        final prep = prepare(m.pool, m.obj.distance);
        final gotGrid = [for (final c in got[k].cells) c.fabric];
        final wantGrid = [for (final h in wantHex) hexByIndex.indexOf(h)];
        expect(gotGrid, hasLength(a4.rows * a4.cols));
        expect(withinStock(gotGrid, p.stock), isTrue, reason: '${got[k].key.name}: within stock');
        final gotTotal = score(gotGrid, m.obj, prep).total, wantTotal = score(wantGrid, m.obj, prep).total;
        // ignore: avoid_print
        print('${kIsWeb ? 'WEB' : 'VM'}: start ${got[k].key.name} differs; score $gotTotal against $wantTotal');
        expect(isLocalMinimum(gotGrid, m.obj, prep, p.stock, members), isTrue,
            reason: '${got[k].key.name}: no single move of the solver improves it');
        continue;
      }
      for (var i = 0; i < cells.length; i++) {
        expect(got[k].cells[i].rot, cells[i]['rot'], reason: '${got[k].key.name} cell $i turn');
      }
    }
  });

  test('a cloth index past the stock list is not counted, as an Int32Array ignores the write', () {
    expect(withinStock([0, 5], [1]), isTrue);
    expect(withinStock([0, 0, 5], [1]), isFalse);
  });

  test('a template icon shades its squares as recorded below', () {
    // Math.round(28 + clamp(value(key, r, c)) * 200) for every square, row by row: the original TypeScript
    // value(), run under node.
    const want = {
      'contrast': [228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228, 38, 228],
      'gradient': [228, 203, 178, 153, 128, 211, 186, 161, 136, 111, 195, 170, 145, 120, 95, 178, 153, 128, 103, 78, 161, 136, 111, 86, 61, 145, 120, 95, 70, 45, 128, 103, 78, 53, 28],
      'medallion': [228, 203, 194, 203, 228, 185, 152, 139, 152, 185, 152, 106, 83, 106, 152, 139, 83, 28, 83, 139, 152, 106, 83, 106, 152, 185, 152, 139, 152, 185, 228, 203, 194, 203, 228],
      'wave': [228, 228, 128, 128, 28, 228, 128, 128, 28, 28, 128, 128, 28, 28, 228, 128, 28, 28, 228, 228, 28, 28, 228, 228, 228, 28, 228, 228, 228, 228, 228, 228, 228, 228, 128],
      'framed': [28, 28, 28, 28, 28, 28, 128, 128, 128, 28, 28, 128, 228, 128, 28, 28, 128, 228, 128, 28, 28, 128, 228, 128, 28, 28, 128, 128, 128, 28, 28, 28, 28, 28, 28],
      'cross': [28, 153, 228, 153, 28, 111, 70, 195, 70, 111, 195, 70, 111, 70, 195, 228, 153, 28, 153, 228, 195, 70, 111, 70, 195, 111, 70, 195, 70, 111, 28, 153, 228, 153, 28],
      'spectrum': [78, 103, 128, 153, 178, 78, 103, 128, 153, 178, 78, 103, 128, 153, 178, 78, 103, 128, 153, 178, 78, 103, 128, 153, 178, 78, 103, 128, 153, 178, 78, 103, 128, 153, 178],
      'boro': [28, 178, 78, 228, 128, 128, 28, 178, 78, 228, 228, 128, 28, 178, 78, 78, 228, 128, 28, 178, 178, 78, 228, 128, 28, 28, 178, 78, 228, 128, 128, 28, 178, 78, 228],
      'blocks': [68, 68, 68, 138, 138, 68, 68, 68, 138, 138, 68, 68, 68, 138, 138, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198, 198],
      'medallionPrint': [228, 203, 194, 203, 228, 185, 152, 139, 152, 185, 152, 106, 83, 106, 152, 139, 83, 28, 83, 139, 152, 106, 83, 106, 152, 185, 152, 139, 152, 185, 228, 203, 194, 203, 228],
      'heart': [228, 228, 228, 228, 228, 228, 88, 228, 88, 228, 88, 88, 88, 88, 88, 88, 88, 88, 88, 88, 228, 88, 88, 88, 228, 228, 228, 88, 228, 228, 228, 228, 228, 228, 228],
    };
    expect(want.keys, [for (final k in layoutKeys) k.name]);
    for (final key in layoutKeys) {
      expect(layoutIconLevels(key), want[key.name], reason: key.name);
    }
  });

  /* What the TypeScript gave on these inputs (node, seed 7, mount none):
       members [0, 1, 2]    (27 pieces): heart refuses 'fewPieces', anchors {1: 1}; every other template fills; no grid for any
       members [3, 4, 5, 6] (25 pieces): heart refuses 'noDarkEnough', anchors {1: 5}; no grid for any */
  group('a box too small for the panel', () {
    final pool = fixturePool(), edge = fixtureEdge(), stock = ints(poolFixture['stock']);
    final base = Base(pool, edge, stock);
    for (final (members, why, anchor) in [([0, 1, 2], Unfillable.fewPieces, 1), ([3, 4, 5, 6], Unfillable.noDarkEnough, 5)]) {
      test('members $members: the heart gives its reason, and no template deals a grid', () {
        final heart = modelFor(LayoutKey.heart, ObjectiveInput(pool: pool, edge: edge, members: members,
            mount: Mount.none, stock: stock));
        expect(heart.fills, isFalse);
        expect(heart.why, why);
        expect(heart.anchors, {1: anchor});
        for (final key in layoutKeys) {
          final s = solveLayout(key, base, members, Mount.none, 7);
          expect(s.fills, key != LayoutKey.heart, reason: key.name);
          expect(s.grid, isNull, reason: key.name);
          expect(s.rot, isNull, reason: key.name);
        }
      });
    }

    test('the start page leaves out every template it cannot fill', () {
      final labs = poolLab();
      final fabrics = [
        for (final i in [0, 1, 2])
          Fabric(id: 'swatch_$i', name: '', lab: labs[i], busy: false, edge: 0, grain: null, stock: stock[i]),
      ];
      expect(layoutsFrom(fabrics), isEmpty);
    });
  });
}
