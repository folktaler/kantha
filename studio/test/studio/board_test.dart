import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/studio/sheet_geometry.dart';
import '../support/pump.dart';

void main() {
  testWidgets('35 squares, each its own cloth, named by row and column, with no mark drawn on them', (tester) async {
    final c = await pumpStudio(tester);
    for (var i = 0; i < cells; i++) {
      final r = i ~/ a4.cols, col = i % a4.cols, f = c.grid![i];
      expect(find.bySemanticsLabel('Row ${r + 1}, column ${col + 1} — ${c.cloth[f].name}'), findsOneWidget);
    }
  });

  testWidgets('a square is laid 6 cm of cloth, 4 cm apart, the last row and column trimmed to 4', (tester) async {
    final c = await pumpStudio(tester);
    final ppc = c.ppc;
    final first = tester.getRect(find.byKey(const ValueKey('cell-0')));
    final second = tester.getRect(find.byKey(const ValueKey('cell-1')));
    final corner = tester.getRect(find.byKey(ValueKey('cell-${cells - 1}')));
    expect(first.width, closeTo(cutCm * ppc, 0.01));
    expect(second.left - first.left, closeTo(patchCm * ppc, 0.01));
    expect(corner.width, closeTo(patchCm * ppc, 0.01));
    expect(corner.height, closeTo(patchCm * ppc, 0.01));
    expect(footprintOf(0, 0).w, cutCm);
    expect(layIndex(1, 0), 1, reason: 'laid column by column');
  });

  testWidgets('the paper grid and the 4 cm label show only on Plain', (tester) async {
    final c = await pumpStudio(tester);
    expect(find.text('4 cm'), findsOneWidget);
    c.setMount(Mount.frame);
    await tester.pumpAndSettle();
    expect(find.text('4 cm'), findsNothing);
    expect(find.byKey(const ValueKey('frame')), findsOneWidget);
  });

  // On an iPhone the first square is narrower than its label, which was cut to "4 cr".
  for (final size in [phone, const Size(375, 667), const Size(320, 568)]) {
    testWidgets('the 4 cm label shows whole, centred on its line, at ${size.width.toInt()} × ${size.height.toInt()}',
        (tester) async {
      final c = await pumpStudio(tester, size: size);
      final label = tester.renderObject<RenderParagraph>(find.text('4 cm'));
      expect(label.size.width, label.getMaxIntrinsicWidth(double.infinity), reason: 'not cut short');
      final words = tester.getRect(find.text('4 cm')), first = tester.getRect(find.byKey(const ValueKey('cell-0')));
      // The line runs the first square's 4 cm, from its left edge.
      expect(words.center.dx, closeTo(first.left + patchCm * c.ppc / 2, 0.5));
      expect(words.left, greaterThanOrEqualTo(0));
      expect(words.right, lessThanOrEqualTo(size.width));
    });
  }
}
