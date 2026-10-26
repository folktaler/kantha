import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../solver/geometry.dart';
import '../theme.dart' show kFallbackFonts;

/* The sheet's footer line (7 pt, ink3, centred), drawn by Flutter at
   300 px to the inch on a clear ground, as a PNG the PDF places at that size — so a
   Malayalam name is shaped by Flutter's text, not by the PDF. */
const footerPpi = 300.0;

/* The line is never wider than the grid above it (20 cm): a long name is set smaller, down
   to 5 pt, and past that it is cut short with an ellipsis. */
final double footerMaxWidth = a4.bw / 2.54 * footerPpi;
const _pt = footerPpi / 72, _size = 7 * _pt, _smallest = 5 * _pt;
// Public Sans in ink3, as the sheet sets it, whatever face the studio's screens use.
const _font = 'Public Sans', _ink3 = Color(0xFF666A75);

Future<Uint8List> footerPng(String text) async {
  TextPainter set(double size) => TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontFamily: _font, fontFamilyFallback: kFallbackFonts,
            fontSize: size, color: _ink3)),
        textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…',
      )..layout(maxWidth: footerMaxWidth);
  var painter = set(_size);
  if (painter.didExceedMaxLines) {
    final whole = TextPainter(text: painter.text, textDirection: TextDirection.ltr, maxLines: 1)..layout();
    final natural = whole.width;
    whole.dispose();
    painter.dispose();
    painter = set((_size * footerMaxWidth / natural).clamp(_smallest, _size));
  }
  final w = painter.width.ceil().clamp(1, footerMaxWidth.ceil()), h = painter.height.ceil().clamp(1, 1 << 14);
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset.zero);
  painter.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
