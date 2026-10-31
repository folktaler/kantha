/* The Design tab of the phone's dock (redesign handover, "Dock panel — Patterns tab"; renamed Design by the owner,
   19 Oct): the pattern tiles, and under them one row, Show stitches (owner, 20 and 21 Oct): the switch, its words, and
   the thread that clears this design's cloth best, as a dot and its plain colour. The spacing is always Open and is
   not said. Under it Rows and Columns, one line for everyone (owner, 31 Oct 2026). */
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../l10n/app_localizations.dart';
import '../../l10n/words.dart';
import '../../solver/geometry.dart' show boardMin, boardMax;
import '../../solver/icons.dart';
import '../../solver/layouts.dart';
import '../controller.dart';
import '../painters.dart';
import '../pressable.dart';
import 'phone_theme.dart';
import 'phone_toast.dart';
import 'strip.dart';

/* Rows and Columns, measured at her text size for a column `width` wide: on one line when both fit beside each other
   (16 px in each side, 8 between), else Rows over Columns, their words a shared width so the numbers line up. The
   panel's height follows (phone_studio.dart dockPanelFor). */
({bool oneLine, double rows, double columns, double number}) boardSizeLine(BuildContext context, double width) {
  final words = L.of(context), scaler = MediaQuery.textScalerOf(context), dir = Directionality.of(context);
  double measure(String text) {
    final t = TextPainter(text: TextSpan(text: text, style: pText(PType.bodySmall)), maxLines: 1, textDirection: dir,
        textScaler: scaler)..layout();
    final w = t.width.ceilToDouble();
    t.dispose();
    return w;
  }
  final rows = measure(words.canvasRows), columns = measure(words.canvasColumns);
  final number = math.max(28.0, measure('$boardMax') + 4);
  // Each: its word, 4, minus, the number, plus.
  double stepper(double word) => word + 4 + 44 + number + 44;
  return (oneLine: 16 + stepper(rows) + 8 + stepper(columns) + 16 <= width, rows: rows, columns: columns, number: number);
}

final Map<LayoutKey, List<int>> _icons = {for (final k in layoutKeys) k: layoutIconLevels(k)};

/* A tile per pattern in a strip that scrolls sideways, 8 px under the panel's top, then the Show stitches row. A pattern the box
   cannot fill stays, faded to 35 %, and a tap on it says why and changes nothing (decision 11). The panel scrolls up
   and down, as Preview does, so with the phone's text set larger nothing runs over the tabs. */
class DockPatterns extends StatelessWidget {
  const DockPatterns({super.key, required this.c, required this.toaster});
  final StudioController c;
  final Toaster toaster;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      key: const ValueKey('dock-design'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          Strip(
            scrollKey: const ValueKey('dock-patterns'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final k in layoutKeys) ...[
                if (k != layoutKeys.first) const SizedBox(width: 8),
                _tile(context, k),
              ],
            ]),
          ),
          const SizedBox(height: 4),
          _stitches(context),
          _size(context),
        ]),
      );

  /* The board's size (owner, 30 and 31 Oct 2026): Rows and Columns, each its word, minus, the number and plus, 16 px
     in, under Show stitches, in the room the taller panel gives them (phone_studio.dart dockPanelFor): side by side
     on one line where the column is boardSizeOneRow wide or more, else Rows over Columns. */
  Widget _size(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final words = L.of(context), g = c.chosen, line = boardSizeLine(context, box.maxWidth);
    // Stacked, the two words share the wider's width, so the numbers line up.
    final shared = line.oneLine ? null : math.max(line.rows, line.columns);
    final rows = _stepper('rows', words.canvasRows, g.rows, words.canvasRowsFewer, words.canvasRowsMore,
            (n) => c.setBoardSize((rows: n, cols: g.cols)), shared, line.number),
        columns = _stepper('columns', words.canvasColumns, g.cols, words.canvasColumnsFewer, words.canvasColumnsMore,
            (n) => c.setBoardSize((rows: g.rows, cols: n)), shared, line.number);
    return Padding(
      key: const ValueKey('board-size'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: line.oneLine
          ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [rows, const SizedBox(width: 8), columns])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [rows, columns]),
    );
  });

  /* A pattern pressed. When it deals an arrangement, the first time on this device: the note that pressing it again
     makes a new one. It waits for any other toast to go, and counts as shown only once she has had the whole of it. */
  void _press(LayoutKey k, String again) {
    c.loadLayout(k);
    if (c.grid != null || c.solving) unawaited(_noteOnce(again));
  }

  Future<void> _noteOnce(String again) async {
    if (!await c.patternAgainDue()) return;
    for (var i = 0; i < 3; i++) {
      await toaster.idle();
      if (await toaster.sayWhole(again)) return c.patternAgainShown();
    }
    c.patternAgainMissed();
  }

  /* Its word, then minus, the number, plus: each button 44 px square, faded and not pressed at its end. */
  Widget _stepper(String key, String name, int n, String fewer, String more, void Function(int) set, double? word,
      double number) {
    Widget button(String k, String label, tabler.Icon icon, bool can, VoidCallback go) => Pressable(
          key: ValueKey('$key-$k'),
          label: label,
          value: '$n',
          excludeChildSemantics: true,
          onPressed: can ? go : null,
          builder: (context, st) => focusRing(st.focused, Opacity(
            opacity: can ? 1 : 0.35,
            child: Container(
              width: 44, height: 44,
              alignment: Alignment.center,
              color: st.hovered && can ? PhonePalette.hover : PhonePalette.white,
              child: tablerIcon(icon, size: 18),
            ),
          )),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: word, child: Text(name, maxLines: 1, style: pText(PType.bodySmall))),
      const SizedBox(width: 4),
      button('fewer', fewer, const tabler.Minus(), n > boardMin, () => set(n - 1)),
      SizedBox(width: number, child: Text('$n', key: ValueKey('$key-count'), textAlign: TextAlign.center,
          style: pText(PType.bodySmall, figures: true))),
      button('more', more, const tabler.Plus(), n < boardMax, () => set(n + 1)),
    ]);
  }

  /* One row across the panel, at least 44 tall and one target: 16 px in, the switch, the words "Show stitches", then a
     dot in the thread's colour and the colour's plain name (canvas.stitchColours), on or off (owner, 21 Oct). A screen
     reader hears Show stitches, on or off, then the colour. */
  Widget _stitches(BuildContext context) {
    final words = L.of(context);
    final on = c.stitch;
    final thread = c.threadShown;
    final name = words.stitchColour(thread.key);
    return Pressable(
      key: const ValueKey('stitch-switch'),
      label: words.canvasStitchesSwitch,
      value: name,
      toggled: on,
      excludeChildSemantics: true,
      onPressed: () => c.setStitch(!on),
      builder: (context, st) => focusRing(st.focused, Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: st.hovered ? PhonePalette.hover : PhonePalette.white,
        child: Row(children: [
          _switch(on),
          const SizedBox(width: 12),
          Flexible(child: Text(words.canvasStitchesSwitch, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: pText(PType.bodySmall))),
          const SizedBox(width: 16),
          Row(key: const ValueKey('stitch-thread'), mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: hexColor(thread.hex), shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFA9A392)))),
            const SizedBox(width: iconGap),
            Text(name, maxLines: 1, style: pText(PType.bodySmall, color: PhonePalette.text2)),
          ]),
        ]),
      )),
    );
  }

  /* 40 × 24 with the control's 2 px corners: on, the text colour with a white 18 px square at the right; off, white in
     a 1 px strong edge, the square in strong at the left. */
  Widget _switch(bool on) => Container(
        key: const ValueKey('stitch-switch-track'),
        width: 40, height: 24,
        padding: const EdgeInsets.all(2),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(borderRadius: kControlRadius, color: on ? PhonePalette.text : PhonePalette.white,
            border: Border.all(color: on ? PhonePalette.text : PhonePalette.strong)),
        child: SizedBox.square(dimension: 18,
            child: DecoratedBox(decoration: BoxDecoration(borderRadius: kControlRadius,
                color: on ? PhonePalette.white : PhonePalette.strong))),
      );

  /* 80 × 124 with 2 px corners: the pattern's icon in a 46 × 64 box, the name under it. Selected: the tint, a 2 px
     edge in the action colour and a mark in a square of it at the top right: ↻ while the board holds an arrangement,
     as a press again deals it afresh (owner, 31 Oct 2026), and a screen reader hears that it is chosen, then "Press
     {pattern} again for a new arrangement."; with nothing on the board (an empty box, or none that can fill), the
     check. */
  Widget _tile(BuildContext context, LayoutKey k) {
    final words = L.of(context), f = c.feasible[k];
    final cannot = f != null && !f.fills;
    final title = words.layoutTitle(k);
    final why = cannot ? words.canvasLayoutCannot(title, words.notFillable(f.why!)) : null;
    // The chosen tile wears ↻, and says to press it again, while the board holds an arrangement a press would deal
    // afresh.
    final on = k == c.layout, again = words.canvasPatternAgain(title), anew = on && c.grid != null;
    return Pressable(
      key: ValueKey('tile-${k.name}'),
      label: why ?? (anew ? '$title\n$again' : title),
      excludeChildSemantics: true,
      selected: on,
      onPressed: () => why != null ? toaster.say(why) : _press(k, again),
      builder: (context, st) => Opacity(
        opacity: cannot ? 0.35 : 1,
        child: focusRing(st.focused, Container(
          width: 80, height: 124,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: kControlRadius,
              color: on ? PhonePalette.tint : (st.hovered ? PhonePalette.hover : PhonePalette.white)),
          foregroundDecoration: BoxDecoration(borderRadius: kControlRadius,
              border: on ? Border.all(color: PhonePalette.blue, width: 2) : Border.all(color: PhonePalette.border)),
          child: Stack(fit: StackFit.expand, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
              child: Column(children: [
                SizedBox(width: 46, height: 64, child: CustomPaint(painter: LayoutIconPainter(levels: _icons[k]!, active: on))),
                const SizedBox(height: 6),
                SizedBox(height: 28, child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: pText(PType.tile))),
              ]),
            ),
            if (on)
              Positioned(top: 0, right: 0, child: SizedBox.square(dimension: 20,
                  child: ColoredBox(color: PhonePalette.blue,
                      child: Center(child: anew
                          ? KeyedSubtree(key: const ValueKey('tile-again'),
                              child: tablerIcon(const tabler.RotateClockwise(), size: 14, color: PhonePalette.white))
                          : tablerIcon(const tabler.Check(), size: 14, color: PhonePalette.white))))),
          ]),
        )),
      ),
    );
  }
}
