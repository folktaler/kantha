import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/theme.dart' show PhonePalette;
import 'pump.dart' show sheet;

/* Every row divider in the open sheet runs 16 px in from each side of that sheet. The open sheet is the one on top,
   sheet.last, when one sheet is open over another. A row divider is a 1 px line in the border colour. A row with a ⋯
   draws its line in two pieces, the row's and the ⋯'s: they must meet, end to start, with no gap and no overlap. */
void expectDividersInset(WidgetTester tester) {
  final open = sheet.last, box = tester.getRect(open);
  final lines = find.descendant(of: open, matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == PhonePalette.border));
  final rects = [
    for (final e in lines.evaluate())
      if (e.renderObject case final RenderBox b when b.hasSize && b.size.height == 1) b.localToGlobal(Offset.zero) & b.size,
  ];
  expect(rects, isNotEmpty, reason: 'the open sheet has row dividers');
  final byRow = <double, List<Rect>>{};
  for (final r in rects) {
    (byRow[r.top] ??= []).add(r);
  }
  for (final row in byRow.values) {
    row.sort((a, b) => a.left.compareTo(b.left));
    for (var i = 1; i < row.length; i++) {
      expect(row[i].left, closeTo(row[i - 1].right, 0.5), reason: 'the pieces of one divider meet');
    }
    expect((row.first.left - box.left, box.right - row.last.right), (16.0, 16.0), reason: 'a divider 16 px in from each side');
  }
}
