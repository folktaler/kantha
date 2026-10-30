/* The cropper of Add a piece and Fix this cloth: the picture
   in a 300 px stage, a square over it that she moves and sizes, starting at `coverage` of
   the picture (cropperjs's initial-coverage); under it the hint. The card asks for the square through
   controller.crop(); the cropped square comes back through onCropped, for preparePhoto. The cropper is handed the
   picture readPhoto already read, and does not read it again. The square stays inside the
   picture. The stage is square-cornered in the phone's colours and the hint is the
   phone's note. */
import 'dart:math' as math;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../studio/phone/phone_theme.dart';
import 'parts.dart';
import 'prepare.dart';

/* cropperjs's selection: a 1 px blue outline, its grid in thirds, and a small square handle at each corner. */
const _cropperBlue = Color(0xFF3399FF);

class CropStep extends StatelessWidget {
  const CropStep({super.key, required this.photo, required this.controller, required this.coverage, required this.hint,
      required this.onCropped, required this.onReady, this.onTouched, this.start});

  /* null while the picture is still being read: the stage is shown empty. */
  final PickedPhoto? photo;
  final CropController controller;
  final double coverage;
  final String hint;
  final ValueChanged<CropResult> onCropped;
  /* The picture is read and the square is on it: a crop may be asked for. */
  final VoidCallback onReady;
  /* She pressed on it, or turned the wheel over it: the square may have moved. */
  final VoidCallback? onTouched;
  /* Where the square starts, in the picture's own pixels (the one piece the finder found), instead of `coverage`. */
  final Rect? start;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Listener(
          onPointerDown: (_) => onTouched?.call(),
          onPointerSignal: (_) => onTouched?.call(),
          child: Container(
            key: const ValueKey('crop-stage'),
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: PhonePalette.canvas, border: Border.all(color: PhonePalette.border)),
            child: photo == null ? null : Crop(
              image: photo!.bytes,
              imageParser: photo!.parser,
              formatDetector: photoFormat,
              imageCropper: PhotoCropper(photo!.picture),
              controller: controller,
              aspectRatio: 1,
              initialRectBuilder: InitialRectBuilder.withBuilder((stage, picture) => start == null
                  ? startingSquare(stage, picture, coverage)
                  : placedSquare(picture, start!, photo!.width)),
              onCropped: onCropped,
              onStatusChanged: (s) { if (s == CropStatus.ready) onReady(); },
              baseColor: PhonePalette.canvas,
              // <cropper-shade hidden>: nothing is dimmed outside the square.
              maskColor: const Color(0x00000000),
              overlayBuilder: (context, rect) => const CustomPaint(key: ValueKey('crop-square'), painter: _SelectionPainter()),
              cornerDotBuilder: (size, edge) => SizedBox(width: size, height: size,
                  child: const Center(child: SizedBox(width: 5, height: 5, child: ColoredBox(color: _cropperBlue)))),
            ),
          ),
        ),
        const SizedBox(height: 8),
        cardHint(hint),
      ]);
}

/* cropperjs's initial-coverage: the square starts at `coverage` of the stage's shorter side,
   in its middle — kept inside the picture, so never larger than the picture's shorter side. */
Rect startingSquare(Rect stage, Rect picture, double coverage) {
  final side = math.min(math.min(stage.width, stage.height) * coverage, math.min(picture.width, picture.height));
  final x = (stage.center.dx - side / 2).clamp(picture.left, picture.right - side);
  final y = (stage.center.dy - side / 2).clamp(picture.top, picture.bottom - side);
  return Rect.fromLTWH(x, y, side, side);
}

/* `start` (the picture's pixels, `width` across) on the picture as the stage shows it, made square on its mean side
   and kept inside the picture. */
Rect placedSquare(Rect picture, Rect start, int width) {
  final k = picture.width / width;
  final side = math.min((start.width + start.height) / 2 * k, math.min(picture.width, picture.height));
  final c = picture.topLeft + start.center * k;
  final x = (c.dx - side / 2).clamp(picture.left, picture.right - side);
  final y = (c.dy - side / 2).clamp(picture.top, picture.bottom - side);
  return Rect.fromLTWH(x, y, side, side);
}

/* <cropper-selection> with <cropper-grid bordered covered>: the outline and the thirds. */
class _SelectionPainter extends CustomPainter {
  const _SelectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x80EEEEEE)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3, y = size.height * i / 3;
      _dashed(canvas, Offset(x, 0), Offset(x, size.height), grid);
      _dashed(canvas, Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawRect(Offset.zero & size, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _cropperBlue);
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final d = b - a, n = (d.distance / 6).floor();
    for (var i = 0; i < n; i += 2) {
      canvas.drawLine(a + d * (i / n), a + d * ((i + 1) / n), p);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => false;
}
