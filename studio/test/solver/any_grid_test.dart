import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import '../studio/solver_runner_test.dart' show fixtureBase;

/* Level 2: the solver on a board of any size. Level 1 (7 rows of 5) is pinned by the parity tests. */
void main() {
  String drawn(LayoutKey key, BoardSize g) {
    final z = layouts[key]!.zonesOn(g);
    return [for (var r = 0; r < g.rows; r++) [for (var c = 0; c < g.cols; c++) z[r * g.cols + c]].join()].join('/');
  }

  test('Level 1 is the A4 sheet, and its zones are the drawn map itself', () {
    expect(level1, (rows: a4.rows, cols: a4.cols));
    for (final key in layoutKeys) {
      expect(identical(layouts[key]!.zonesOn(level1), layouts[key]!.zones), isTrue, reason: key.name);
    }
  });

  test('Blocks stretches: each square takes the zone of the Level 1 square under its centre', () {
    expect(drawn(LayoutKey.blocks, (rows: 3, cols: 3)), '001/222/222');
    expect(drawn(LayoutKey.blocks, (rows: 14, cols: 10)),
        '0000001111/0000001111/0000001111/0000001111/0000001111/0000001111/'
        '2222222222/2222222222/2222222222/2222222222/2222222222/2222222222/2222222222/2222222222');
    expect(drawn(LayoutKey.contrast, (rows: 4, cols: 6)), '000000/000000/000000/000000');
  });

  test('Heart keeps its shape (owner, 31 Oct 2026): scaled the same both ways, centred, the rest plain ground', () {
    expect(drawn(LayoutKey.heart, (rows: 3, cols: 3)), '000/111/010');
    // 7 rows of 5 at 12/7 a square: 8.6 columns wide, centred, so the two columns at each side are ground.
    final wide = drawn(LayoutKey.heart, (rows: 12, cols: 12)).split('/');
    expect(wide.every((r) => r.startsWith('00') && r.endsWith('00')), isTrue, reason: wide.join('/'));
    expect(wide.join().contains('1'), isTrue);
    // A board twice as wide as tall: the heart is no wider than it is tall would make it.
    final flat = drawn(LayoutKey.heart, (rows: 5, cols: 12)).split('/');
    final used = [for (var c = 0; c < 12; c++) if (flat.any((r) => r[c] == '1')) c];
    expect(used.length, lessThanOrEqualTo(4), reason: flat.join('/'));
    expect(used.first + used.last, 11, reason: 'centred: ${flat.join('/')}');
  });

  test('a board under 2 squares a side is refused', () {
    final b = fixtureBase();
    final members = [for (var i = 0; i < b.stock.length; i++) i];
    expect(() => solveLayout(LayoutKey.gradient, b, members, Mount.none, 7, size: (rows: 1, cols: 5)), throwsArgumentError);
  });

  for (final size in [(rows: 3, cols: 3), (rows: 8, cols: 8), (rows: 12, cols: 20), (rows: 20, cols: 20)]) {
    test('${size.rows} × ${size.cols}: every pattern fills the board from enough cloth, within stock', () {
      final n = size.rows * size.cols, b0 = fixtureBase();
      // Enough cloth: every cloth has a piece for every square.
      final b = Base(b0.pool, b0.edge, [for (final _ in b0.stock) n]);
      final members = [for (var i = 0; i < b.stock.length; i++) i];
      for (final key in layoutKeys) {
        final s = solveLayout(key, b, members, Mount.none, 7, size: size);
        expect(s.fills, isTrue, reason: key.name);
        expect(s.grid, hasLength(n), reason: key.name);
        expect(s.rot, hasLength(n), reason: key.name);
        expect(s.grid!.every(members.contains), isTrue, reason: key.name);
        expect(withinStock(s.grid!, b.stock), isTrue, reason: key.name);
        final m = modelFor(key, ObjectiveInput(pool: b.pool, edge: b.edge, members: members, mount: Mount.none,
            stock: b.stock, size: size));
        expect((m.obj.rows, m.obj.cols), (size.rows, size.cols), reason: key.name);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  test('a board with too little cloth for it deals nothing, as on Level 1', () {
    final b0 = fixtureBase();
    final b = Base(b0.pool, b0.edge, [for (final _ in b0.stock) 1]);
    final members = [for (var i = 0; i < b.stock.length; i++) i];
    expect(solveLayout(LayoutKey.contrast, b, members, Mount.none, 7, size: (rows: 8, cols: 8)).grid, isNull);
  });
}
