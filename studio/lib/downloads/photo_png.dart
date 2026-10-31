import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../cloth/parts.dart' show paintedFirst;
import '../solver/geometry.dart';
import '../studio/shelf_feed.dart';
import '../theme.dart' show kFallbackFonts;

/* The picture to share: 6 × 7.5 in at 180 ppi, so
   1080 × 1350 px and 1 pt = 2.5 px. The design in its cloth on its mount, scaled to
   the room above the caption, then the caption's four lines. `photos` holds each
   cloth's picture by id; a cloth with none is drawn plain. */
const _ppi = 180.0, _pt = _ppi / 72, _inch = _ppi;
const photoWidth = 1080, photoHeight = 1350;

// The page (37): its ground, and its margins.
const _ground = Color(0xFFEFEBDD);
const _left = 0.55 * _inch, _top = 0.5 * _inch, _bottom = 0.45 * _inch;
// The gutter between the drawing and the caption (62).
const _gutter = 0.3 * _inch;
// Typst's text sits between the font's cap height and its baseline; Public Sans's cap
// height is 1446 of its 2000 units (OS/2 sCapHeight). The caption's leading and spacing (68)
// are in each line's own em: 0.5 em between a paragraph's rows, and 0.55 em between two
// paragraphs, the larger of the two (measured against Typst's own output, 7 Oct).
const _capHeight = 1446 / 2000, _leading = 0.5, _spacing = 0.55;

// The cloth's base and its seams.
const _base = Color(0xFFEAE5D5), _seam = Color(0x551E2027);
// The caption's face and inks: Public Sans, as the sheet sets it, whatever face the studio's screens use.
const _font = 'Public Sans';
const _ink = Color(0xFF1E2027), _ink2 = Color(0xFF545963), _ink3 = Color(0xFF666A75);

/* The photo, and, with `thumb`, the small copy of it My designs shows (thumbWidth × thumbHeight), drawn from the photo's
   image as it is drawn here: its PNG is never decoded again. Without `thumb` (Save photo, Share) no small copy is made. */
Future<({Uint8List png, Uint8List? thumb})> photoPng(DesignView d, Map<String, ui.Image?> photos, List<String> caption,
    {bool thumb = false}) async {
  final recorder = ui.PictureRecorder();
  paintPhoto(Canvas(recorder), d, photos, caption);
  final picture = recorder.endRecording();
  final image = await picture.toImage(photoWidth, photoHeight);
  picture.dispose();
  try {
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    if (!thumb) return (png: png, thumb: null);
    // A frame drawn and painted between the two encodes, so the page is not held still for both at once.
    await paintedFirst();
    return (png: png, thumb: await _thumb(image));
  } finally {
    image.dispose();
  }
}

/* The small copy: 160 × 200, a 4:5 like the photo, enough for its 38 × 48 row at up to 4 device pixels a point. */
const thumbWidth = 160, thumbHeight = 200;

Future<Uint8List> _thumb(ui.Image photo) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(photo, Rect.fromLTWH(0, 0, photoWidth.toDouble(), photoHeight.toDouble()),
      Rect.fromLTWH(0, 0, thumbWidth.toDouble(), thumbHeight.toDouble()), Paint()..filterQuality = FilterQuality.medium);
  final picture = recorder.endRecording();
  final image = await picture.toImage(thumbWidth, thumbHeight);
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void paintPhoto(Canvas canvas, DesignView d, Map<String, ui.Image?> photos, List<String> caption) {
  canvas.drawRect(Rect.fromLTWH(0, 0, photoWidth.toDouble(), photoHeight.toDouble()), Paint()..color = _ground);
  final content = Rect.fromLTRB(_left, _top, photoWidth - _left, photoHeight - _bottom);

  // The caption, centred, each line in its own size, weight and ink.
  final lines = [
    for (final (i, words) in caption.indexed)
      _line(words, size: [19.0, 10.5, 10.5, 9.0][math.min(i, 3)] * _pt, bold: i == 0,
          colour: [_ink, _ink2, _ink2, _ink3][math.min(i, 3)],
          width: content.width),
  ];
  double heightOf(_Line l) => l.rows * l.cap + (l.rows - 1) * _leading * l.size;
  double gapAfter(int i) => i + 1 < lines.length ? _spacing * math.max(lines[i].size, lines[i + 1].size) : 0;
  var captionHeight = 0.0;
  for (var i = 0; i < lines.length; i++) {
    captionHeight += heightOf(lines[i]) + gapAfter(i);
  }

  // The drawing: its footprint in cm, scaled to fit the room it has, centred there.
  final room = Rect.fromLTWH(content.left, content.top, content.width, content.height - _gutter - captionHeight);
  final foot = switch (d.mount) {
    Mount.frame => (frame.outer.$1, frame.outer.$2),
    Mount.tote => (tote.w, tote.h),
    Mount.none => (sheetFor(d.size).bw, sheetFor(d.size).bh),
  };
  final u = math.min(room.width / foot.$1, room.height / foot.$2);
  final at = Offset(room.center.dx - foot.$1 * u / 2, room.center.dy - foot.$2 * u / 2);
  _drawing(canvas, at, u, d, photos);

  var y = room.bottom + _gutter;
  for (final (i, l) in lines.indexed) {
    // The first row's cap height stands at y; its baseline below that.
    final baseline = l.painter.computeLineMetrics().first.baseline;
    l.painter.paint(canvas, Offset(content.left, y + l.cap - baseline));
    y += heightOf(l) + gapAfter(i);
    l.painter.dispose();
  }
}

class _Line {
  _Line(this.painter, this.size, this.rows) : cap = _capHeight * size;
  final TextPainter painter;
  final double size, cap;
  final int rows;
}

/* One caption paragraph, its rows a cap height plus the leading apart, as Typst sets them. */
_Line _line(String words, {required double size, required bool bold, required Color colour, required double width}) {
  final painter = TextPainter(
    text: TextSpan(text: words, style: TextStyle(fontFamily: _font, fontFamilyFallback: kFallbackFonts, fontSize: size,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: colour, height: _capHeight + _leading)),
    textAlign: TextAlign.center, textDirection: TextDirection.ltr,
  )..layout(minWidth: width, maxWidth: width);
  return _Line(painter, size, painter.computeLineMetrics().length);
}

/* The panel on its mount, its top left at `at`, `u` px to the cm. */
void _drawing(Canvas canvas, Offset at, double u, DesignView d, Map<String, ui.Image?> photos) {
  final panel = Size(a4.bw * u, a4.bh * u);
  switch (d.mount) {
    case Mount.none:
      _patchwork(canvas, at, u, d, photos);
    case Mount.frame:
      final outer = at & Size(frame.outer.$1 * u, frame.outer.$2 * u);
      canvas.drawRect(outer, Paint()..color = const Color(0xFFD2AC7C));
      final opening = Rect.fromCenter(center: outer.center, width: frame.opening.$1 * u, height: frame.opening.$2 * u);
      canvas.drawRect(opening, Paint()..color = const Color(0xFFFBFAF6));
      final aperture = Rect.fromCenter(center: opening.center, width: frame.aperture.$1 * u, height: frame.aperture.$2 * u);
      canvas.drawRect(aperture, Paint()..color = const Color(0xFFFCFCFA));
      canvas.drawRect(aperture, _stroke(0.06 * u, const Color(0xFFE9DFC8)));
      _patchwork(canvas, aperture.center - Offset(panel.width / 2, panel.height / 2), u, d, photos);
      canvas.drawRect(outer, _stroke(0.5 * _pt, const Color(0xFFB88C5A)));
    case Mount.tote:
      final bag = at & Size(tote.w * u, tote.h * u);
      final shape = RRect.fromRectAndCorners(bag, topLeft: Radius.circular(0.25 * u), topRight: Radius.circular(0.25 * u),
          bottomLeft: Radius.circular(0.5 * u), bottomRight: Radius.circular(0.5 * u));
      canvas.save();
      canvas.clipRRect(shape);
      canvas.drawRect(bag, Paint()..color = const Color(0xFFDED2B8));
      final hemBand = Rect.fromLTWH(bag.left, bag.top, bag.width, hem * u);
      canvas.drawRect(hemBand, Paint()..color = const Color(0xFFD6C8AC));
      _dashed(canvas, hemBand.bottomLeft, hemBand.bottomRight, const Color(0xFFA8987A));
      final off = 0.6 * u;
      final panelAt = Offset(bag.center.dx - panel.width / 2, bag.top + tote.top * u);
      _patchwork(canvas, panelAt, u, d, photos);
      final edge = (panelAt & panel).inflate(off);
      _dashed(canvas, edge.topLeft, edge.topRight, const Color(0xFF8C7B5C));
      _dashed(canvas, edge.topRight, edge.bottomRight, const Color(0xFF8C7B5C));
      _dashed(canvas, edge.bottomRight, edge.bottomLeft, const Color(0xFF8C7B5C));
      _dashed(canvas, edge.bottomLeft, edge.topLeft, const Color(0xFF8C7B5C));
      canvas.restore();
  }
}

Paint _stroke(double width, Color colour) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..color = colour;

/* Typst's "dashed" at 0.5 pt: 3 pt dashes, 3 pt apart (measured on its output). */
void _dashed(Canvas canvas, Offset from, Offset to, Color colour) {
  const width = 0.5 * _pt, dash = 3 * _pt;
  final paint = _stroke(width, colour);
  final length = (to - from).distance, along = (to - from) / length;
  for (var s = 0.0; s < length; s += 2 * dash) {
    canvas.drawLine(from + along * s, from + along * math.min(s + dash, length), paint);
  }
}

/* The board's grid (5 × 7 on Level 1): each square the cloth's photo covering it, turned as she turned
   it, then the seams over them — 0.2 mm lines on every square's edges. */
void _patchwork(Canvas canvas, Offset at, double u, DesignView d, Map<String, ui.Image?> photos) {
  final s = patchCm * u, g = d.size;
  final paint = Paint()..filterQuality = FilterQuality.medium;
  for (var i = 0; i < d.grid.length && i < g.rows * g.cols; i++) {
    final cell = Rect.fromLTWH(at.dx + (i % g.cols) * s, at.dy + (i ~/ g.cols) * s, s, s);
    canvas.drawRect(cell, Paint()..color = _base);
    final photo = photos[d.grid[i]];
    if (photo == null) continue;
    final side = math.min(photo.width, photo.height).toDouble();
    final src = Rect.fromCenter(center: Offset(photo.width / 2, photo.height / 2), width: side, height: side);
    canvas.save();
    canvas.clipRect(cell);
    canvas.translate(cell.center.dx, cell.center.dy);
    canvas.rotate((i < d.rot.length ? d.rot[i] : 0) * math.pi / 2);
    canvas.drawImageRect(photo, src, Rect.fromCenter(center: Offset.zero, width: s, height: s), paint);
    canvas.restore();
  }
  final seam = _stroke(0.02 * u, _seam);
  for (var c = 0; c <= g.cols; c++) {
    canvas.drawLine(at + Offset(c * s, 0), at + Offset(c * s, g.rows * s), seam);
  }
  for (var r = 0; r <= g.rows; r++) {
    canvas.drawLine(at + Offset(0, r * s), at + Offset(g.cols * s, r * s), seam);
  }
}
