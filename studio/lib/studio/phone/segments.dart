/* The phone's segmented controls and the labelled row they sit in, shared by the dock's Preview tab and the Share
   sheet. */
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../pressable.dart';
import 'phone_theme.dart';

/* A labelled row (the dock's Mount and Zoom, Share's Paper): 96 px for the label (the eyebrow role, caps, text2), 8 px, then the control. The caps are a style: a screen reader
   hears the words as they are written. */
Widget labelledRow(String label, Widget control) => Row(children: [
      SizedBox(
        width: 96,
        child: Semantics(label: label, excludeSemantics: true,
            child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: pText(PType.eyebrow, color: PhonePalette.text2))),
      ),
      const SizedBox(width: 8),
      Expanded(child: control),
    ]);

/* A 1 px strong edge with 2 px corners round segments `height` tall (38 in the dock), with 1 px divider lines between
   them. */
Widget segments(List<Widget> cells, {double height = 38}) => DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: PhonePalette.strong), borderRadius: kControlRadius),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: SizedBox(
          height: height,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, cell) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: 1, child: ColoredBox(color: PhonePalette.divider)),
              cell,
            ],
          ]),
        ),
      ),
    );

/* An equal share of the row, its `icon` before its words: selected, the text colour as its ground and white words.
   Where the words and the icon would not both fit, the icon goes, so the words are never cut. */
Widget segmentCell({required String key, required String text, tabler.Icon? icon, required bool on,
    required VoidCallback? onPressed}) {
  final colour = on ? PhonePalette.white : (onPressed == null ? PhonePalette.text2 : PhonePalette.text);
  final style = pText(PType.control, color: colour);
  return Expanded(
    child: Pressable(
      key: ValueKey(key),
      toggled: on,
      onPressed: onPressed,
      builder: (context, st) => focusRing(st.focused, Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: on ? PhonePalette.text : (st.hovered ? PhonePalette.hover : PhonePalette.white)),
        child: LayoutBuilder(builder: (context, box) {
          final words = TextPainter(text: TextSpan(text: text, style: style), maxLines: 1,
              textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context))..layout();
          final withIcon = icon != null && words.width + roleIconSize(PType.control) + iconGap <= box.maxWidth;
          words.dispose();
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (withIcon) ...[roleIcon(icon, PType.control, color: colour), const SizedBox(width: iconGap)],
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          ]);
        }),
      )),
    ),
  );
}
