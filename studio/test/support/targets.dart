import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/pressable.dart';

/* The segmented controls in the Finish tab: 38 px segments, as the redesign handover draws them (each at least
   44 wide). Zoom's −, Fit (the percentage) and + are segments too. */
const phoneSizedItems = {
  'Panel': 38.0, 'Frame': 38.0, 'Tote': 38.0,
  'Zoom out': 38.0, 'Fit': 38.0, 'Zoom in': 38.0,
};

/* The board's squares ("Row 1, column 1 — …"), whose size is the board's fitted scale: the owner's ruling of 31 October
   2026 accepts them under 44 px, with their own floor of 24 px, WCAG 2.2 AA's target size minimum (2.5.8). Every
   other control keeps `least`. */
const boardSquareLeast = 24.0;
final _boardSquare = RegExp(r'^Row \d+, column \d+ — ');

/* Every button on the screen — each is a Pressable, and a Material button if one appears — at its own size; how
   many there were. Sizes come from the render boxes, not the semantics rects: those are clipped by a scrolling bar,
   so a button half scrolled out of a row would read short. `allowed` names buttons kept below `least`, labelled or
   not, each with the least it may be. */
int checkTargets(WidgetTester tester, double least, {Map<String, double> allowed = const {}}) {
  final buttons = find.byWidgetPredicate((w) => w is Pressable || w is ButtonStyleButton || w is IconButton).evaluate().toList();
  for (final e in buttons) {
    final w = e.widget;
    final words = find.descendant(of: find.byWidget(w), matching: find.byType(Text)).evaluate();
    final name = w is Pressable ? (w.label ?? w.tooltip ?? (words.isEmpty ? '' : (words.first.widget as Text).data ?? '')) : '$w';
    final s = tester.getSize(find.byWidget(w));
    final floor = math.min(allowed[name] ?? (_boardSquare.hasMatch(name) ? boardSquareLeast : least), least);
    expect(s.width >= floor - 0.5 && s.height >= floor - 0.5, isTrue, reason: '"$name" is $s');
  }
  return buttons.length;
}
