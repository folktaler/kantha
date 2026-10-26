import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/pump.dart';

/* The button nodes at and under the one that holds `text`'s node: a screen reader says each one. */
List<SemanticsNode> buttonsAround(WidgetTester tester, Finder text) {
  var node = tester.getSemantics(text);
  // Up to the button the text belongs to (or the text's own node, when merged into it).
  while (!node.flagsCollection.isButton && node.parent != null) {
    node = node.parent!;
  }
  final out = <SemanticsNode>[];
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (n.flagsCollection.isButton || d.hasAction(SemanticsAction.tap)) out.add(n);
    n.visitChildren((c) { walk(c); return true; });
  }
  walk(node);
  return out;
}

void main() {
  testWidgets('an unlabelled button is one button, named by its own words: Save and a dock tab', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpStudio(tester);
    final tab = buttonsAround(tester, find.descendant(of: find.byKey(const ValueKey('tab-finish')), matching: find.text('Preview')));
    expect(tab, hasLength(1));
    expect(tab.single.getSemanticsData().label, 'Preview');
    final save = buttonsAround(tester, find.descendant(of: find.byKey(const ValueKey('phone-save')), matching: find.text('Save')));
    expect(save, hasLength(1));
    expect(save.single.getSemanticsData().label, 'Save');
    semantics.dispose();
  });
}
