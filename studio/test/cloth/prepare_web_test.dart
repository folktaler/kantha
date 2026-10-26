@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/prepare.dart';
import 'package:kantha_studio/downloads/smaller_web.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/platform/canvas_web.dart';
import 'package:web/web.dart' as web;
import '../fixtures/fixtures.g.dart' as g;

/* The web's photo path (prepare_web.dart, smaller_web.dart): the browser reads, crops, sizes and saves; Dart measures. */
void main() {
  final browser = createBitmap;
  setUp(forgetBitmapOptions);
  tearDown(() {
    createBitmap = browser;
    forgetBitmapOptions();
  });

  /* A browser that refuses `refused` (option name to value) with a TypeError, as one that predates the value does. One
     that refuses 'from-image' is made to read the file as such a browser did, without its EXIF turn. */
  void olderBrowser(Map<String, String> refused, {List<web.ImageBitmapOptions>? asked}) {
    createBitmap = (source, options) async {
      asked?.add(options);
      for (final e in refused.entries) {
        if (options.getProperty<JSAny?>(e.key.toJS)?.dartify() == e.value) throw TypeError();
      }
      if (refused['imageOrientation'] == 'from-image' && source.instanceOfString('Blob')) {
        final bytes = (await (source as web.Blob).arrayBuffer().toDart).toDart.asUint8List();
        source = web.Blob(<JSAny>[_withoutExif(bytes).toJS].toJS);
      }
      return browser(source, options);
    };
  }

  /* Stored 64 × 32, red on the left, blue on the right, EXIF orientation 6 (a quarter turn clockwise): upright it is
     32 × 64, red on top. */
  Uint8List quarterTurned() {
    final stored = img.Image(width: 64, height: 32);
    for (final p in stored) {
      p..r = p.x < 32 ? 220 : 20..g = 20..b = p.x < 32 ? 20 : 220;
    }
    stored.exif.imageIfd.orientation = 6;
    return img.encodeJpg(stored, quality: 95);
  }
  bool red(num r, num b) => r > 150 && b < 100;

  test('a browser that refuses imageOrientation from-image: the photo is turned upright by the image package', () async {
    olderBrowser({'imageOrientation': 'from-image'});
    expect((await bitmapOptions()).orientation, isFalse);
    final photo = await readPhoto(quarterTurned());
    expect((photo.width, photo.height), (32, 64));
    final top = await PhotoCropper(photo.picture).call(original: null, topLeft: Offset.zero, bottomRight: const Offset(32, 32));
    expect(red(top[0], top[2]), isTrue, reason: 'cut: (${top[0]}, ${top[2]})');
    final preview = img.decodeJpg(photo.bytes)!;
    expect((preview.width, preview.height), (32, 64));
    expect(red(preview.getPixel(16, 8).r, preview.getPixel(16, 8).b), isTrue, reason: 'shown the same way up');
    photo.close();
  });

  test('a browser that refuses from-image but turns the photo anyway: it is not turned twice', () async {
    createBitmap = (source, options) =>
        options.getProperty<JSAny?>('imageOrientation'.toJS)?.dartify() == 'from-image' ? Future.error(TypeError()) : browser(source, options);
    final photo = await readPhoto(quarterTurned());
    expect((photo.width, photo.height), (32, 64));
    final top = await PhotoCropper(photo.picture).call(original: null, topLeft: Offset.zero, bottomRight: const Offset(32, 32));
    expect(red(top[0], top[2]), isTrue, reason: 'cut: (${top[0]}, ${top[2]})');
    photo.close();
  });

  test('a browser that refuses colorSpaceConversion none as well still reads the photo, upright', () async {
    olderBrowser({'imageOrientation': 'from-image', 'colorSpaceConversion': 'none'});
    expect(await bitmapOptions(), (orientation: false, raw: false, upright: false));
    final photo = await readPhoto(quarterTurned());
    expect((photo.width, photo.height), (32, 64));
    photo.close();
  });

  test('a photo past 2560 px is decoded by the browser straight at 2560 px (resizeQuality high), from its header size',
      () async {
    final asked = <web.ImageBitmapOptions>[];
    olderBrowser({}, asked: asked);
    final photo = await readPhoto(img.encodePng(img.Image(width: 6000, height: 4000)..clear(img.ColorRgb8(200, 60, 40))));
    expect((photo.width, photo.height), (2560, 1707));
    final read = asked.last;
    expect((read.getProperty<JSAny?>('resizeWidth'.toJS)?.dartify(), read.getProperty<JSAny?>('resizeHeight'.toJS)?.dartify(),
        read.resizeQuality), (2560, 1707, 'high'), reason: 'both sides, rounded as on a phone');
    photo.close();
  });

  test('a browser that does not know the resize options gives the photo whole: it is brought down on a canvas', () async {
    createBitmap = (source, options) {
      options..delete('resizeWidth'.toJS)..delete('resizeHeight'.toJS)..delete('resizeQuality'.toJS);
      return browser(source, options);
    };
    final photo = await readPhoto(img.encodePng(img.Image(width: 3200, height: 2000)..clear(img.ColorRgb8(200, 60, 40))));
    expect((photo.width, photo.height), (2560, 1600));
    photo.close();
  });

  test('what has no readable header is refused before a box is made; a large photo is not', () {
    expect(() => checkPicked(utf8.encode('not a picture')), throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'notAnImage')));
    checkPicked(img.encodePng(img.Image(width: 3200, height: 2000)));
  });

  test('on the web too, a JPEG past 52 MP or another picture past 30 MP is refused before the browser reads it', () {
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
    Uint8List png(int w, int h) {
      final png = Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1)));
      ByteData.sublistView(png)
        ..setUint32(16, w)
        ..setUint32(20, h)
        ..setUint32(29, getCrc32(png.sublist(12, 29)));
      return png;
    }
    for (final picked in [jpeg(12000, 9000), png(6400, 4800)]) {
      expect(() => checkPicked(picked), throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'pixelLimit')),
          reason: '${pickedSize(picked)}');
    }
  });

  test('a finely striped photo is measured alike on the web (browser high resize) and on a phone (area average)',
      () async {
    // Stripes `thread` px wide, two colours, across a 4000 × 3000 photo.
    // The phone and the web shrink differently, so they are held to the gap measured on 20 Oct with a little
    // headroom, not to 0.5: the area average is off the browser's 'high' resize by up to ΔL* 1.5, Δb* 2.1 and
    // Δspread 2.7 (2 px stripes). The image package's cubic would match within 0.1, but it adds about 3.7 s per photo
    // on an M4 Pro (his decision, 20 Oct: the area average, for the wait).
    final gaps = <(int, double, double, double, double)>[];
    for (final thread in [1, 2, 3, 4, 8]) {
      final big = img.Image(width: 4000, height: 3000);
      for (final p in big) {
        final dark = (p.x ~/ thread).isEven;
        p..r = dark ? 60 : 225..g = dark ? 40 : 200..b = dark ? 110 : 150;
      }
      final picked = img.encodePng(big);
      final photo = await readPhoto(picked);
      expect((photo.width, photo.height), (2560, 1920));
      final square = await PhotoCropper(photo.picture).call(original: null, topLeft: const Offset(320, 0),
          bottomRight: const Offset(2240, 1920));
      final web = (await preparePhoto(square)).measured;
      final phonePicture = img.copyResize(big, width: 2560, interpolation: img.Interpolation.average);
      final phone = measureImage(img.copyCrop(phonePicture, x: 320, y: 0, width: 1920, height: 1920));
      final dl = (web.lab.l - phone.lab.l).abs(), da = (web.lab.a - phone.lab.a).abs(), db = (web.lab.b - phone.lab.b).abs();
      final ds = (web.spread - phone.spread).abs();
      // ignore: avoid_print
      print('stripes $thread px wide: web L*a*b* ${web.lab} spread ${web.spread}; phone ${phone.lab} spread '
          '${phone.spread}; ΔL* $dl Δa* $da Δb* $db Δspread $ds');
      final near = measureImage(img.copyCrop(img.copyResize(big, width: 2560, interpolation: img.Interpolation.nearest),
          x: 320, y: 0, width: 1920, height: 1920));
      // ignore: avoid_print
      print('  nearest pixel (the picker on Android before): ${near.lab} spread ${near.spread}');
      gaps.add((thread, dl, ds, da, db));
      photo.close();
    }
    expect([for (final g in gaps) if (g.$2 > 2.0 || g.$3 > 3.5 || g.$4 > 2.5 || g.$5 > 2.5) g], isEmpty,
        reason: '(stripe px, ΔL*, Δspread, Δa*, Δb*)');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a picked photo is read by the browser, upright by its EXIF', () async {
    final photo = await readPhoto(base64Decode(g.pictures['rotated.jpg']!));
    expect((photo.width, photo.height), (480, 640));
    final parsed = photo.parser(Uint8List(0));
    expect((parsed.width, parsed.height), (480.0, 640.0));
    expect(parsed.image, isNull, reason: 'the size only; the cropper is handed the picture itself');
  });

  test('a photo turned by EXIF orientation 6: the cropper is shown the same upright picture it cuts from', () async {
    // Stored 64 × 32, red on the left, blue on the right; orientation 6 says turn it a quarter clockwise, so upright it
    // is 32 × 64, red on top.
    final stored = img.Image(width: 64, height: 32);
    for (final p in stored) {
      p..r = p.x < 32 ? 220 : 20..g = 20..b = p.x < 32 ? 20 : 220;
    }
    stored.exif.imageIfd.orientation = 6;
    final picked = img.encodeJpg(stored, quality: 95);
    expect(img.decodeJpgExif(picked)!.imageIfd.orientation, 6);

    final photo = await readPhoto(picked);
    expect((photo.width, photo.height), (32, 64), reason: 'the browser turned it');
    final shown = photo.bytes;
    expect(img.decodeJpgExif(shown)?.imageIfd.orientation ?? 1, 1, reason: 'the bytes the cropper shows name no turn');
    final preview = img.decodeJpg(shown)!;
    expect((preview.width, preview.height), (32, 64), reason: 'shown as the cropper lays it out');
    final top = await PhotoCropper(photo.picture).call(original: null, topLeft: Offset.zero,
        bottomRight: const Offset(32, 32));
    // The cut's top square, and the preview's: both red.
    bool red(num r, num b) => r > 150 && b < 100;
    bool blue(num r, num b) => r < 100 && b > 150;
    expect(red(top[0], top[2]), isTrue, reason: 'cut: (${top[0]}, ${top[2]})');
    final p = preview.getPixel(16, 8), q = preview.getPixel(16, 56);
    expect(red(p.r, p.b), isTrue, reason: 'preview top: (${p.r}, ${p.b})');
    expect(blue(q.r, q.b), isTrue, reason: 'preview bottom: (${q.r}, ${q.b})');
    photo.close();
  });

  test('what the browser cannot read is notAnImage', () async {
    await expectLater(readPhoto(utf8.encode('not a picture')),
        throwsA(isA<MeasureError>().having((e) => e.key, 'key', 'notAnImage')));
  });

  test('the square is measured from its own pixels, as the phone measures it, and stored ≤ 600 px at quality 80',
      () async {
    final big = img.Image(width: 1200, height: 1000);
    for (final p in big) {
      p..r = 120 + p.x % 40..g = 90 + p.y % 30..b = 60;
    }
    final photo = await readPhoto(img.encodePng(big));
    final square = await PhotoCropper(photo.picture).call(original: null, topLeft: const Offset(100, 50),
        bottomRight: const Offset(1000, 950));
    expect(square.length, 900 * 900 * 4, reason: 'RGBA pixels, not a saved file');
    final out = await preparePhoto(square);
    final back = img.decodeJpg(out.jpeg)!;
    expect((back.width, back.height), (storedLongSide, storedLongSide));
    final direct = measureImage(img.copyCrop(big, x: 100, y: 50, width: 900, height: 900));
    expect((out.measured.lab.l - direct.lab.l).abs(), lessThanOrEqualTo(0.2));
    expect((out.measured.lab.a - direct.lab.a).abs(), lessThanOrEqualTo(0.2));
    expect((out.measured.lab.b - direct.lab.b).abs(), lessThanOrEqualTo(0.2));
    expect(out.measured.name, direct.name);
    final again = measureBytes(out.jpeg);
    expect((again.lab.l - out.measured.lab.l).abs(), lessThanOrEqualTo(0.6 + 1e-9));
  });

  test('a photo longer than 2560 px is shrunk to 2560 px by the browser, its numbers as they were, and the cropper is '
      'shown that picture at 1200 px', () async {
    final big = img.Image(width: 3200, height: 2000)..clear(img.ColorRgb8(200, 60, 40));
    final photo = await readPhoto(img.encodePng(big));
    expect((photo.width, photo.height), (2560, 1600));
    final shown = img.decodeJpg(photo.bytes)!;
    expect((shown.width, shown.height), (1200, 750), reason: 'shown smaller, in the shape of the picture it cuts from');
    final square = await PhotoCropper(photo.picture).call(original: null, topLeft: Offset.zero,
        bottomRight: const Offset(1600, 1600));
    expect(square.sublist(0, 4), [200, 60, 40, 255], reason: 'the file\'s own numbers, not converted');
    photo.close();
  });

  test('a see-through picture is stored with the RGB the measure read: measured again within 0.6 and by the same name',
      () async {
    final picked = base64Decode(g.pictures['alpha.png']!);
    final photo = await readPhoto(picked);
    final square = await PhotoCropper(photo.picture).call(original: null, topLeft: Offset.zero,
        bottomRight: Offset(photo.width.toDouble(), photo.height.toDouble()));
    final out = await preparePhoto(square);
    final again = measureBytes(out.jpeg);
    expect((again.lab.l - out.measured.lab.l).abs(), lessThanOrEqualTo(0.6 + 1e-9), reason: 'L*');
    expect((again.lab.a - out.measured.lab.a).abs(), lessThanOrEqualTo(0.6 + 1e-9), reason: 'a*');
    expect((again.lab.b - out.measured.lab.b).abs(), lessThanOrEqualTo(0.6 + 1e-9), reason: 'b*');
    expect(again.name, out.measured.name);
    photo.close();
  });

  test('a stored JPEG of 600 px or less goes into a Share file as it is, known from its header: the browser does not read it',
      () async {
    var reads = 0;
    createBitmap = (source, options) {
      reads++;
      return browser(source, options);
    };
    final small = Uint8List.fromList(img.encodeJpg(img.Image(width: 600, height: 450)..clear(img.ColorRgb8(30, 120, 140))));
    expect(await smallerJpeg(small), same(small));
    expect(reads, 0);
    final larger = Uint8List.fromList(img.encodeJpg(img.Image(width: 1500, height: 1500)..clear(img.ColorRgb8(30, 120, 140))));
    expect(img.decodeJpg((await smallerJpeg(larger))!)!.width, 600);
    expect(reads, greaterThan(0), reason: 'one that must be made smaller is read');
  });

  test("a canvas's pixels are let go of once its JPEG is made", () async {
    final (canvas, context) = canvasOf(64, 48);
    context.fillRect(0, 0, 64, 48);
    expect(img.decodeJpg(await jpegOf(canvas, 80))!.width, 64);
    expect((canvas.width, canvas.height), (0, 0));
  });

  /* A picture `w` × `h` stored with EXIF orientation `turn`, its four quarters four colours, so that every turn and
     mirror reads differently; and how it looks upright, by the image package. */
  (Uint8List, img.Image) quarters(int w, int h, int turn) {
    final stored = img.Image(width: w, height: h);
    for (final p in stored) {
      final right = p.x >= w ~/ 2, low = p.y >= h ~/ 2;
      final (r, g, b) = switch ((right, low)) {
        (false, false) => (220, 30, 30),
        (true, false) => (30, 200, 30),
        (false, true) => (30, 30, 220),
        (true, true) => (230, 220, 30),
      };
      p..r = r..g = g..b = b;
    }
    stored.exif.imageIfd.orientation = turn;
    return (img.encodeJpg(stored, quality: 95), img.bakeOrientation(img.Image.from(stored)));
  }

  /* The colour of each quarter's middle, from RGBA pixels `w` wide. */
  List<(int, int, int)> middles(Uint8List rgba, int w, int h) => [
        for (final (fx, fy) in [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)])
          (() {
            final i = ((fy * h).floor() * w + (fx * w).floor()) * 4;
            return (rgba[i], rgba[i + 1], rgba[i + 2]);
          })(),
      ];
  bool near(List<(int, int, int)> a, List<(int, int, int)> b) => [
        for (var i = 0; i < a.length; i++)
          (a[i].$1 - b[i].$1).abs() < 40 && (a[i].$2 - b[i].$2).abs() < 40 && (a[i].$3 - b[i].$3).abs() < 40,
      ].every((x) => x);

  for (final turnsItself in [true, false]) {
    final kind = turnsItself ? 'turns the photo itself' : 'does not turn it';
    for (final (w, h, turn) in [(64, 32, 2), (64, 32, 3), (64, 32, 4), (64, 32, 6), (64, 64, 6), (64, 64, 3)]) {
      test('a browser that refuses from-image and $kind: a $w × $h photo with EXIF $turn is read upright, once', () async {
        if (turnsItself) {
          createBitmap = (source, options) => options.getProperty<JSAny?>('imageOrientation'.toJS)?.dartify() == 'from-image'
              ? Future.error(TypeError())
              : browser(source, options);
        } else {
          olderBrowser({'imageOrientation': 'from-image'});
        }
        expect((await bitmapOptions()).upright, turnsItself, reason: 'found by the probe, not by the photo\'s shape');
        final (picked, upright) = quarters(w, h, turn);
        final photo = await readPhoto(picked);
        expect((photo.width, photo.height), (upright.width, upright.height));
        final (canvas, context) = canvasOf(photo.width, photo.height);
        context.drawImage(photo.picture as web.ImageBitmap, 0, 0);
        final read = context.getImageData(0, 0, photo.width, photo.height).data.toDart.buffer.asUint8List();
        final expected = middles(upright.getBytes(order: img.ChannelOrder.rgba), upright.width, upright.height);
        expect(near(middles(read, photo.width, photo.height), expected), isTrue,
            reason: 'read ${middles(read, photo.width, photo.height)}, upright $expected');
        final shown = img.decodeJpg(photo.bytes)!;
        expect(near(middles(shown.getBytes(order: img.ChannelOrder.rgba), shown.width, shown.height), expected), isTrue,
            reason: 'the cropper is shown it the same way up');
        photo.close();
      });
    }
  }

  test('a browser that neither resizes nor turns: a photo past 2560 px is brought down first, then turned', () async {
    olderBrowser({'imageOrientation': 'from-image'});
    final inner = createBitmap;
    createBitmap = (source, options) {
      options..delete('resizeWidth'.toJS)..delete('resizeHeight'.toJS)..delete('resizeQuality'.toJS);
      return inner(source, options);
    };
    final (picked, upright) = quarters(3200, 2000, 6);
    final photo = await readPhoto(picked);
    expect((photo.width, photo.height), (1600, 2560));
    final (canvas, context) = canvasOf(photo.width, photo.height);
    context.drawImage(photo.picture as web.ImageBitmap, 0, 0);
    final read = context.getImageData(0, 0, photo.width, photo.height).data.toDart.buffer.asUint8List();
    expect(near(middles(read, 1600, 2560), middles(upright.getBytes(order: img.ChannelOrder.rgba), 2000, 3200)), isTrue);
    photo.close();
  });

  test('a Share file is made by the browser inside 600 px; a small JPEG goes as it is', () async {
    final stored = Uint8List.fromList(img.encodeJpg(img.Image(width: 1500, height: 1500)..clear(img.ColorRgb8(30, 120, 140))));
    final out = img.decodeJpg((await smallerJpeg(stored))!)!;
    expect((out.width, out.height), (600, 600));
    final small = Uint8List.fromList(img.encodeJpg(img.Image(width: 300, height: 300)));
    expect(await smallerJpeg(small), small);
    expect(await smallerJpeg(Uint8List.fromList(List.filled(64, 7))), isNull);
  });
}

/* A JPEG without its EXIF block (APP1), as a browser that ignored EXIF read it. */
Uint8List _withoutExif(Uint8List jpeg) {
  final out = BytesBuilder()..add(jpeg.sublist(0, 2));
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xFF && jpeg[i + 1] != 0xDA) {
    final length = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (jpeg[i + 1] != 0xE1) out.add(jpeg.sublist(i, i + 2 + length));
    i += 2 + length;
  }
  out.add(jpeg.sublist(i));
  return out.toBytes();
}
