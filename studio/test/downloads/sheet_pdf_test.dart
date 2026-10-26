import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/downloads/sheet_pdf.dart';
import 'caption_test.dart' show zinnia;

final square = Uint8List.fromList(img.encodeJpg(img.Image(width: 600, height: 600)..clear(img.ColorRgb8(30, 120, 140))));
final footer = Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 40)));

double mm(String pt) => double.parse(pt) * 25.4 / 72;

void main() {
  test('one A4 page, its squares exactly 40.0 mm', () async {
    final pdf = latin1.decode(await sheetPdf(zinnia(), {'KF-1': square}, footer, compress: false));
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
    final pdf = await sheetPdf(zinnia(), {'KF-1': null}, footer, compress: false);
    expect(pdf.length, greaterThan(1000));
    expect(RegExp(r'/I\w+ Do').allMatches(latin1.decode(pdf)).length, 1, reason: 'only the footer is an image');
  });
}
