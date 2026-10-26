import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/jpeg_size.dart';
import 'package:kantha_studio/cloth/photo_source.dart' show previewLongSide;
import 'package:kantha_studio/cloth/prepare.dart';
import 'package:kantha_studio/measure/measure.dart';
import '../fixtures/fixtures.g.dart' as g;

/* 0.6, the spec's tolerance for a JPEG (decision 10). Both values are rounded to one decimal, so a difference of
   exactly 0.6 comes out as 0.6000000000000014 in floating point; it is still within. */
const _within = 0.6 + 1e-9;

void main() {
  test('a picture past the stored size is brought down to it on its long side, and stored as JPEG', () async {
    final big = img.encodePng(img.Image(width: 3000, height: 3000)..clear(img.ColorRgb8(120, 90, 60)));
    final out = await preparePhoto(big);
    expect(img.findFormatForData(out.jpeg), img.ImageFormat.jpg);
    final back = img.decodeJpg(out.jpeg)!;
    expect((back.width, back.height), (storedLongSide, storedLongSide));
    expect(out.measured.name, isNotEmpty);
  });

  test('a phone photo turned by EXIF is stored and measured upright', () async {
    final out = await preparePhoto(base64Decode(g.pictures['rotated.jpg']!));
    final back = img.decodeJpg(out.jpeg)!;
    expect(back.height, greaterThan(back.width));
  });

  test('measured again from the stored JPEG, a cloth reads within 0.6 and by the same name', () async {
    for (final file in ['checker-print.png', 'gradient.png', 'noise.png', 'flat-mid.png']) {
      final out = await preparePhoto(base64Decode(g.pictures[file]!));
      final again = measureBytes(out.jpeg);
      expect((again.lab.l - out.measured.lab.l).abs(), lessThanOrEqualTo(_within), reason: '$file L*');
      expect((again.lab.a - out.measured.lab.a).abs(), lessThanOrEqualTo(_within), reason: '$file a*');
      expect((again.lab.b - out.measured.lab.b).abs(), lessThanOrEqualTo(_within), reason: '$file b*');
      expect((again.spread - out.measured.spread).abs(), lessThanOrEqualTo(_within), reason: '$file spread');
      expect(again.name, out.measured.name, reason: file);
    }
  });

  // Beyond the brief (and fix round 1).
  test('grey, see-through, palette and phone (EXIF-turned JPEG) pictures, stored, read again within 0.6 and by the same name', () async {
    for (final file in ['grey.png', 'alpha.png', 'palette.png', 'rotated.jpg']) {
      final out = await preparePhoto(base64Decode(g.pictures[file]!));
      final again = measureBytes(out.jpeg);
      expect((again.lab.l - out.measured.lab.l).abs(), lessThanOrEqualTo(_within), reason: '$file L*');
      expect((again.lab.a - out.measured.lab.a).abs(), lessThanOrEqualTo(_within), reason: '$file a*');
      expect((again.lab.b - out.measured.lab.b).abs(), lessThanOrEqualTo(_within), reason: '$file b*');
      expect((again.spread - out.measured.spread).abs(), lessThanOrEqualTo(_within), reason: '$file spread');
      expect(again.name, out.measured.name, reason: file);
    }
  });

  test('a crop larger than the stored size is measured at its own resolution: the same numbers as measuring the full crop', () async {
    // A fine weave, 2 px threads of two colours, 2400 px across: brought down to 600 first,
    // its threads would blur together and its lightness spread would fall.
    final weave = img.Image(width: 2400, height: 2400);
    for (final p in weave) {
      final dark = (p.x ~/ 2 + p.y ~/ 2).isEven;
      p..r = dark ? 70 : 200..g = dark ? 40 : 170..b = dark ? 90 : 120;
    }
    final crop = img.encodePng(weave);
    final out = await preparePhoto(crop);
    final whole = measureBytes(crop);
    expect((out.measured.lab, out.measured.spread, out.measured.name), (whole.lab, whole.spread, whole.name));
  });

  test('the cropper is given the photo read once, upright by its EXIF, and does not read it again', () async {
    final turned = base64Decode(g.pictures['rotated.jpg']!);
    checkPicked(turned);
    final photo = await readPhoto(turned);
    expect((photo.width, photo.height), (480, 640));
    final parsed = photo.parser(Uint8List(0));
    expect((parsed.width, parsed.height), (480.0, 640.0));
    expect(parsed.image, isNull, reason: 'the parser holds the size only: compute copies nothing big');
    expect(photo.parser, photo.parser, reason: 'one parser for the photo, so the cropper does not read it again');
  });

  test('a photo longer than 2560 px is brought down to 2560 px by area average, and the cropper is shown that picture '
      'at 1200 px', () async {
    // Fine stripes, 1 px of each colour: an average keeps their mean, a nearest-pixel shrink would not.
    final big = img.Image(width: 4000, height: 3000);
    for (final p in big) {
      p..r = p.x.isEven ? 220 : 30..g = 60..b = p.x.isEven ? 40 : 200;
    }
    final picked = img.encodeJpg(big, quality: 95);
    checkPicked(picked);
    final photo = await readPhoto(picked);
    expect((photo.width, photo.height), (2560, 1920));
    final shown = img.decodeJpg(photo.bytes)!;
    expect((shown.width, shown.height), (previewLongSide, 900), reason: 'shown smaller, in the shape it is cut from');
    final parsed = photo.parser(Uint8List(0));
    expect((parsed.width, parsed.height), (2560.0, 1920.0), reason: 'laid out, and cut, by the picture\'s own size');
    final expected = img.copyResize(img.decodeJpg(picked)!, width: 2560, interpolation: img.Interpolation.average);
    final picture = photo.picture as img.Image;
    // The phone's own decoder reads the JPEG, so a pixel can differ by 1 from the image package's reading of it.
    expect([for (var x = 0; x < 50; x++) picture.getPixel(x, 900).r],
        [for (var x = 0; x < 50; x++) closeTo(expected.getPixel(x, 900).r, 2)]);
  });

  test('the square is handed on without loss, and measured and stored from it as from the crop itself', () async {
    final picture = img.Image(width: 300, height: 200);
    for (final p in picture) {
      p..r = p.x % 256..g = p.y % 256..b = (p.x * p.y) % 256;
    }
    final square = await PhotoCropper(picture).call(original: null, topLeft: const Offset(40, 20), bottomRight: const Offset(190, 170));
    final crop = img.copyCrop(picture, x: 40, y: 20, width: 150, height: 150);
    final back = img.decodeImage(square)!;
    expect((back.width, back.height), (150, 150));
    expect([for (final p in back) (p.r, p.g, p.b)], [for (final p in crop) (p.r, p.g, p.b)]);
    final out = await preparePhoto(square);
    final direct = measureImage(crop);
    expect((out.measured.lab, out.measured.spread, out.measured.name), (direct.lab, direct.spread, direct.name));
  });

  test('what is not a picture is refused before the cropper reads it; a large photo is not (it is brought down)', () {
    expect(() => checkPicked(utf8.encode('not a picture')), throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'notAnImage')));
    // A 6000 × 5000 PNG header (30 MP): only the header is read.
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1)));
    ByteData.sublistView(png)
      ..setUint32(16, 6000)
      ..setUint32(20, 5000)
      ..setUint32(29, getCrc32(png.sublist(12, 29)));
    checkPicked(png);
    expect(pickedSize(png), (width: 6000, height: 5000));
  });

  test('a JPEG of 48 or 50 MP is taken and a 64 MP one is refused before it is read; any other picture past 30 MP is '
      'refused', () {
    Uint8List png(int w, int h) {
      final png = Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1)));
      ByteData.sublistView(png)
        ..setUint32(16, w)
        ..setUint32(20, h)
        ..setUint32(29, getCrc32(png.sublist(12, 29)));
      return png;
    }
    Uint8List jpeg(int w, int h) {
      final jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 1, height: 1)));
      final at = [for (var i = 2; i < jpeg.length - 1; i++) if (jpeg[i] == 0xFF && jpeg[i + 1] == 0xC0) i].first;
      ByteData.sublistView(jpeg)
        ..setUint16(at + 5, h)
        ..setUint16(at + 7, w);
      return jpeg;
    }
    checkPicked(jpeg(8000, 6000));
    checkPicked(jpeg(8160, 6144));
    checkPicked(png(6000, 5000));
    for (final picked in [jpeg(9248, 6936), jpeg(12000, 9000), png(8000, 6000), png(6400, 4800)]) {
      expect(() => checkPicked(picked), throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'pixelLimit')),
          reason: '${pickedSize(picked)}');
    }
  });

  test('a JPEG with markers that stand alone before its frame (TEM, RST0-7, fill bytes) is still sized from its header',
      () {
    final b = img.encodeJpg(img.Image(width: 300, height: 200));
    var sof = 2;
    while (!(b[sof] == 0xFF && b[sof + 1] == 0xC0)) {
      sof++;
    }
    final alone = [0xFF, 0x01, for (var m = 0xD0; m <= 0xD7; m++) ...[0xFF, m], 0xFF, 0xFF, 0xFF, 0xD3];
    final marked = Uint8List.fromList([...b.sublist(0, 2), ...alone, ...b.sublist(2, sof), ...alone, ...b.sublist(sof)]);
    expect(jpegSize(marked), (width: 300, height: 200));
    expect(jpegSize(Uint8List.fromList([...b.sublist(0, sof), 0xFF, 0x01])), isNull, reason: 'no frame, then the end');
  });

  test("a JPEG's size is read from its frame header alone, as the image package reads it", () {
    for (final (w, h) in [(300, 200), (200, 300), (4000, 3000), (1, 1)]) {
      final picture = img.Image(width: w, height: h)..exif.imageIfd.orientation = 6;
      final jpeg = img.encodeJpg(picture);
      final info = img.JpegDecoder().startDecode(jpeg)!;
      expect(pickedSize(jpeg), (width: info.width, height: info.height));
      expect(pickedSize(jpeg), (width: w, height: h));
    }
    final b = img.encodeJpg(img.Image(width: 300, height: 200)..clear(img.ColorRgb8(30, 120, 140)));
    var sos = 0;
    while (!(b[sos] == 0xFF && b[sos + 1] == 0xDA)) {
      sos++;
    }
    // After the scan's header, bytes the image package's whole-file walk throws on (a restart marker, then a length 0).
    for (var i = sos + 2 + (b[sos + 2] << 8 | b[sos + 3]); i + 3 < b.length; i += 4) {
      b.setAll(i, [0xFF, 0xD0, 0, 0]);
    }
    expect(() => img.JpegDecoder().startDecode(b), throwsA(isA<img.ImageException>()), reason: 'the whole file walked fails');
    expect(pickedSize(b), (width: 300, height: 200));
  });

  test('a JPEG with a whole header and a broken body passes the header read, then fails the whole read', () async {
    final b = img.encodeJpg(img.Image(width: 200, height: 200)..clear(img.ColorRgb8(30, 120, 140)));
    for (var i = 0; i < b.length - 1; i++) {
      if (b[i] == 0xFF && b[i + 1] == 0xDA) {
        b[i + 4] = 9; // the scan names nine components
        break;
      }
    }
    checkPicked(b);
    await expectLater(readPhoto(b), throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'notAnImage')));
    await readPhoto(base64Decode(g.pictures['rotated.jpg']!));
  });

  test('the stored photo carries no EXIF: no place, no camera', () async {
    final out = await preparePhoto(base64Decode(g.pictures['rotated.jpg']!));
    expect(img.decodeJpgExif(out.jpeg)?.isEmpty ?? true, isTrue);
  });
}
