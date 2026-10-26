/* The Cloth box tab of the phone's dock (redesign handover, "Dock panel — Cloth box tab"): the box picker, which opens
   Your boxes, and Add pieces; under them a swatch for each cloth in the box with the pieces still free, and Delete box
   under those (owner, 20 Oct). A box that holds no cloth offers Delete box beside a tooltip pointing up at Add
   pieces. */
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../l10n/app_localizations.dart';
import '../controller.dart';
import '../painters.dart' show swatchBase;
import '../pressable.dart';
import '../shelf_feed.dart' show ClothView;
import '../studio_screen.dart';
import 'phone_sheet.dart';
import 'phone_theme.dart';
import 'strip.dart';

class DockCloth extends StatelessWidget {
  const DockCloth({super.key, required this.c, required this.actions});
  final StudioController c;
  final StudioActions actions;

  /* Row 1 and, 8 under it, the swatches or what an empty box offers; the panel scrolls if the words are long. */
  @override
  Widget build(BuildContext context) {
    final words = L.of(context);
    final box = c.box;
    // With no box of hers on the board there is nothing to name, fix or delete: Your boxes, and the tooltip alone.
    final mine = box != null && c.mayEdit;
    final members = mine ? c.members(box) : const <int>[];
    // The pieces still free: in stock, less those on the board.
    final use = <int, int>{};
    for (final f in c.grid ?? const <int>[]) {
      use[f] = (use[f] ?? 0) + 1;
    }
    final sample = mine && c.isSample(box);
    return SingleChildScrollView(
      key: const ValueKey('dock-cloth'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: _picker(words, box, mine, sample)),
            const SizedBox(width: 8),
            KeyedSubtree(key: const ValueKey('add-pieces'), child: PhoneButton(text: words.boxesAddPieces, icon: const tabler.Plus(),
                onPressed: () => actions.openCloth(mine ? ClothOpen.add(box) : const ClothOpen.addToNew()))),
          ]),
        ),
        const SizedBox(height: 8),
        if (members.isNotEmpty) ...[
          Strip(
            scrollKey: const ValueKey('dock-swatches'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (i, m) in members.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                _swatch(context, words, c.cloth[m], c.cloth[m].stock - (use[m] ?? 0)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft, child: KeyedSubtree(key: const ValueKey('delete-box'),
                child: PhoneButton(text: words.boxesDelete, kind: PhoneButtonKind.redText, busy: c.deleting,
                    onPressed: () => actions.deleteBox(box!)))),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (mine)
                PhoneButton(text: words.boxesDelete, kind: PhoneButtonKind.redText, busy: c.deleting,
                    onPressed: () => actions.deleteBox(box)),
              Expanded(child: Align(alignment: Alignment.topRight, child: _StartHere(words.boxesStartHere))),
            ]),
          ),
      ]),
    );
  }

  /* 48 tall on the canvas ground, a 1 px strong edge under it: the boxes icon, the box's name (14/500) over its pieces
     (12, text2), the chevron at the right. A screen reader hears both lines. */
  Widget _picker(L words, int? box, bool mine, bool sample) {
    final name = !mine ? words.canvasYourBoxes : sample ? words.boxesSample : words.boxesName('${c.boxNumbers[box] ?? ''}');
    final pieces = !mine ? null
        : sample ? '${words.boxesPieces(c.piecesIn(box!))} · ${words.boxesSampleColours}' : words.boxesPieces(c.piecesIn(box!));
    return Pressable(
      key: const ValueKey('box-picker'),
      label: pieces == null ? name : '$name\n$pieces',
      excludeChildSemantics: true,
      onPressed: actions.openBoxes,
      builder: (context, st) => focusRing(st.focused, Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: st.hovered ? PhonePalette.hover : PhonePalette.canvas,
            border: const Border(bottom: BorderSide(color: PhonePalette.strong))),
        child: Row(children: [
          roleIcon(const tabler.Stack2(), PType.cardLabel),
          const SizedBox(width: iconGap),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: pText(PType.cardLabel)),
            if (pieces != null)
              Text(pieces, maxLines: 1, overflow: TextOverflow.ellipsis, style: pText(PType.finePrint, color: PhonePalette.text2)),
          ])),
          const SizedBox(width: 8),
          tablerIcon(const tabler.ChevronDown(), size: 16),
        ]),
      )),
    );
  }

  /* A 48 × 48 photo of the cloth, `{n} left` 4 under it. With none left it fades to 45 %, the words stay, and a blue +
     sits in its corner. A button that opens the cloth to be fixed: swatches show only on a box she may change
     (`mine`), the Sample box too. */
  Widget _swatch(BuildContext context, L words, ClothView cloth, int left) {
    final out = left <= 0, n = out ? 0 : left;
    final label = out
        ? words.canvasSwatchAllUsed(cloth.name, '${cloth.stock}')
        : words.canvasSwatchLabel(cloth.name, '$n', '${cloth.stock}');
    final px = (48 * MediaQuery.devicePixelRatioOf(context)).round();
    final image = cloth.image;
    Widget photo = Container(
      color: swatchBase,
      // The chip's edge: 1 px of black at 12 %, inside it.
      foregroundDecoration: BoxDecoration(border: Border.all(color: const Color(0x1F000000))),
      child: image == null ? null : Image(
          image: ResizeImage(image, width: px, height: px, policy: ResizeImagePolicy.fit),
          fit: BoxFit.cover, excludeFromSemantics: true, gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink()),
    );
    if (out) photo = Opacity(opacity: 0.45, child: photo);
    Widget item(bool focused) => Column(mainAxisSize: MainAxisSize.min, children: [
          focusRing(focused, SizedBox.square(
            key: const ValueKey('swatch-chip'),
            dimension: 48,
            child: Stack(fit: StackFit.expand, children: [
              photo,
              if (out)
                Positioned(right: 0, bottom: 0, child: SizedBox.square(key: const ValueKey('swatch-badge'), dimension: 20,
                    child: ColoredBox(color: PhonePalette.blue,
                        child: Center(child: tablerIcon(const tabler.Plus(), size: 14, color: PhonePalette.white))))),
            ]),
          )),
          const SizedBox(height: 4),
          Text(words.canvasSwatchLeft('$n'), style: pText(PType.finePrint)),
        ]);
    return Pressable(
      key: ValueKey('swatch-${cloth.id}'),
      // All used, the label already says a tap adds more; otherwise it says what a tap opens.
      label: out ? label : '$label · ${words.clothFixTitle}',
      excludeChildSemantics: true,
      onPressed: () => actions.openCloth(ClothOpen.fix(cloth.id)),
      builder: (context, st) => item(st.focused),
    );
  }
}

/* The empty box's tooltip: at most 190 wide, white 13/18 on the dark ground, padding 8 12, its 12 px caret on top, 24 px
   in from its right edge, pointing up at Add pieces. */
class _StartHere extends StatelessWidget {
  const _StartHere(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        key: const ValueKey('start-here'),
        constraints: const BoxConstraints(maxWidth: 190),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Padding(
            padding: EdgeInsets.only(right: 24),
            child: CustomPaint(key: ValueKey('start-here-caret'), size: Size(12, 6), painter: _Caret()),
          ),
          Container(
            color: PhonePalette.dark,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(text, style: pText(PType.metadata, color: PhonePalette.white)),
          ),
        ]),
      );
}

class _Caret extends CustomPainter {
  const _Caret();
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
      Path()..moveTo(0, size.height)..lineTo(size.width / 2, 0)..lineTo(size.width, size.height)..close(),
      Paint()..color = PhonePalette.dark);
  @override
  bool shouldRepaint(_Caret old) => false;
}
