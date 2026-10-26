import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:image/image.dart' as img;
import 'package:kantha_studio/downloads/caption.dart';
import 'package:kantha_studio/downloads/paper.dart';
import 'package:kantha_studio/downloads/sheet_pdf.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'caption_test.dart' show zinnia;

final square = Uint8List.fromList(img.encodeJpg(img.Image(width: 600, height: 600)..clear(img.ColorRgb8(30, 120, 140))));
final footer = Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 40)));
final join = Uint8List.fromList(img.encodePng(img.Image(width: 900, height: 30)));

double mm(String pt) => double.parse(pt) * 25.4 / 72;

/* 4 cm in points: 4 / 2.54 × 72. */
const edge = 4 / 2.54 * 72;

/* Each page of an uncompressed sheet, in order: its MediaBox and the pictures its content stream paints. A picture is
   painted by "w 0 0 h 0 0 cm /Ix Do" (its width and height in points) after its Positioned's "1 0 0 1 x y cm" (its
   lower-left corner, in points up from the page's lower left): the last move before it. */
List<({double w, double h, List<({double w, double h, double x, double y})> placed})> pagesOf_(String pdf) {
  final boxes = RegExp(r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)').allMatches(pdf).toList();
  final streams = RegExp(r'stream\r?\n(.*?)endstream', dotAll: true).allMatches(pdf)
      .map((m) => m[1]!).where((s) => s.contains(' Do')).toList();
  expect(streams.length, boxes.length, reason: 'one content stream a page');
  return [
    for (var i = 0; i < boxes.length; i++)
      (w: double.parse(boxes[i][1]!), h: double.parse(boxes[i][2]!), placed: _placed(streams[i])),
  ];
}

/* The filled rectangles a content stream paints ("0 0 w h re … f"), each at the last move before it: the seams, and
   the join's line and ticks. */
List<({double w, double h, double x, double y})> rects(String stream) {
  final found = <({double w, double h, double x, double y})>[];
  var (x, y) = (0.0, 0.0);
  for (final m in RegExp(r'1 0 0 1 ([-\d.]+) ([-\d.]+) cm|0 0 ([\d.]+) ([\d.]+) re [^f]*?f').allMatches(stream)) {
    if (m[1] != null) {
      final (mx, my) = (double.parse(m[1]!), double.parse(m[2]!));
      if (mx != 0 || my != 0) (x, y) = (mx, my);
    } else {
      found.add((w: double.parse(m[3]!), h: double.parse(m[4]!), x: x, y: y));
    }
  }
  return found;
}

/* Each page's content stream, in order. */
List<String> streamsOf(String pdf) => RegExp(r'stream\r?\n(.*?)endstream', dotAll: true).allMatches(pdf)
    .map((m) => m[1]!).where((s) => s.contains(' Do')).toList();

List<({double w, double h, double x, double y})> _placed(String stream) {
  final placed = <({double w, double h, double x, double y})>[];
  var (x, y) = (0.0, 0.0);
  for (final m in RegExp(r'1 0 0 1 ([-\d.]+) ([-\d.]+) cm|([\d.]+) 0 0 ([\d.]+) 0 0 cm\s*/I\w+ Do').allMatches(stream)) {
    if (m[1] != null) {
      final (mx, my) = (double.parse(m[1]!), double.parse(m[2]!));
      if (mx != 0 || my != 0) (x, y) = (mx, my);
    } else {
      placed.add((w: double.parse(m[3]!), h: double.parse(m[4]!), x: x, y: y));
    }
  }
  return placed;
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
    test('${paper.name}: ${rows.length} page(s) of ${w.toStringAsFixed(2)} × ${h.toStringAsFixed(2)} pt, '
        'every square 4 cm within 0.01 pt', () async {
      final pdf = latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [for (final _ in rows) footer],
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

  test('Letter: the join words sit 2 mm above page 2’s top line', () async {
    final pages = pagesOf_(latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [footer, footer],
        paper: Paper.letter, join: join, compress: false)));
    final second = pages[1].placed, squares = second.where((s) => (s.w - edge).abs() < 1);
    final top = squares.map((s) => s.y + edge).reduce((a, b) => a > b ? a : b); // PDF y runs up the page
    final words = second.firstWhere((s) => (s.w - 900 * 72 / 300).abs() < 0.01);
    expect(words.y, closeTo(top + 4 * 72 / 25.4, 0.01), reason: '4 mm above the line, clear of the ticks');
  });

  test('Letter: where the pages meet, each draws a solid line along that edge and a tick across it at every column '
      'line, half in the grid and half in the margin; A4 has none', () async {
    const mm = 72 / 25.4, mark = 0.3 * mm;
    final pdf = latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [footer, footer],
        paper: Paper.letter, join: join, compress: false));
    final pages = pagesOf_(pdf), streams = streamsOf(pdf);
    for (final (i, p) in pages.indexed) {
      final squares = p.placed.where((s) => (s.w - edge).abs() < 1).toList();
      final left = squares.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      // PDF y runs up the page: page 1 meets page 2 along its grid's bottom, page 2 meets page 1 along its top.
      final y = i == 0 ? squares.map((s) => s.y).reduce((a, b) => a < b ? a : b)
          : squares.map((s) => s.y + edge).reduce((a, b) => a > b ? a : b);
      final marks = rects(streams[i]).where((r) => (r.w - mark).abs() < 0.01 || (r.h - mark).abs() < 0.01).toList();
      final line = marks.where((r) => (r.h - mark).abs() < 0.01).toList();
      expect(line, hasLength(1), reason: 'page ${i + 1}: one join line');
      expect(line.single.w, closeTo(20 / 2.54 * 72 + 10 * mm, 0.01), reason: 'the grid and 5 mm past each side');
      expect(line.single.x, closeTo(left - 5 * mm, 0.01));
      expect(line.single.y + mark / 2, closeTo(y, 0.01), reason: 'centred on the edge');
      final ticks = marks.where((r) => (r.w - mark).abs() < 0.01).toList()..sort((a, b) => a.x.compareTo(b.x));
      expect(ticks, hasLength(6), reason: 'page ${i + 1}: one at each of the 6 column lines');
      for (final (c, t) in ticks.indexed) {
        expect(t.x + mark / 2, closeTo(left + c * edge, 0.01), reason: 'on column line $c');
        expect(t.h, closeTo(6 * mm, 0.01));
        expect(t.y + t.h / 2, closeTo(y, 0.01), reason: '3 mm into the grid, 3 mm into the margin');
      }
    }
    final a4 = latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, [footer], compress: false));
    expect(rects(streamsOf(a4).single).where((r) => (r.w - mark).abs() < 0.01 || (r.h - mark).abs() < 0.01), isEmpty);
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
