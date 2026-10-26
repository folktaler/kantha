import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart' show Mount;
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';
import 'package:kantha_studio/studio/pressable.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../support/fonts.dart';
import '../../support/pump.dart';
import '../../support/targets.dart';

/* The Preview tab (renamed from Finish by the owner, 19 Oct; redesign handover, "Dock panel — Finish tab"; decision 4):
   Mount and Zoom. Stitches are on the Design tab (owner, 20 Oct). */
final panel = key('dock-panel'), finish = key('dock-finish');

/* The button holding these words in the Finish tab. */
Finder segment(String words) =>
    find.ancestor(of: find.descendant(of: finish, matching: find.text(words)), matching: find.byType(Pressable)).first;
Pressable pressable(WidgetTester tester, Finder f) => tester.widget<Pressable>(f);
final zoomOut = key('zoom-out'), zoomIn = key('zoom-in'), zoomFit = key('zoom-fit');

/* How far the panel can scroll down. */
double reach(WidgetTester tester) =>
    tester.state<ScrollableState>(find.descendant(of: finish, matching: find.byType(Scrollable)).first).position.maxScrollExtent;

Future<StudioController> openFinish(WidgetTester tester) async {
  final c = await pumpStudio(tester, size: phone);
  await tester.tap(key('tab-finish'));
  await tester.pumpAndSettle();
  return c;
}

Future<void> press(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a phone the Preview tab holds Mount and Zoom only: 96 px caps labels, 38 px segments in a strong edge',
      (tester) async {
    // The bundled faces, so a label cut short here is cut short in the browser.
    await tester.runAsync(loadFonts);
    final c = await openFinish(tester);
    expect(find.descendant(of: panel, matching: finish), findsOneWidget);
    final box = tester.getRect(panel);
    // The labels: the words, upper-cased as a style; a screen reader hears the words.
    final labels = <Rect>[];
    for (final (caps, words) in [('MOUNT', 'Mount'), ('ZOOM', 'Zoom')]) {
      final t = tester.widget<Text>(find.descendant(of: finish, matching: find.text(caps)));
      final s = t.style!;
      expect((s.fontSize, s.fontWeight, s.color, s.letterSpacing), (13.83, FontWeight.w500, PhonePalette.text2, 1.38), reason: caps);
      expect(find.descendant(of: finish, matching: find.bySemanticsLabel(words)), findsOneWidget, reason: words);
      final r = tester.getRect(find.descendant(of: finish, matching: find.text(caps)));
      expect(r.left, closeTo(16, 0.5), reason: caps);
      expect(tester.renderObject<RenderParagraph>(find.descendant(of: finish, matching: find.text(caps))).didExceedMaxLines,
          isFalse, reason: '$caps is not cut short');
      labels.add(r);
    }
    expect(labels[0].top < labels[1].top, isTrue, reason: 'Mount, then Zoom');
    expect(find.descendant(of: finish, matching: find.text('STITCHES')), findsNothing, reason: 'Stitches is on the Design tab');

    // Each control starts 96 + 8 after the label's edge and runs to 16 from the right.
    final rows = [
      ['Panel', 'Frame', 'Tote'],
    ];
    for (final row in rows) {
      final rects = [for (final w in row) tester.getRect(segment(w))];
      expect(rects.first.left, closeTo(16 + 96 + 8 + 1, 0.5), reason: '${row.first}: inside the 1 px edge');
      expect(rects.last.right, closeTo(phone.width - 16 - 1, 0.5), reason: row.last);
      for (final (i, r) in rects.indexed) {
        expect(r.height, 38.0, reason: row[i]);
        expect(r.width, greaterThanOrEqualTo(44), reason: row[i]);
        expect(r.width, closeTo(rects.first.width, 0.5), reason: '${row[i]}: equal widths');
      }
      final words = tester.widget<Text>(find.descendant(of: finish, matching: find.text(row[1])));
      expect(words.style!.fontSize, 15.81);
    }
    // The selected segment: text ground, white words, toggled; the others white.
    expect(pressable(tester, segment('Panel')).toggled, isTrue);
    expect(pressable(tester, segment('Frame')).toggled, isFalse);
    expect(tester.widget<Text>(find.descendant(of: finish, matching: find.text('Panel'))).style!.color, PhonePalette.white);
    expect(tester.widget<Text>(find.descendant(of: finish, matching: find.text('Frame'))).style!.color, PhonePalette.text);
    bool grounded(String words, Color color) => find
        .descendant(of: segment(words), matching: find.byWidgetPredicate((w) =>
            w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == color))
        .evaluate()
        .isNotEmpty;
    expect(grounded('Panel', PhonePalette.text), isTrue);
    expect(grounded('Frame', PhonePalette.white), isTrue);

    // Zoom: − and + 40 wide with 16 px icons, the percentage 14/600 tabular between them.
    for (final (f, icon) in [(zoomOut, tabler.ZoomOut), (zoomIn, tabler.ZoomIn)]) {
      expect(tester.getSize(f), const Size(40, 38));
      expect(iconLook(tester, find.descendant(of: f, matching: find.byType(icon))).size, 16);
    }
    final pct = tester.widget<Text>(find.descendant(of: zoomFit, matching: find.text('${c.percent}%')));
    expect((pct.style!.fontSize, pct.style!.fontWeight), (15.81, FontWeight.w600));
    expect(pct.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(tester.getRect(zoomOut).left, closeTo(16 + 96 + 8 + 1, 0.5));
    expect(tester.getRect(zoomIn).right, closeTo(phone.width - 16 - 1, 0.5));

    // Two rows 8 apart, centred in the panel, and nothing to scroll.
    final mount = tester.getRect(segment('Panel')), zoom = tester.getRect(zoomFit);
    expect(zoom.top - mount.bottom, closeTo(1 + 8 + 1, 0.5), reason: 'two edges and the 8 px gap');
    expect((mount.top - 1) - box.top, closeTo(box.bottom - (zoom.bottom + 1), 1), reason: 'centred');
    expect(reach(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a 320 px phone the mount words show in full: the icons go where both would not fit', (tester) async {
    await tester.runAsync(loadFonts);
    await pumpStudio(tester, size: const Size(320, 568));
    await tester.tap(key('tab-finish'));
    await tester.pumpAndSettle();
    for (final words in ['Panel', 'Frame', 'Tote']) {
      final p = tester.renderObject<RenderParagraph>(find.descendant(of: finish, matching: find.text(words)));
      expect(p.didExceedMaxLines, isFalse, reason: '$words is not cut short');
      expect(p.size.width, greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.01), reason: '$words in full');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone Frame puts the board in its frame', (tester) async {
    final c = await openFinish(tester);
    // Measured in centimetres (the rect over the scale): the board is refitted to the canvas, frame and all.
    final before = tester.getSize(key('phone-board')) / c.ppc;
    await press(tester, segment('Frame'));
    expect(c.mount, Mount.frame);
    expect(pressable(tester, segment('Frame')).toggled, isTrue);
    expect(pressable(tester, segment('Panel')).toggled, isFalse);
    final after = tester.getSize(key('phone-board')) / c.ppc;
    expect(after.width > before.width + 1 && after.height > before.height + 1, isTrue, reason: 'the frame\'s reach, cm: $before then $after');
    final board = tester.getRect(key('phone-board')), area = tester.getRect(key('phone-canvas'));
    expect(area.contains(board.topLeft) && area.contains(board.bottomRight), isTrue, reason: 'fitted, frame and all: $board in $area');
  });

  testWidgets('on a phone Zoom steps by twenties from 60 to 160; the percentage goes back to 100', (tester) async {
    final c = await openFinish(tester);
    expect(c.percent, 100);
    for (final n in [120, 140, 160]) {
      await press(tester, zoomIn);
      expect(c.percent, n);
      expect(find.descendant(of: zoomFit, matching: find.text('$n%')), findsOneWidget);
    }
    expect(pressable(tester, zoomIn).onPressed, isNull, reason: '+ at 160');
    expect(pressable(tester, zoomOut).onPressed, isNotNull);
    await press(tester, zoomFit);
    expect(c.percent, 100);
    expect(pressable(tester, zoomIn).onPressed, isNotNull);
    await press(tester, zoomOut);
    expect(c.percent, 80);
    await press(tester, zoomOut);
    expect(c.percent, 60);
    expect(pressable(tester, zoomOut).onPressed, isNull, reason: '− at 60');
    expect(find.bySemanticsLabel('Fit'), findsOneWidget);
  });

  // A tall narrow window fits the board big, so 160 % of it is past the scale's own limit (zoomMax).
  testWidgets('on a tall narrow window + goes disabled once the scale is at its limit, and the percentage stops there',
      (tester) async {
    final c = await pumpStudio(tester, size: const Size(600, 1100));
    await tester.tap(key('tab-finish'));
    await tester.pumpAndSettle();
    expect(c.fitPpc * 160 / 100, greaterThan(zoomMax), reason: 'the size reaches the limit: fitPpc ${c.fitPpc}');
    for (var i = 0; i < 5 && pressable(tester, zoomIn).onPressed != null; i++) {
      await press(tester, zoomIn);
    }
    expect(c.ppc, zoomMax);
    expect(pressable(tester, zoomIn).onPressed, isNull, reason: '+ with the scale pinned at zoomMax');
    final shown = c.percent;
    expect(find.descendant(of: zoomFit, matching: find.text('$shown%')), findsOneWidget);
    await tester.tap(zoomIn);
    await tester.pumpAndSettle();
    expect(c.percent, shown, reason: 'a press on the disabled + changes nothing');
    expect(pressable(tester, zoomOut).onPressed, isNotNull);
  });

  testWidgets('on a phone every Preview control is a target: segments 38 tall and at least 44 wide', (tester) async {
    await openFinish(tester);
    expect(checkTargets(tester, 44, allowed: phoneSizedItems), greaterThanOrEqualTo(6 + 3));
    for (final w in phoneSizedItems.keys) {
      final f = {'Zoom out': zoomOut, 'Fit': zoomFit, 'Zoom in': zoomIn}[w] ?? segment(w);
      final s = tester.getSize(f);
      expect(s.height, greaterThanOrEqualTo(38), reason: w);
      expect(s.width, greaterThanOrEqualTo(w.startsWith('Zoom') ? 40 : 44), reason: w);
    }
  });
}
