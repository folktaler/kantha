import 'dart:convert';
import 'dart:math' as math;
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
/* A photo half as wide again as it is tall: cover fills the square with it, 6 cm by 4 cm, its sides cut off. */
final wide = Uint8List.fromList(img.encodeJpg(img.Image(width: 900, height: 600)..clear(img.ColorRgb8(140, 30, 60))));
final join = Uint8List.fromList(img.encodePng(img.Image(width: 900, height: 30)));

double mm(String pt) => double.parse(pt) * 25.4 / 72;

/* 4 cm in points: 4 / 2.54 × 72. */
const edge = 4 / 2.54 * 72;

typedef Box = ({double w, double h, double x, double y});

/* A transform matrix [a b c d e f], as PDF writes it: a point (x, y) goes to (a x + c y + e, b x + d y + f). */
typedef Matrix = List<double>;
const Matrix identity = [1, 0, 0, 1, 0, 0];

/* `m` then `n`: what a "cm" of `m` makes of the current matrix `n`. */
Matrix then(Matrix m, Matrix n) => [
      m[0] * n[0] + m[1] * n[2], m[0] * n[1] + m[1] * n[3],
      m[2] * n[0] + m[3] * n[2], m[2] * n[1] + m[3] * n[3],
      m[4] * n[0] + m[5] * n[2] + n[4], m[4] * n[1] + m[5] * n[3] + n[5],
    ];

/* The page box (in points, up from the page's lower left) that `m` makes of the rectangle x, y, w, h: whatever the
   turn, the box around its four corners. */
Box boxOf(Matrix m, double x, double y, double w, double h) {
  final corners = [for (final (px, py) in [(x, y), (x + w, y), (x, y + h), (x + w, y + h)])
    (m[0] * px + m[2] * py + m[4], m[1] * px + m[3] * py + m[5])];
  final xs = corners.map((c) => c.$1), ys = corners.map((c) => c.$2);
  final (x0, y0) = (xs.reduce(math.min), ys.reduce(math.min));
  return (x: x0, y: y0, w: xs.reduce(math.max) - x0, h: ys.reduce(math.max) - y0);
}

/* Where two boxes overlap; a box of no size where they do not. */
Box meet(Box a, Box b) {
  final x0 = math.max(a.x, b.x), y0 = math.max(a.y, b.y);
  final x1 = math.min(a.x + a.w, b.x + b.w), y1 = math.min(a.y + a.h, b.y + b.h);
  return (x: x0, y: y0, w: math.max(0, x1 - x0), h: math.max(0, y1 - y0));
}

/* One page's content stream run as a PDF reader runs it: the current matrix and the clip are kept through q and Q, and
   changed by cm and by "re W n". A picture ("/Ix Do") fills the unit square under the current matrix: `full` is its
   page box, turn and offset included, and `shown` the part of it inside the clip, which is what prints. A filled
   rectangle ("re … f") is its page box. */
({List<({Box full, Box shown, Matrix m})> pictures, List<Box> rects}) run(String stream, double w, double h) {
  var ctm = identity;
  Box clip = (x: 0, y: 0, w: w, h: h);
  final saved = <(Matrix, Box)>[], path = <Box>[], nums = <double>[];
  final pictures = <({Box full, Box shown, Matrix m})>[], rects = <Box>[];
  var clipping = false;
  for (final t in RegExp(r'/\w+|[-+]?(?:\d+\.?\d*|\.\d+)|[A-Za-z*]+').allMatches(stream).map((m) => m[0]!)) {
    final n = double.tryParse(t);
    if (n != null) {
      nums.add(n);
      continue;
    }
    if (t.startsWith('/')) continue;
    switch (t) {
      case 'q':
        saved.add((ctm, clip));
      case 'Q':
        (ctm, clip) = saved.removeLast();
      case 'cm':
        ctm = then(nums.sublist(nums.length - 6), ctm);
      case 're':
        final r = nums.sublist(nums.length - 4);
        path.add(boxOf(ctm, r[0], r[1], r[2], r[3]));
      case 'W':
        clipping = true;
      case 'n':
        if (clipping) clip = path.fold(clip, meet);
        path.clear();
        clipping = false;
      case 'f':
        rects.addAll(path);
        path.clear();
      case 'Do':
        final full = boxOf(ctm, 0, 0, 1, 1);
        pictures.add((full: full, shown: meet(full, clip), m: ctm));
    }
    nums.clear();
  }
  return (pictures: pictures, rects: rects);
}

/* Each page of an uncompressed sheet, in order: its MediaBox; the pictures it paints, as they print (`placed`) and
   whole (`full`), and each one's matrix (`mats`); and the filled rectangles (the seams, and the join's line, ticks and their white). */
List<({double w, double h, List<Box> placed, List<Box> full, List<Matrix> mats, List<Box> rects})> pagesOf_(String pdf) {
  final boxes = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)').allMatches(pdf).toList();
  final streams = RegExp(r'stream\r?\n(.*?)endstream', dotAll: true).allMatches(pdf)
      .map((m) => m[1]!).where((s) => s.contains(' Do')).toList();
  expect(streams.length, boxes.length, reason: 'one content stream a page');
  return [
    for (var i = 0; i < boxes.length; i++)
      if ((double.parse(boxes[i][1]!), double.parse(boxes[i][2]!)) case (final w, final h))
        if (run(streams[i], w, h) case final r)
          (w: w, h: h, placed: [for (final p in r.pictures) p.shown], full: [for (final p in r.pictures) p.full],
              mats: [for (final p in r.pictures) p.m], rects: r.rects),
  ];
}

/* The page's squares of cloth, as they print, each in its slot: column and row from the grid's lower left, every one of
   the `rows` × 5 slots filled exactly once, each square 4 cm and on its slot within 0.01 pt. */
List<Box> slotted(List<Box> placed, int rows, String where) {
  final squares = placed.where((s) => (s.w - edge).abs() < 1).toList();
  final left = squares.map((s) => s.x).reduce(math.min), bottom = squares.map((s) => s.y).reduce(math.min);
  final slots = <(int, int)>[];
  for (final s in squares) {
    expect(s.w, closeTo(edge, 0.01), reason: where);
    expect(s.h, closeTo(edge, 0.01), reason: where);
    final (c, r) = (((s.x - left) / edge).round(), ((s.y - bottom) / edge).round());
    expect(s.x, closeTo(left + c * edge, 0.01), reason: '$where: on its column');
    expect(s.y, closeTo(bottom + r * edge, 0.01), reason: '$where: on its row');
    slots.add((c, r));
  }
  expect(slots.toSet(), {for (var c = 0; c < 5; c++) for (var r = 0; r < rows; r++) (c, r)}, reason: '$where: every slot');
  expect(slots.length, 5 * rows, reason: '$where: each slot once');
  return squares;
}

/* zinnia with its cloth turned: square i a quarter turn i % 3 times. 3 does not divide 20, so page 2 (from square 20)
   does not start the pattern again: a page-2 square that took a page-1 square's turn would show. */
DesignView turned() {
  final z = zinnia();
  return z.copyWithRot([for (var i = 0; i < z.grid.length; i++) i % 3]);
}

/* Where a picture's top-left corner lands: PDF draws a picture over the unit square, its top row at y = 1. */
(double, double) topLeftOf(Matrix m) => (m[2] + m[4], m[3] + m[5]);

/* Where the top-left corner of a square turned `turn` quarter turns clockwise lands in its slot `s`: top left, top
   right, bottom right, bottom left (PDF's y runs up the page). */
(double, double) cornerFor(Box s, int turn) => switch (turn % 4) {
      0 => (s.x, s.y + s.h),
      1 => (s.x + s.w, s.y + s.h),
      2 => (s.x + s.w, s.y),
      _ => (s.x, s.y),
    };

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
      final d = design();
      final pdf = latin1.decode(await sheetPdf(d, {'KF-1': square}, [for (final _ in rows) footer],
          paper: paper, join: join, compress: false));
      final pages = pagesOf_(pdf);
      expect(pages.length, rows.length);
      for (final (i, p) in pages.indexed) {
        expect(p.w, closeTo(w, 0.01), reason: 'page ${i + 1} wide');
        expect(p.h, closeTo(h, 0.01), reason: 'page ${i + 1} tall');
        final squares = slotted(p.placed, rows[i], 'page ${i + 1}');
        // Each turned photo whole, not only what its clip leaves: on its own square.
        for (final f in p.full.where((f) => (f.w - edge).abs() < 1)) {
          expect(squares.where((s) => (s.x - f.x).abs() < 0.01 && (s.y - f.y).abs() < 0.01 && (s.w - f.w).abs() < 0.01),
              hasLength(1), reason: 'page ${i + 1}: the photo at $f is its square, not beside it');
        }
        expect(p.full.where((f) => (f.w - edge).abs() < 1), hasLength(5 * rows[i]));
        final xs = squares.map((s) => s.x).toList()..sort(), ys = squares.map((s) => s.y).toList()..sort();
        // The grid centred on its page, both ways.
        expect(xs.first, closeTo((w - 5 * edge) / 2, 0.01), reason: 'page ${i + 1}: centred across');
        expect(ys.first, closeTo((h - rows[i] * edge) / 2, 0.01), reason: 'page ${i + 1}: centred up and down');
        // Each square turned as she turned it, clockwise: its photo's top-left corner where that turn puts it. The
        // squares are painted first, in the grid's order.
        final from = rows.take(i).fold(0, (a, b) => a + b) * 5;
        for (final (k, s) in squares.indexed) {
          final turn = d.rot[from + k];
          final (cx, cy) = topLeftOf(p.mats[k]);
          final (ex, ey) = cornerFor(s, turn);
          expect(cx, closeTo(ex, 0.01), reason: 'page ${i + 1}, square ${from + k + 1}, turned $turn: across');
          expect(cy, closeTo(ey, 0.01), reason: 'page ${i + 1}, square ${from + k + 1}, turned $turn: up and down');
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

  test('Letter, a wide photo turned every way: each is cut to its own square, and the whole photo is centred on it, '
      '6 × 4 cm one way round and 4 × 6 the other, so an offset under a turn lands where it should', () async {
    final d = turned();
    final pages = pagesOf_(latin1.decode(await sheetPdf(d, {'KF-1': wide}, [footer, footer],
        paper: Paper.letter, join: join, compress: false)));
    var i = 0;
    for (final (n, p) in pages.indexed) {
      final squares = slotted(p.placed, n == 0 ? 4 : 3, 'page ${n + 1}');
      // The squares are painted first, in the grid's order.
      for (final (k, s) in squares.indexed) {
        final f = p.full[k], turn = d.rot[i++];
        final (long, short) = (edge * 1.5, edge);
        expect(f.w, closeTo(turn.isEven ? long : short, 0.01), reason: 'square $i turned $turn: across');
        expect(f.h, closeTo(turn.isEven ? short : long, 0.01), reason: 'square $i turned $turn: up and down');
        expect(f.x + f.w / 2, closeTo(s.x + s.w / 2, 0.01), reason: 'square $i: centred across');
        expect(f.y + f.h / 2, closeTo(s.y + s.h / 2, 0.01), reason: 'square $i: centred up and down');
      }
    }
    expect(i, d.grid.length);
  });

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
