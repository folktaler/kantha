import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../solver/geometry.dart';
import '../studio/shelf_feed.dart';

/* The laying sheet: one A4 page at true size, the
   5 × 7 grid of 4 cm squares of cloth inside geometry's margins, the seam grid over
   them, and the footer — drawn by Flutter at 300 px to the inch and placed here as
   a picture, so Malayalam needs no PDF text shaping. Nothing else is on the page.
   `photos` holds each cloth's JPEG by id; a cloth with none is drawn plain. */
Future<Uint8List> sheetPdf(DesignView d, Map<String, Uint8List?> photos, Uint8List footer, {bool compress = true}) async {
  const cm = PdfPageFormat.cm, mm = PdfPageFormat.mm, size = patchCm * cm, seam = 0.2 * mm;
  final images = {for (final e in photos.entries) if (e.value != null) e.key: pw.MemoryImage(e.value!)};
  final words = pw.MemoryImage(footer);
  // The footer's picture at 300 px to the inch, so its words are the 7 pt they were drawn at.
  final wordsW = words.width! * 72 / 300, wordsH = words.height! * 72 / 300;
  final bottom = a4.my + a4.bh;
  final doc = pw.Document(compress: compress);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(children: [
      for (var i = 0; i < d.grid.length; i++)
        pw.Positioned(
          left: (a4.mx + (i % a4.cols) * patchCm) * cm,
          top: (a4.my + (i ~/ a4.cols) * patchCm) * cm,
          child: pw.SizedBox(width: size, height: size, child: switch (images[d.grid[i]]) {
            null => pw.Container(color: PdfColor.fromInt(0xFFEAE5D5)),
            // rotateBox turns counter-clockwise for a positive angle; her turns are clockwise.
            final photo => pw.ClipRect(child: pw.Transform.rotateBox(angle: -d.rot[i] * math.pi / 2,
                child: pw.Image(photo, width: size, height: size, fit: pw.BoxFit.cover))),
          }),
        ),
      // The seams: 0.2 mm of #1E2027 at 0x55, each centred on a square's edge.
      pw.Opacity(opacity: 0x55 / 255, child: pw.Stack(children: [
        for (var c = 0; c <= a4.cols; c++)
          pw.Positioned(left: (a4.mx + c * patchCm) * cm - seam / 2, top: a4.my * cm - seam / 2,
              child: pw.Container(width: seam, height: a4.bh * cm + seam, color: PdfColor.fromInt(0xFF1E2027))),
        for (var r = 0; r <= a4.rows; r++)
          pw.Positioned(left: a4.mx * cm - seam / 2, top: (a4.my + r * patchCm) * cm - seam / 2,
              child: pw.Container(width: a4.bw * cm + seam, height: seam, color: PdfColor.fromInt(0xFF1E2027))),
      ])),
      // The footer, centred in the bottom margin.
      pw.Positioned(left: (sheetW * cm - wordsW) / 2, top: bottom * cm + ((sheetH - bottom) * cm - wordsH) / 2,
          child: pw.Image(words, width: wordsW, height: wordsH)),
    ]),
  ));
  return doc.save();
}
