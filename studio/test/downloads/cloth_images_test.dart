import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/downloads/cloth_images.dart';
import 'package:kantha_studio/studio/shelf_feed.dart';

ClothView cloth(Uint8List bytes, {String id = 'C-1', int version = 1}) => ClothView(id: id, name: id, lab: (l: 50, a: 0, b: 0),
    busy: null, edge: null, grain: null, stock: 1, box: 1, fabric: 'Cotton', image: MemoryImage(bytes), version: version);

Uint8List jpeg(int w, int h) =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)..clear(img.ColorRgb8(30, 120, 140)), quality: 90));

void main() {
  test('a photo stored at 1500 px (as before 20 Oct) is made 600 px on its long side', () async {
    final out = img.decodeJpg((await ClothImages().jpeg(cloth(jpeg(1500, 1000))))!)!;
    expect((out.width, out.height), (600, 400));
  });

  test('a JPEG already within 600 px is passed as it is', () async {
    final small = jpeg(300, 300);
    expect(await ClothImages().jpeg(cloth(small)), small);
  });

  test('a see-through picture is set on the cloth base', () async {
    final clear = Uint8List.fromList(img.encodePng(img.Image(width: 50, height: 50, numChannels: 4)..clear(img.ColorRgba8(0, 0, 0, 0))));
    final out = img.decodeJpg((await ClothImages().jpeg(cloth(clear)))!)!;
    final p = out.getPixel(25, 25);
    expect([p.r, p.g, p.b].map((v) => v.toInt()).toList(), [for (final v in [0xEA, 0xE5, 0xD5]) closeTo(v, 3)]);
  });

  test('kept by id and version: asked again, the same; a new version, made again', () async {
    final images = ClothImages(), bytes = jpeg(800, 800);
    final a = images.jpeg(cloth(bytes)), b = images.jpeg(cloth(bytes));
    expect(identical(a, b), isTrue);
    expect(identical(images.jpeg(cloth(bytes, version: 2)), a), isFalse);
    expect(identical(await a, await b), isTrue);
  });

  test('cleared (after an import), a photo is made again', () async {
    final images = ClothImages(), view = cloth(jpeg(800, 800));
    final a = images.jpeg(view);
    await a;
    images.clear();
    expect(identical(images.jpeg(view), a), isFalse);
  });

  test('a photo that cannot be read is null, and is not kept: asked again, it is tried again', () async {
    final images = ClothImages(), junk = cloth(Uint8List.fromList(List.filled(64, 7)));
    final first = images.jpeg(junk);
    expect(await first, isNull);
    final second = images.jpeg(junk);
    expect(identical(first, second), isFalse);
    expect(await second, isNull);
  });
}
