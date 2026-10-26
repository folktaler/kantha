import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:image/image.dart' as img;
import 'package:kantha_studio/downloads/caption.dart';
import 'package:kantha_studio/downloads/paper.dart';
import 'package:kantha_studio/downloads/sheet_pdf.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/studio/shelf_feed.dart';
import 'caption_test.dart' show zinnia;

final square = Uint8List.fromList(img.encodeJpg(img.Image(width: 600, height: 600)..clear(img.ColorRgb8(30, 120, 140))));
final footer = Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 40)));
final join = Uint8List.fromList(img.encodePng(img.Image(width: 900, height: 30)));

double mm(String pt) => double.parse(pt) * 25.4 / 72;

/* 4 cm in points: 4 / 2.54 × 72. */
const edge = 4 / 2.54 * 72;

typedef Box = ({double w, double h, double x, double y});

/* Each page of an uncompressed sheet, in order: its MediaBox, the pictures its content stream paints, and the filled
   rectangles (the seams, and the join's line, ticks and their white). A picture is painted by "w 0 0 h 0 0 cm /Ix Do"
   (its width and height in points), a filled rectangle by "0 0 w h re r g b rg f" (a clip, "re W n", is not one); each after its Positioned's "1 0 0 1 x y cm" (its
   lower-left corner, in points up from the page's lower left): the last move before it. */
List<({double w, double h, List<Box> placed, List<Box> rects})> pagesOf_(String pdf) {
  final boxes = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)').allMatches(pdf).toList();
  final streams = RegExp(r'stream\r?\n(.*?)endstream', dotAll: true).allMatches(pdf)
      .map((m) => m[1]!).where((s) => s.contains(' Do')).toList();
  expect(streams.length, boxes.length, reason: 'one content stream a page');
  return [
    for (var i = 0; i < boxes.length; i++)
      (w: double.parse(boxes[i][1]!), h: double.parse(boxes[i][2]!),
          placed: _painted(streams[i], r'([\d.]+) 0 0 ([\d.]+) ([-\d.]+) ([-\d.]+) cm\s*/I\w+ Do'),
          rects: _painted(streams[i], r'0 0 ([\d.]+) ([\d.]+) re\s+[\d.\s]+rg\s+f')),
  ];
}

/* What `paint` (its width and height captured, then for a picture its own offset, signed: "-0 0" is a real PDF's)
   paints in `stream`, each at the last move before it. A turned square's rotation is not a move: it stays at its own. */
List<Box> _painted(String stream, String paint) {
  final found = <Box>[];
  var (x, y) = (0.0, 0.0);
  for (final m in RegExp('1 0 0 1 ([-\\d.]+) ([-\\d.]+) cm|$paint').allMatches(stream)) {
    if (m[1] != null) {
      final (mx, my) = (double.parse(m[1]!), double.parse(m[2]!));
      if (mx != 0 || my != 0) (x, y) = (mx, my);
    } else {
      final (ox, oy) = m.groupCount >= 6 && m[5] != null ? (double.parse(m[5]!), double.parse(m[6]!)) : (0.0, 0.0);
      found.add((w: double.parse(m[3]!), h: double.parse(m[4]!), x: x + ox, y: y + oy));
    }
  }
  return found;
}

/* zinnia with its cloth turned: square i a quarter turn i times, so every turn is on both Letter pages. */
DesignView turned() {
  final z = zinnia();
  return DesignView(id: z.id, name: z.name, layout: z.layout, mount: z.mount, box: z.box, seed: z.seed, started: null,
      firstSolve: null, grid: z.grid, rot: [for (var i = 0; i < 35; i++) i % 4], saved: z.saved);
}

void main() {
  test('one A4 page, its squares exactly 40.0 mm', () async {
    final pdf = latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [footer], compress: false));
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(pdf).length, 1);
    final box = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)').firstMatch(pdf)!;
    expect(mm(box[1]!), closeTo(210, 0.05));
    expect(mm(box[2]!), closeTo(297, 0.05));
    // Each picture is painted by "w 0 0 h x y cm /Ix Do": its width and height in points.
    // The 35 squares of cloth, and the footer's line of words (a picture too, 300 px to the inch).
    final placed = RegExp(r'([\d.]+) 0 0 ([\d.]+) [-\d.]+ [-\d.]+ cm\s*/I\w+ Do').allMatches(pdf).toList();
    expect(placed.length, 36);
    final squares = placed.where((m) => (mm(m[1]!) - 40).abs() < 1).toList();
    expect(squares.length, 35);
    for (final m in squares) {
      expect(mm(m[1]!), closeTo(40.0, 0.05));
      expect(mm(m[2]!), closeTo(40.0, 0.05));
    }
    final words = placed.firstWhere((m) => !squares.contains(m));
    expect(double.parse(words[1]!), closeTo(400 * 72 / 300, 0.01), reason: 'the footer at 300 px to the inch');
    expect(double.parse(words[2]!), closeTo(40 * 72 / 300, 0.01));
  });

  test('a design whose cloth has gone still makes its sheet, those squares plain', () async {
    final pdf = await sheetPdf(zinnia(), {'KF-1': null}, [footer], compress: false);
    expect(pdf.length, greaterThan(1000));
    expect(RegExp(r'/I\w+ Do').allMatches(latin1.decode(pdf)).length, 1, reason: 'only the footer is an image');
  });

  /* Both papers: the page is the paper's size, and every square is 4 cm (113.39 pt) within 0.01 pt, on every page, the
     squares touching edge to edge. */
  // `clear`: the least room, in cm, between the grid and the paper's edge — A4's 0.5 cm sides as they always were; on
  // Letter at least 0.6 cm, past the 0.4–0.6 cm most printers leave unprinted.
  for (final (paper, w, h, rows, clearCm) in [(Paper.a4, 595.28, 841.89, [7], 0.5), (Paper.letter, 612.0, 792.0, [4, 3], 0.6)]) {
    for (final (design, how) in [(zinnia, 'cloth as cut'), (turned, 'cloth turned every way')]) {
    test('${paper.name}, $how: ${rows.length} page(s) of ${w.toStringAsFixed(2)} × ${h.toStringAsFixed(2)} pt, '
        'every square 4 cm within 0.01 pt, edge to edge', () async {
      final pdf = latin1.decode(await sheetPdf(design(), {'KF-1': square}, [for (final _ in rows) footer],
          paper: paper, join: join, compress: false));
      final pages = pagesOf_(pdf);
      expect(pages.length, rows.length);
      for (final (i, p) in pages.indexed) {
        expect(p.w, closeTo(w, 0.01), reason: 'page ${i + 1} wide');
        expect(p.h, closeTo(h, 0.01), reason: 'page ${i + 1} tall');
        final squares = p.placed.where((s) => (s.w - edge).abs() < 1).toList();
        expect(squares.length, rows[i] * 5, reason: 'page ${i + 1}: ${rows[i]} rows of 5');
        for (final s in squares) {
          expect(s.w, closeTo(edge, 0.01));
          expect(s.h, closeTo(edge, 0.01));
        }
        // Edge to edge: 5 columns and the page's rows, each one square's edge from the next.
        final xs = squares.map((s) => s.x).toSet().toList()..sort(), ys = squares.map((s) => s.y).toSet().toList()..sort();
        expect(xs.length, 5);
        expect(ys.length, rows[i]);
        for (var k = 1; k < xs.length; k++) {
          expect(xs[k] - xs[k - 1], closeTo(edge, 0.01));
        }
        for (var k = 1; k < ys.length; k++) {
          expect(ys[k] - ys[k - 1], closeTo(edge, 0.01));
        }
        final clear = clearCm / 2.54 * 72 - 0.01;
        expect(xs.first, greaterThanOrEqualTo(clear));
        expect(w - (xs.last + edge), greaterThanOrEqualTo(clear));
        expect(ys.first, greaterThanOrEqualTo(clear));
        expect(h - (ys.last + edge), greaterThanOrEqualTo(clear));
        // The footer on every page; the join's words only on a page after the first.
        final others = p.placed.where((s) => (s.w - edge).abs() >= 1).toList();
        expect(others.map((s) => s.w.toStringAsFixed(2)),
            [if (i > 0) (900 * 72 / 300).toStringAsFixed(2), (400 * 72 / 300).toStringAsFixed(2)]..sort(),
            reason: 'page ${i + 1}');
      }
    });
    }
  }

  test('Letter: the join words sit 4 mm above page 2’s top line', () async {
    final pages = pagesOf_(latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [footer, footer],
        paper: Paper.letter, join: join, compress: false)));
    final second = pages[1].placed, squares = second.where((s) => (s.w - edge).abs() < 1);
    final top = squares.map((s) => s.y + edge).reduce((a, b) => a > b ? a : b); // PDF y runs up the page
    final words = second.firstWhere((s) => (s.w - 900 * 72 / 300).abs() < 0.01);
    expect(words.y, closeTo(top + 4 * 72 / 25.4, 0.01), reason: '4 mm above the line');
  });

  /* The join's marks, each in ink over white: a line along the edge where the pages meet, and a tick at every column
     line on the side that stays in sight once page 2 is cut along its top line and laid over page 1's bottom margin. */
  test('Letter: where the pages meet, a solid line along the edge, 1 mm past the grid, and a 4 mm tick at every column '
      'line on the side that stays in sight: above the line on page 1, below it on page 2; each with a white edge; '
      'A4 has none', () async {
    const mm = 72 / 25.4, mark = 0.3 * mm, halo = 0.25 * mm, tick = 4 * mm;
    final pages = pagesOf_(latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [footer, footer],
        paper: Paper.letter, join: join, compress: false)));
    bool near(double a, double b) => (a - b).abs() < 0.01;
    for (final (i, p) in pages.indexed) {
      final squares = p.placed.where((s) => (s.w - edge).abs() < 1).toList();
      final left = squares.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      // PDF y runs up the page: page 1 meets page 2 along its grid's bottom, page 2 meets page 1 along its top.
      final y = i == 0 ? squares.map((s) => s.y).reduce((a, b) => a < b ? a : b)
          : squares.map((s) => s.y + edge).reduce((a, b) => a > b ? a : b);
      for (final (white, e) in [(false, 0.0), (true, halo)]) {
        final what = white ? 'white' : 'ink';
        final line = p.rects.where((r) => near(r.h, mark + 2 * e)).toList();
        expect(line, hasLength(1), reason: 'page ${i + 1}: one join line ($what)');
        expect(line.single.w, closeTo(20 / 2.54 * 72 + 2 * mm + 2 * e, 0.01), reason: 'the grid and 1 mm past each side');
        expect(line.single.x, closeTo(left - mm - e, 0.01));
        expect(line.single.y + line.single.h / 2, closeTo(y, 0.01), reason: 'centred on the edge');
        final ticks = p.rects.where((r) => near(r.w, mark + 2 * e) && near(r.h, tick + 2 * e)).toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        expect(ticks, hasLength(6), reason: 'page ${i + 1}: one at each of the 6 column lines ($what)');
        for (final (c, t) in ticks.indexed) {
          expect(t.x + t.w / 2, closeTo(left + c * edge, 0.01), reason: 'on column line $c');
          // Page 1: from the line up into the grid. Page 2: from the line down into the grid.
          expect(i == 0 ? t.y + e : t.y + t.h - e, closeTo(y, 0.01), reason: 'page ${i + 1}, on the kept side');
        }
      }
    }
    final a4 = pagesOf_(latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [footer], compress: false)));
    expect(a4.single.rects.where((r) => [mark, mark + 2 * halo].any((m) => near(r.w, m) || near(r.h, m))), isEmpty,
        reason: 'no marks, and no white edges');
  });

  for (final (design, how) in [(zinnia, 'cloth as cut'), (turned, 'cloth turned every way')]) {
  test('Letter, $how: everything on both pages, the marks and their white included, is at least 6.35 mm (¼ in) from '
      'every edge of the paper, where printers print', () async {
    const clear = 6.35 * 72 / 25.4;
    final pages = pagesOf_(latin1.decode(await sheetPdf(design(), {'KF-1': square}, [footer, footer],
        paper: Paper.letter, join: join, compress: false)));
    expect(pages.map((p) => p.placed.where((s) => (s.w - edge).abs() < 1).length), [20, 15], reason: 'every square found');
    for (final (i, p) in pages.indexed) {
      for (final b in [...p.rects, ...p.placed]) {
        final where = 'page ${i + 1}: $b';
        expect(b.x, greaterThanOrEqualTo(clear), reason: where);
        expect(b.y, greaterThanOrEqualTo(clear), reason: where);
        expect(p.w - (b.x + b.w), greaterThanOrEqualTo(clear), reason: where);
        expect(p.h - (b.y + b.h), greaterThanOrEqualTo(clear), reason: where);
      }
    }
  });
  }

  test('a sheet is refused without one footer a page, or a Letter sheet without its join words', () async {
    await expectLater(sheetPdf(zinnia(), {'KF-1': square}, [footer], paper: Paper.letter, join: join),
        throwsA(isA<ArgumentError>()));
    await expectLater(sheetPdf(zinnia(), {'KF-1': square}, [footer, footer]), throwsA(isA<ArgumentError>()));
    await expectLater(sheetPdf(zinnia(), {'KF-1': square}, [footer, footer], paper: Paper.letter),
        throwsA(isA<ArgumentError>()));
  });

  test("each page's footer: the footer alone on A4; on Letter, which page it is, first", () {
    final l = lookupL(const Locale('en'));
    expect(footersFor(l, zinnia(), Paper.a4), ['Zinnia · made with kantha.app']);
    expect(footersFor(l, zinnia(), Paper.letter),
        ['Page 1 of 2 · Zinnia · made with kantha.app', 'Page 2 of 2 · Zinnia · made with kantha.app']);
  });
}
