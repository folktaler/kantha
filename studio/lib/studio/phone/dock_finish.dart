/* The Preview tab of the phone's dock (redesign handover, "Dock panel — Finish tab"; renamed Preview by the owner,
   19 Oct): Mount and Zoom, each a label and a segmented control. Stitches are on the Design tab (owner, 20 Oct). Zoom
   is 60–160 % of the fitted board, in steps of 20 (decision 4). */
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../l10n/app_localizations.dart';
import '../../l10n/words.dart';
import '../../solver/geometry.dart' show Mount, mounts;
import '../controller.dart';
import '../pressable.dart';
import 'phone_theme.dart';

/* Each mount's icon in its segment: the panel alone, framed, or on a tote bag. */
const _mountIcon = <Mount, tabler.Icon>{Mount.none: tabler.Square(), Mount.frame: tabler.Frame(), Mount.tote: tabler.ShoppingBag()};

/* The zoom's ends, in percent of the fitted board, and its step. */
const _zoomLeast = 60, _zoomMost = 160, _zoomStep = 20;

class DockFinish extends StatelessWidget {
  const DockFinish({super.key, required this.c});
  final StudioController c;

  /* Two rows 8 apart, centred in the panel, 16 px from its sides. */
  @override
  Widget build(BuildContext context) {
    final words = L.of(context);
    final rows = [
      // The frame and the tote are for Level 1's A4 board alone.
      if (c.onA4) _row(words.canvasMountEyebrow, _segments([
        for (final m in mounts)
          _segment(key: 'mount-${m.name}', text: words.mountName(m), icon: _mountIcon[m], on: c.mount == m,
              onPressed: () => c.setMount(m)),
      ])),
      _row(words.canvasZoom, _zoom(words)),
    ];
    return LayoutBuilder(
      key: const ValueKey('dock-finish'),
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - 16)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final (i, r) in rows.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              r,
            ],
          ]),
        ),
      ),
    );
  }

  /* 96 px for the label (the eyebrow role, caps, text2), 8 px, then the control. The caps are a style: a screen reader
     hears the words as they are written. */
  Widget _row(String label, Widget control) => Row(children: [
        SizedBox(
          width: 96,
          child: Semantics(label: label, excludeSemantics: true,
              child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: pText(PType.eyebrow, color: PhonePalette.text2))),
        ),
        const SizedBox(width: 8),
        Expanded(child: control),
      ]);

  /* A 1 px strong edge with 2 px corners round 38 px segments, with 1 px divider lines between them. */
  Widget _segments(List<Widget> cells) => DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: PhonePalette.strong), borderRadius: kControlRadius),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: SizedBox(
            height: 38,
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
  Widget _segment({required String key, required String text, tabler.Icon? icon, required bool on,
      required VoidCallback onPressed}) {
    final colour = on ? PhonePalette.white : PhonePalette.text;
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

  /* − | the percentage | +. The percentage is Fit: a press goes back to 100. */
  Widget _zoom(L words) {
    final step = (c.percent / _zoomStep).round() * _zoomStep;
    // The board's scale has its own limits (zoomMin..zoomMax): pinned at one, that end does nothing, so it is disabled.
    final out = step > _zoomLeast && c.ppc > zoomMin ? () => c.zoomTo(math.max(_zoomLeast, step - _zoomStep)) : null;
    final into = step < _zoomMost && c.ppc < zoomMax ? () => c.zoomTo(math.min(_zoomMost, step + _zoomStep)) : null;
    final percent = words.canvasZoomPercent('${c.percent}');
    return _segments([
      _zoomEnd('zoom-out', words.canvasZoomOut, const tabler.ZoomOut(), out),
      Expanded(
        child: Pressable(
          key: const ValueKey('zoom-fit'),
          label: words.canvasFit,
          value: percent,
          excludeChildSemantics: true,
          onPressed: () => c.zoomTo(100),
          builder: (context, st) => focusRing(st.focused, Container(
            alignment: Alignment.center,
            color: st.hovered ? PhonePalette.hover : PhonePalette.white,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              roleIcon(const tabler.Maximize(), PType.labelStrong),
              const SizedBox(width: iconGap),
              Text(percent, maxLines: 1, style: pText(PType.labelStrong, figures: true)),
            ]),
          )),
        ),
      ),
      _zoomEnd('zoom-in', words.canvasZoomIn, const tabler.ZoomIn(), into),
    ]);
  }

  /* 40 px wide, a 16 px icon; at its end of the range, or with the scale at its limit, it is disabled and its icon drawn in strong. */
  Widget _zoomEnd(String key, String label, tabler.Icon icon, VoidCallback? onPressed) => SizedBox(
        width: 40,
        child: Pressable(
          key: ValueKey(key),
          label: label,
          excludeChildSemantics: true,
          onPressed: onPressed,
          builder: (context, st) => focusRing(st.focused, Container(
            alignment: Alignment.center,
            color: st.hovered ? PhonePalette.hover : PhonePalette.white,
            child: tablerIcon(icon, size: 16, color: onPressed == null ? PhonePalette.strong : PhonePalette.text),
          )),
        ),
      );
}
