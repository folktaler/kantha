import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../solver/geometry.dart';
import '../studio/shelf_feed.dart';
import 'paper.dart';

/* The laying sheet at true size: the 5 × 7 grid of 4 cm squares of cloth, the seam grid over them, and the footer —
   drawn by Flutter at 300 px to the inch and placed here as a picture, so Malayalam needs no PDF text shaping.
   On A4 it is one page, the grid inside geometry's margins. On Letter (28 cm of panel on 27.94 cm of paper) it is two:
   rows 1–4, then rows 5–7 with `join` (its words to cut and lay it on page 1) just above its top line; each grid is
   centred on its page. Where two pages meet, each draws the join: a solid line along that edge of its grid, and a
   tick at every column line on the side of it that stays in sight once page 2 is cut along its top line and laid
   over page 1's bottom margin: above the line on page 1, below it on page 2. Laid, each column's two ticks meet end
   to end across the join. Every mark has a white edge, so it shows over dark cloth, and stays at least 6.35 mm
   (¼ in) from the paper's edges, inside what printers print. The squares stay 4 cm: the marks are drawn over them.
   `footers` holds each page's footer, in page order. `photos` holds each cloth's JPEG by id; a cloth with none is
   drawn plain. */
Future<Uint8List> sheetPdf(DesignView d, Map<String, Uint8List?> photos, List<Uint8List> footers,
    {Paper paper = Paper.a4, Uint8List? join, bool compress = true}) async {
  const cm = PdfPageFormat.cm, mm = PdfPageFormat.mm, size = patchCm * cm, seam = 0.2 * mm;
  // The join's marks: 0.3 mm of #1E2027, solid, on 0.25 mm of white each side; the line runs 1 mm past the grid each
  // side (on Letter its white ends 6.7 mm from the paper's edge), the ticks 4 mm into the grid.
  const mark = 0.3 * mm, halo = 0.25 * mm, past = 1 * mm, tick = 4 * mm;
  const ink = PdfColor.fromInt(0xFF1E2027), white = PdfColor.fromInt(0xFFFFFFFF);
  final format = switch (paper) { Paper.a4 => PdfPageFormat.a4, Paper.letter => PdfPageFormat.letter };
  final pages = pagesOf(paper);
  if (footers.length != pages.length) {
    throw ArgumentError.value(footers.length, 'footers', 'one a page: ${pages.length} on ${paper.name}');
  }
  if (pages.length > 1 && join == null) throw ArgumentError.notNull('join');
  final images = {for (final e in photos.entries) if (e.value != null) e.key: pw.MemoryImage(e.value!)};
  // A picture drawn at 300 px to the inch, at that size: the words are the 7 pt they were drawn at.
  ({pw.MemoryImage image, double w, double h}) words(Uint8List png) {
    final image = pw.MemoryImage(png);
    return (image: image, w: image.width! * 72 / 300, h: image.height! * 72 / 300);
  }
  final joinWords = join == null ? null : words(join);
  final doc = pw.Document(compress: compress);
  for (final (p, rows) in pages.indexed) {
    final footer = words(footers[p]);
    final bw = a4.bw * cm, bh = (rows.to - rows.from) * size;
    final left = (format.width - bw) / 2, top = (format.height - bh) / 2, bottom = top + bh;
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: [
        for (var i = rows.from * a4.cols; i < rows.to * a4.cols; i++)
          pw.Positioned(
            left: left + (i % a4.cols) * size,
            top: top + (i ~/ a4.cols - rows.from) * size,
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
            pw.Positioned(left: left + c * size - seam / 2, top: top - seam / 2,
                child: pw.Container(width: seam, height: bh + seam, color: PdfColor.fromInt(0xFF1E2027))),
          for (var r = 0; r <= rows.to - rows.from; r++)
            pw.Positioned(left: left - seam / 2, top: top + r * size - seam / 2,
                child: pw.Container(width: bw + seam, height: seam, color: PdfColor.fromInt(0xFF1E2027))),
        ])),
        // The join: along the bottom of a page with one after it, ticks above; along the top of a page with one before
        // it, ticks below. All the white first, then the ink, so no white is over a mark.
        for (final edge in [halo, 0.0])
          for (final (y, down) in [if (p > 0) (top, true), if (p < pages.length - 1) (bottom, false)]) ...[
            pw.Positioned(left: left - past - edge, top: y - mark / 2 - edge,
                child: pw.Container(width: bw + 2 * past + 2 * edge, height: mark + 2 * edge, color: edge > 0 ? white : ink)),
            for (var c = 0; c <= a4.cols; c++)
              pw.Positioned(left: left + c * size - mark / 2 - edge, top: (down ? y : y - tick) - edge,
                  child: pw.Container(width: mark + 2 * edge, height: tick + 2 * edge, color: edge > 0 ? white : ink)),
          ],
        // On a page after the first, the words to cut it at its top line and lay it on the page before: 4 mm above
        // that line (clear of the ticks), centred.
        if (p > 0 && joinWords != null)
          pw.Positioned(left: (format.width - joinWords.w) / 2, top: top - 4 * mm - joinWords.h,
              child: pw.Image(joinWords.image, width: joinWords.w, height: joinWords.h)),
        // The footer, centred in the bottom margin.
        pw.Positioned(left: (format.width - footer.w) / 2, top: bottom + (format.height - bottom - footer.h) / 2,
            child: pw.Image(footer.image, width: footer.w, height: footer.h)),
      ]),
    ));
  }
  return doc.save();
}
