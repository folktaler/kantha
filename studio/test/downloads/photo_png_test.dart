import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/downloads/footer_png.dart';
import 'package:kantha_studio/downloads/photo_png.dart';
import 'caption_test.dart' show zinnia;

Future<void> loadFonts() async {
  final sans = FontLoader('Public Sans')..addFont(rootBundle.load('assets/fonts/PublicSans-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/PublicSans-SemiBold.ttf'));
  final ml = FontLoader('Noto Sans Malayalam')..addFont(rootBundle.load('assets/fonts/NotoSansMalayalam-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansMalayalam-SemiBold.ttf'));
  await Future.wait([sans.load(), ml.load()]);
}

/* The picture drawn now against the one drawn before: the same size; above `wordsFrom` (the drawing: ground, cloth,
   seams) every pixel the same; from there down (the words) all but `allow` pixels the same — each machine's text
   rasteriser sets a glyph's edges a little differently (the fixtures were drawn on the Mac; the mini's build differed
   in 763 pixels of the photo's caption and 181 of the footer, none of the drawing). `allow` sits under the inked
   pixels of the smallest line (the photo's fourth line has 1,823; the footer's one line 3,807), so a changed colour,
   face or weight on any one line still fails. */
void expectSamePicture(Uint8List? png, String fixture, String reason, {required int wordsFrom, required int allow}) {
  final now = img.decodePng(png!)!, was = img.decodePng(File(fixture).readAsBytesSync())!;
  expect((now.width, now.height, now.numChannels), (was.width, was.height, was.numChannels), reason: '$reason: its size');
  // Each image's bytes read once, a pixel `channels` of them; its row is its offset over a row's bytes.
  final a = now.getBytes(), b = was.getBytes(), channels = was.numChannels, rowBytes = was.width * channels;
  var drawing = 0, words = 0;
  for (var i = 0; i < b.length; i += channels) {
    for (var k = 0; k < channels; k++) {
      if (a[i + k] != b[i + k]) {
        i ~/ rowBytes < wordsFrom ? drawing++ : words++;
        break;
      }
    }
  }
  expect(drawing, 0, reason: '$reason: $drawing pixels of the drawing differ');
  expect(words, lessThan(allow), reason: '$reason: $words pixels of the words differ');
}

void main() {
  testWidgets('the photo and the footer she shares are what they were before the studio went to Inter', (tester) async {
    // Both fixtures were drawn by the studio of 11 Oct (737bb39), with these fonts loaded, for this design and these words.
    await tester.runAsync(loadFonts);
    final png = (await tester.runAsync(() => photoPng(zinnia(), const {},
        ['കാന്ത — ഒരു പരീക്ഷണം', 'High contrast — Every seam earns its keep, light against dark.',
          'Upcycled from 35 cloth pieces', 'made with kantha.app'])))?.png;
    expectSamePicture(png, 'test/fixtures/photo-fixture.png', 'the photo', wordsFrom: 1100, allow: 1500);
    final footer = await tester.runAsync(() => footerPng('കാന്ത · made with kantha.app'));
    expectSamePicture(footer, 'test/fixtures/footer-fixture.png', "the sheet's footer", wordsFrom: 0, allow: 400);
  }, tags: 'pixels');

  testWidgets('the photo is a 1080 × 1350 PNG, on every mount, with a Malayalam name', (tester) async {
    await tester.runAsync(loadFonts);
    for (final mount in ['none', 'frame', 'tote']) {
      final made = await tester.runAsync(() => photoPng(zinnia().withMount(mount), const {},
          ['കാന്ത — ഒരു പരീക്ഷണം', 'High contrast — Every seam earns its keep, light against dark.',
            'Upcycled from 35 cloth pieces', 'made with kantha.app']));
      expect(made?.thumb, isNull, reason: 'no small copy for Save photo or Share');
      final back = img.decodePng(made!.png)!;
      expect((back.width, back.height), (1080, 1350), reason: mount);
    }
  });

  testWidgets('each square is its cloth covering it, turned clockwise as she turned it', (tester) async {
    await tester.runAsync(loadFonts);
    // A 600 × 400 picture, red on its left half and blue on its right: covering a square, the
    // middle 400 × 400 is shown, red on the left and blue on the right, edge to edge.
    final picture = img.Image(width: 600, height: 400)..clear(img.ColorRgb8(0, 0, 255));
    img.fillRect(picture, x1: 0, y1: 0, x2: 299, y2: 399, color: img.ColorRgb8(255, 0, 0));
    final d = zinnia().withMount('none').copyWithRot([1, ...List.filled(34, 0)]);
    final png = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(img.encodePng(picture));
      final photo = (await codec.getNextFrame()).image;
      return (await photoPng(d, {'KF-1': photo}, ['Zinnia', 'b', 'c', 'd'])).png;
    });
    final back = img.decodePng(png!)!;
    // The grid: the run of red or blue along the middle row of the picture, from the left.
    bool coloured(img.Pixel p) => (p.r > 200 && p.g < 60 && p.b < 60) || (p.b > 200 && p.r < 60 && p.g < 60);
    final y = 300;
    final left = [for (var x = 0; x < 1080; x++) x].firstWhere((x) => coloured(back.getPixel(x, y)));
    final right = [for (var x = 1079; x >= 0; x--) x].firstWhere((x) => coloured(back.getPixel(x, y)));
    final s = (right - left + 1) / 5;
    final top = [for (var yy = 0; yy < 1350; yy++) yy].firstWhere((yy) => coloured(back.getPixel(left + s ~/ 2 + s.round(), yy)));
    String at(int col, int row, double fx, double fy) {
      final p = back.getPixel((left + (col + fx) * s).round(), (top + (row + fy) * s).round());
      return p.r > 200 && p.b < 60 ? 'red' : p.b > 200 && p.r < 60 ? 'blue' : 'other';
    }
    // Unturned (square 1): red left, blue right, and covered to its corners.
    expect([at(1, 0, 0.25, 0.5), at(1, 0, 0.75, 0.5)], ['red', 'blue']);
    expect([at(1, 0, 0.06, 0.06), at(1, 0, 0.94, 0.94)], ['red', 'blue'], reason: 'covered, no base showing');
    // A quarter turn clockwise (square 0): the left half comes to the top.
    expect([at(0, 0, 0.5, 0.25), at(0, 0, 0.5, 0.75)], ['red', 'blue']);
  });
}
