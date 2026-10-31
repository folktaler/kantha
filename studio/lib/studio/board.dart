/* The board (the sheet, from the tote under it to the 4 cm line): the A4 sheet at
   the controller's scale, its printed grid on Plain, the 35 squares each wearing its own
   cloth, the grid over them, the stitches, and the frame or tote around it. */
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../solver/geometry.dart';
import 'controller.dart';
import 'mounts.dart';
import 'painters.dart';
import 'phone/phone_theme.dart';
import 'pressable.dart';
import 'sheet_geometry.dart';
import 'shelf_feed.dart';

/* The board's own colours: the sheet and the 4 cm label (a cloth's ground is swatchBase).
   The board is what she makes, not the studio's chrome. */
const _sheet = Color(0xFFFCFCFA), _dimBg = Color(0xFFF6F2E6), _dimInk = Color(0xFF666A75);

/* The squares in the order they are laid: column by column, each over the one before. One list per sheet. */
final _laidOn = <SheetGrid, List<int>>{};
List<int> _laid(SheetGrid g) => _laidOn.putIfAbsent(g, () => [for (var i = 0; i < g.rows * g.cols; i++) i]
  ..sort((p, q) => layIndex(p ~/ g.cols, p % g.cols, g).compareTo(layIndex(q ~/ g.cols, q % g.cols, g))));

/* The drop (owner, 21 Oct): after a tap on another pattern's tile, its squares fall into place one after another, row by
   row from the bottom, as the home page's do (kantha.app's panel stack) at about a quarter of its timing: 110 ms
   apart there and 27 here, a 0.36 s fall there and 88 ms here, so the 35 land in about a second. Each falls from just
   over the board on the home page's curve and is solid 0.1 / 0.36 of the way into its fall. */
const _dropGap = 27, _dropFall = 88;
final _dropTotal = Duration(milliseconds: (cells - 1) * _dropGap + _dropFall);
/* On a Level 2 board of more squares the drop still lands in the same time: the gap between squares shrinks. */
double _gapOn(SheetGrid g) => math.min(_dropGap.toDouble(), (_dropTotal.inMilliseconds - _dropFall) / math.max(1, g.rows * g.cols - 1));
const _dropCurve = Cubic(.55, 0, 1, .45);

/* A square's place in the drop: the bottom row first, left to right, then the row over it. */
int _dropOrder(int i, SheetGrid g) => (g.rows - 1 - i ~/ g.cols) * g.cols + i % g.cols;

class Board extends StatefulWidget {
  const Board({super.key, required this.c, required this.onEmptyCell});
  final StudioController c;
  /* Decision 14: with nothing arranged, nothing being arranged and the box short of 35 pieces (or no box), each of the
     35 squares is a dashed button that calls this to add cloth. A full box that could not be arranged keeps the empty
     sheet under its note. */
  final VoidCallback onEmptyCell;

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> with SingleTickerProviderStateMixin {
  StudioController get c => widget.c;
  VoidCallback get onEmptyCell => widget.onEmptyCell;
  /* At 1 the squares are in place; a drop runs it from 0. */
  late final AnimationController _drop = AnimationController(vsync: this, duration: _dropTotal, value: 1);
  late int _drops = c.drops;
  /* The board the drop is for: any other board put up while it runs (a saved design opened, cloth added) stops it. */
  List<int>? _dropping;

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  /* A new tap's board drops from the start, cutting short any drop still running, so two patterns never mix; with
     reduced motion there is no drop. */
  void _follow() {
    if (c.drops != _drops) {
      _drops = c.drops;
      _dropping = c.grid;
      if (c.grid != null && !MediaQuery.disableAnimationsOf(context)) {
        _drop.forward(from: 0);
        return;
      }
    }
    if (_drop.isAnimating && !identical(c.grid, _dropping)) _drop.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    _follow();
    final words = L.of(context);
    final ppc = c.ppc, cellPx = patchCm * ppc;
    // The frame or tote takes up room in the layout, so it is centred and nothing sits under it.
    final reach = reachOf(c.mount);
    final flat = c.mount == Mount.none, framed = c.mount == Mount.frame;
    final grid = c.grid;
    final dens = c.density;
    final thread = c.threadShown;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final g = c.sheet, cells = g.rows * g.cols;

    return Padding(
      padding: EdgeInsets.fromLTRB(reach.left * ppc, reach.top * ppc, reach.right * ppc, reach.bottom * ppc),
      child: SizedBox(
        width: g.w * ppc, height: g.h * ppc,
        child: Stack(clipBehavior: Clip.none, children: [
          if (c.mount == Mount.tote) ToteUnder(ppc: ppc),
          Positioned.fill(
            child: DecoratedBox(
              decoration: framed
                  ? const BoxDecoration(color: _sheet, boxShadow: [
                      BoxShadow(offset: Offset(0, 2), blurRadius: 4, color: Color(0x141E2027)),
                      BoxShadow(offset: Offset(0, 14), blurRadius: 34, color: Color(0x141E2027)),
                    ])
                  : const BoxDecoration(),
              // The empty squares take Tab in reading order, row by row, wherever the board is scrolled to.
              child: FocusTraversalGroup(policy: WidgetOrderTraversalPolicy(), child: Stack(clipBehavior: Clip.none, children: [
                if (flat)
                  Positioned(
                    left: (g.mx - bleedCm) * ppc, top: (g.my - bleedCm) * ppc,
                    width: (g.bw + bleedCm * 2) * ppc, height: (g.bh + bleedCm * 2) * ppc,
                    child: IgnorePointer(child: CustomPaint(painter: PaperGridPainter(g))),
                  ),
                if (grid != null)
                  Positioned.fill(child: ClipRect(
                    clipper: _WhileDropping(Rect.fromLTRB(-1e4, g.my * ppc, 1e4, 1e4), _drop),
                    child: Stack(clipBehavior: Clip.none, children: [
                      for (final i in _laid(g)) if (i < grid.length) _cell(words, g, i, grid[i], ppc, cellPx, dpr),
                    ]),
                  ))
                else if (!c.solving && (c.box == null || c.piecesIn(c.box!) < cells))
                  for (var i = 0; i < cells; i++) _emptyCell(words, g, i, ppc, cellPx),
                if (flat)
                  Positioned(
                    left: g.mx * ppc, top: g.my * ppc, width: g.bw * ppc, height: g.bh * ppc,
                    child: IgnorePointer(child: CustomPaint(painter: GhostGridPainter(g))),
                  ),
                if (c.solving && grid == null)
                  Positioned.fill(child: Center(
                      child: Text(words.canvasSolving, style: pText(PType.metadata, color: PhonePalette.text2)))),
              ])),
            ),
          ),
          if (c.mount == Mount.tote) ToteEdge(ppc: ppc, hex: thread.hex),
          if (flat && c.onA4) _dimension(words, g, ppc, cellPx),
          Positioned(
            left: g.mx * ppc, top: g.my * ppc, width: g.bw * ppc, height: g.bh * ppc,
            child: IgnorePointer(child: AnimatedOpacity(
              opacity: c.stitch ? 1 : 0, duration: const Duration(milliseconds: 200),
              child: CustomPaint(painter: StitchPainter(density: dens, thread: thread, sheet: g)),
            )),
          ),
          if (framed) FrameOver(ppc: ppc),
        ]),
      ),
    );
  }

  /* The square in its place, or on its way there: transform and opacity only, so a drop lays nothing out again. */
  Widget _falling(SheetGrid g, int i, double ppc, double cellPx, Widget cell) {
    final r = i ~/ g.cols, foot = footprintOf(r, i % g.cols, g);
    final start = _dropOrder(i, g) * _gapOn(g) / _dropTotal.inMilliseconds;
    final span = _dropFall / _dropTotal.inMilliseconds;
    // drive(), not CurvedAnimation: these are made at every build, and listen to the drop only while shown.
    final fall = _drop.drive(CurveTween(curve: Interval(start, start + span)));
    final up = -(r * cellPx + foot.h * ppc);
    return FadeTransition(
      opacity: _drop.drive(CurveTween(curve: Interval(start, start + span * .1 / .36))),
      child: AnimatedBuilder(
        animation: fall,
        builder: (context, child) => Transform.translate(offset: Offset(0, up * (1 - _dropCurve.transform(fall.value))), child: child),
        // While it falls, the square is its 4 cm, as the home page's are; at rest its cut runs under its neighbours.
        child: ClipRect(clipper: _WhileDropping(Rect.fromLTWH(0, 0, cellPx, cellPx), _drop), child: cell),
      ),
    );
  }

  Widget _cell(L words, SheetGrid g, int i, int f, double ppc, double cellPx, double dpr) {
    final r = i ~/ g.cols, col = i % g.cols, foot = footprintOf(r, col, g);
    final cloth = c.cloth[f];
    final cut = cutCm * ppc;
    return Positioned(
      key: ValueKey('cell-$i'),
      left: g.mx * ppc + col * cellPx, top: g.my * ppc + r * cellPx, width: foot.w * ppc, height: foot.h * ppc,
      child: _falling(g, i, ppc, cellPx, Semantics(
        container: true, image: true, excludeSemantics: true,
        label: words.canvasCellLabel('${r + 1}', '${col + 1}', cloth.name),
        child: DecoratedBox(
          // inset 0 0 0 1px #1e202722 (under the cloth, as an inset shadow is), 2px 2px 3px #1e20271f.
          decoration: BoxDecoration(color: swatchBase, border: Border.all(color: const Color(0x221E2027)),
              boxShadow: const [BoxShadow(offset: Offset(2, 2), blurRadius: 3, color: Color(0x1F1E2027))]),
          child: ClipRect(
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0, top: 0, width: cut, height: cut,
                child: _ClothSquare(cloth: cloth, turns: c.rot[i], cacheWidth: (cutCm * zoomMax * dpr).round()),
              ),
            ]),
          ),
        ),
      )),
    );
  }

  /* An empty square on the phone (handover, Canvas, "Empty cell"): its 4 cm on the sheet in white, a 1 px dashed strong
     edge 4 px in, a 16 px plus at 60 %; a tap adds cloth. */
  Widget _emptyCell(L words, SheetGrid g, int i, double ppc, double cellPx) {
    final r = i ~/ g.cols, col = i % g.cols;
    return Positioned(
      key: ValueKey('empty-cell-$i'),
      left: g.mx * ppc + col * cellPx, top: g.my * ppc + r * cellPx, width: cellPx, height: cellPx,
      child: Pressable(
        label: words.canvasEmptyCell('${r + 1}', '${col + 1}'),
        excludeChildSemantics: true,
        onPressed: onEmptyCell,
        builder: (context, st) => focusRing(st.focused, ColoredBox(
          color: PhonePalette.white,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CustomPaint(
              painter: const DashedRectPainter(color: PhonePalette.strong),
              child: Center(child: tablerIcon(const tabler.Plus(), size: 16, color: PhonePalette.text.withValues(alpha: 0.6))),
            ),
          ),
        )),
      ),
    );
  }

  /* The 4 cm line over the first square, its length written on it. The label keeps its own width, centred on the
     line: on a phone the square can be narrower than the words, and they would be cut short ("4 cr"). */
  Widget _dimension(L words, SheetGrid g, double ppc, double cellPx) => Positioned(
        left: g.mx * ppc, top: -22 - 10, width: cellPx, height: 21,
        child: IgnorePointer(
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Positioned(left: 0, right: 0, top: 10, height: 1, child: DecoratedBox(decoration: BoxDecoration(
                color: const Color(0x6633507F), boxShadow: const [BoxShadow(color: _dimBg, spreadRadius: 1.5)]))),
            OverflowBox(
              maxWidth: double.infinity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: _dimBg, border: Border.all(color: const Color(0x3333507F)),
                    borderRadius: BorderRadius.circular(3)),
                child: Text(words.cm(patchCm), softWrap: false,
                    style: pText(PType.dimension, color: _dimInk, figures: true)),
              ),
            ),
          ]),
        ),
      );
}

/* While a drop runs, `rect`; at rest nothing is cut, so the board looks as it does without a drop. The sheet's top
   edge (the squares above it are cut off as they fall, as the home page's panel cuts them), or a square's 4 cm. */
class _WhileDropping extends CustomClipper<Rect> {
  _WhileDropping(this.rect, this.drop) : super(reclip: drop);
  final Rect rect;
  final AnimationController drop;
  @override
  Rect getClip(Size size) => drop.isAnimating ? rect : Rect.largest;
  @override
  bool shouldReclip(_WhileDropping old) => old.rect != rect || old.drop != drop;
}

/* A 6 cm square of the cloth's photo, covering, turned by its quarter turns. Decoded to fit
   within the biggest square it is ever drawn, both sides bounded, and never past the stored photo's own size
   (ResizeImage does not enlarge): decoded once, so a zoom or a turn of the phone neither reads nor decodes it again. */
class _ClothSquare extends StatelessWidget {
  const _ClothSquare({required this.cloth, required this.turns, required this.cacheWidth});
  final ClothView cloth;
  final int turns, cacheWidth;

  @override
  Widget build(BuildContext context) {
    final image = cloth.image;
    if (image == null) return const ColoredBox(color: swatchBase);
    return RotatedBox(
      quarterTurns: turns,
      child: Image(image: ResizeImage(image, width: cacheWidth, height: cacheWidth, policy: ResizeImagePolicy.fit), fit: BoxFit.cover,
          excludeFromSemantics: true, gaplessPlayback: true,
          errorBuilder: (_, _, _) => const ColoredBox(color: swatchBase)),
    );
  }
}

