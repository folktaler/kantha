/* The tote under the sheet, the tote's edge and the frame over it: what the panel is set into, drawn
   around the A4 sheet at the board's scale. Each is a Positioned child of the board's
   Stack, whose origin is the sheet's top-left corner. */
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../solver/geometry.dart';
import 'painters.dart';

/* The mounts' own colours: they are the thing she makes, not the studio's chrome. */
const _mountCard = Color(0xFFFBFAF6), _mountBevel = Color(0xFFE9DFC8);
const _canvasCloth = Color(0xFFDED2B8), _toteHem = Color(0xFFD6C8AC), _toteTopstitch = Color(0xFFA8987A);

/* The tote bag under the panel: canvas cloth with a faint weave, its hem across the top. */
class ToteUnder extends StatelessWidget {
  const ToteUnder({super.key, required this.ppc});
  final double ppc;

  @override
  Widget build(BuildContext context) {
    final tw = tote.w * ppc, th = tote.h * ppc;
    final radius = BorderRadius.only(topLeft: Radius.circular(ppc * 0.25), topRight: Radius.circular(ppc * 0.25),
        bottomRight: Radius.circular(ppc * 0.5), bottomLeft: Radius.circular(ppc * 0.5));
    final a = math.max(1.4, ppc * 0.05), b = math.max(2.8, ppc * 0.1);
    return Positioned(
      left: a4.mx * ppc + (a4.bw * ppc) / 2 - tw / 2, top: a4.my * ppc - tote.top * ppc, width: tw, height: th,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(color: _canvasCloth, borderRadius: radius, boxShadow: const [
            BoxShadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0x141E2027)),
            BoxShadow(offset: Offset(0, 16), blurRadius: 36, color: Color(0x1A1E2027)),
          ]),
          // repeating-linear-gradient(90deg, #00000008 0, transparent a, transparent b), and the 1px inset edge.
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: const Color(0x14000000)),
                gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment(-1 + 2 * b / tw, 0),
                    colors: const [Color(0x08000000), Color(0x00000000), Color(0x00000000)], stops: [0, a / b, 1],
                    tileMode: TileMode.repeated)),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(left: 0, right: 0, top: 0, height: hem * ppc, child: const _Hem()),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Hem extends StatelessWidget {
  const _Hem();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: _toteHem,
            border: Border(top: BorderSide(color: Color(0x33FFFFFF)))), // inset 0 1px 0 #FFFFFF33
        child: CustomPaint(painter: DashedRectPainter(color: _toteTopstitch, sides: const {2})),
      );
}

/* The tote's stitched edge round the panel, 0.6 cm out, in the thread's colour. */
class ToteEdge extends StatelessWidget {
  const ToteEdge({super.key, required this.ppc, required this.hex});
  final double ppc;
  final String hex;

  @override
  Widget build(BuildContext context) {
    final off = 0.6 * ppc;
    return Positioned(
      left: a4.mx * ppc - off, top: a4.my * ppc - off, width: a4.bw * ppc + off * 2, height: a4.bh * ppc + off * 2,
      child: IgnorePointer(child: CustomPaint(painter: DashedRectPainter(color: hexColor(hex, 0xCC / 0xFF)))),
    );
  }
}

/* A pine frame over the sheet: four mitred strips of moulding with their grain, and the
   mount card with its opening and bevel. */
class FrameOver extends StatelessWidget {
  const FrameOver({super.key, required this.ppc});
  final double ppc;

  @override
  Widget build(BuildContext context) => Positioned(
        left: (sheetW - frame.outer.$1) / 2 * ppc, top: (sheetH - frame.outer.$2) / 2 * ppc,
        width: frame.outer.$1 * ppc, height: frame.outer.$2 * ppc,
        child: IgnorePointer(child: CustomPaint(key: const ValueKey('frame'), painter: _FramePainter(ppc))),
      );
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.ppc);
  final double ppc;

  static const _pale = (base: Color(0xFFE3C193), pale: Color(0xFFEFD8B2), dark: Color(0xFFC99F6B));
  static const _shade = (base: Color(0xFFD2AC7C), pale: Color(0xFFE0C29A), dark: Color(0xFFB88C5A));

  /* The moulding's grain: repeating-linear-gradient(pale 0, base .42g, dark .62g, base .82g, pale g).
     (The CSS lays a second, darker streak gradient under it; the first is opaque, so it never shows.) */
  Paint _grain(Offset from, Offset along, ({Color base, Color pale, Color dark}) c, double g) => Paint()
    ..shader = ui.Gradient.linear(from, from + along * g, [c.pale, c.base, c.dark, c.base, c.pale],
        const [0, 0.42, 0.62, 0.82, 1], TileMode.repeated);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = frame.moulding * ppc, g = math.max(2.6, m * 0.34);
    final outer = Offset.zero & size;

    // box-shadow 0 3px 8px, 0 22px 48px #1e20271f — outside the frame only.
    canvas.save();
    canvas.clipRect(outer, clipOp: ui.ClipOp.difference);
    for (final (dy, blur) in [(3.0, 8.0), (22.0, 48.0)]) {
      canvas.drawRect(outer.shift(Offset(0, dy)),
          Paint()..color = const Color(0x1F1E2027)..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2));
    }
    canvas.restore();

    final top = Path()..addPolygon([Offset.zero, Offset(w, 0), Offset(w - m, m), Offset(m, m)], true);
    final bottom = Path()..addPolygon([Offset(m, h - m), Offset(w - m, h - m), Offset(w, h), Offset(0, h)], true);
    final left = Path()..addPolygon([Offset.zero, Offset(m, m), Offset(m, h - m), Offset(0, h)], true);
    final right = Path()..addPolygon([Offset(w, 0), Offset(w, h), Offset(w - m, h - m), Offset(w - m, m)], true);
    canvas.drawPath(top, _grain(Offset.zero, const Offset(0, 1), _pale, g));
    canvas.drawPath(bottom, _grain(Offset(0, h - m), const Offset(0, 1), _shade, g));
    canvas.drawPath(left, _grain(Offset.zero, const Offset(1, 0), _pale, g));
    canvas.drawPath(right, _grain(Offset(w - m, 0), const Offset(1, 0), _shade, g));

    // The mount card: the frame's opening, less the aperture the panel shows through.
    final side = (frame.opening.$1 - frame.aperture.$1) / 2 * ppc, end = (frame.opening.$2 - frame.aperture.$2) / 2 * ppc;
    final card = Rect.fromLTWH(m, m, frame.opening.$1 * ppc, frame.opening.$2 * ppc);
    final hole = Rect.fromLTRB(card.left + side, card.top + end, card.right - side, card.bottom - end);
    canvas.drawRect(card.inflate(0.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0x0F000000));
    canvas.drawPath(Path()..fillType = PathFillType.evenOdd..addRect(card)..addRect(hole), Paint()..color = _mountCard);

    // Inside the aperture, under to over: the bevel, a soft shadow from the top edge, a hairline.
    final bevel = math.max(1.0, ppc * 0.06);
    canvas.save();
    canvas.clipRect(hole);
    canvas.drawRect(hole.deflate(bevel / 2), Paint()..style = PaintingStyle.stroke..strokeWidth = bevel..color = _mountBevel);
    canvas.drawPath(Path()..fillType = PathFillType.evenOdd..addRect(hole.inflate(10))..addRect(hole.shift(const Offset(0, 1))),
        Paint()..color = const Color(0x10000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    canvas.drawRect(hole.deflate(0.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0x12000000));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.ppc != ppc;
}
