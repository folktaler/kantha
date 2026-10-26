@Tags(['chrome-only'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'recorded.dart';

void main() {
  test('the sheet: 5 × 7 squares of 4 cm on A4, its margins to the last bit', () {
    expect((a4.cols, a4.rows, a4.bw, a4.bh, a4.mx, a4.my), (5, 7, 20.0, 28.0, 0.5, 0.8499999999999996));
    expect(cells, 35);
  });

  test('one tote, 16 × 17½ in', () {
    expect((tote.w, tote.h, tote.top, tote.side), (40.6, 44.5, 6.9, 10.3));
  });

  test("each mount's ground lightness is the number in the snapshot", () {
    final c = recorded['canvasL'] as Map<String, dynamic>;
    for (final m in Mount.values) {
      expect(canvasL(m), d(c[m.name]), reason: m.name);
    }
  });
}
