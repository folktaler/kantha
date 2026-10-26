import 'dart:math' as math;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/crop_step.dart';
import 'package:kantha_studio/cloth/photo_source.dart' show previewLongSide;
import 'package:kantha_studio/cloth/prepare.dart';

/* Run on a phone's path here, and on the web's by crop_step_web_test.dart. */
void main() {
  testWidgets('the cropper shows a 1200 px picture and the square she frames on it is the square cut from the 2560 px one',
      (tester) async {
    // Each pixel's red and green name where it is: red across, green down.
    final big = img.Image(width: 4000, height: 3000);
    for (final p in big) {
      p..r = p.x * 255 ~/ 3999..g = p.y * 255 ~/ 2999..b = 90;
    }
    final photo = (await tester.runAsync(() => readPhoto(img.encodePng(big))))!;
    expect((photo.width, photo.height), (2560, 1920));
    final preview = img.decodeJpg(photo.bytes)!;
    expect((preview.width, preview.height), (previewLongSide, 900));

    final controller = CropController();
    var ready = false;
    CropResult? cut;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 360, child: CropStep(
      photo: photo, controller: controller, coverage: 0.5, hint: '',
      onCropped: (r) => cut = r, onReady: () => ready = true))))));
    for (var i = 0; i < 300 && !(ready && find.byKey(const ValueKey('crop-square')).evaluate().isNotEmpty); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(ready, isTrue);
    // She moves the square towards the top left.
    await tester.drag(find.byKey(const ValueKey('crop-square')), const Offset(-50, -40));
    await tester.pump();

    // What she sees: the square over the picture as drawn, read from the preview.
    final shown = tester.getRect(find.byType(Image).last), square = tester.getRect(find.byKey(const ValueKey('crop-square')));
    final scale = preview.width / shown.width;
    final framed = img.copyCrop(preview, x: ((square.left - shown.left) * scale).round(), y: ((square.top - shown.top) * scale).round(),
        width: (square.width * scale).round(), height: (square.height * scale).round());

    controller.crop();
    for (var i = 0; i < 300 && cut == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    // A phone's cropper hands on a BMP; the web's, the square's RGBA pixels.
    final bytes = (cut! as CropSuccess).croppedImage, side = math.sqrt(bytes.length / 4).round();
    final square2560 = kIsWeb
        ? img.Image.fromBytes(width: side, height: side, bytes: bytes.buffer, bytesOffset: bytes.offsetInBytes, numChannels: 4)
        : img.decodeImage(bytes)!;
    expect(square2560.width, closeTo(square.width * 2560 / shown.width, 2), reason: 'cut at the picture\'s own size');
    // The same place: the corners and the middle read alike in the framed preview and in the cut.
    for (final (fx, fy) in [(0.05, 0.05), (0.95, 0.05), (0.5, 0.5), (0.05, 0.95), (0.95, 0.95)]) {
      final a = framed.getPixel((fx * (framed.width - 1)).round(), (fy * (framed.height - 1)).round());
      final b = square2560.getPixel((fx * (square2560.width - 1)).round(), (fy * (square2560.height - 1)).round());
      expect(math.max((a.r - b.r).abs(), (a.g - b.g).abs()), lessThanOrEqualTo(3),
          reason: 'at ($fx, $fy): framed (${a.r}, ${a.g}), cut (${b.r}, ${b.g})');
    }
    expect(square2560.getPixel(0, 0).r, lessThan(120), reason: 'moved left of the middle');
  });
}
