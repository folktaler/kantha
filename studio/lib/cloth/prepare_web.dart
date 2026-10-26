/* prepare.dart on the web: the browser reads, crops, sizes and saves the picture (platform/canvas_web.dart); the
   colour is measured in Dart from the crop's own pixels, by the same measureImage as on a phone. */
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;
import '../measure/measure.dart';
import '../platform/canvas_web.dart';
import 'long_side.dart';
import 'photo_source.dart' show pickedLongSide, previewLongSide;
import '../solver/geometry.dart' show maxLongSide;
import 'prepare.dart' show PickedPhoto, pickedSize, storedJpegQuality, storedLongSide;

/* PickedPhoto.close: the browser's decoded bitmap freed now. */
void closePicture(Object picture) => (picture as web.ImageBitmap).close();

/* After checkPicked, which refuses a photo past the phone's limits before the browser is asked to read it (a browser
   that does not know the resize options decodes it whole): the picture read once, by the browser, with the file's own
   colour numbers (readInBrowser), and decoded straight at pickedLongSide on its long side when it is longer (the
   browser's 'high' resize, to the size its header names, brought down as on a phone), so a 48 MP photo is never held
   whole. Upright by its EXIF: by the browser where it turns it
   (bitmapOptions' upright), else turned here by the image package. A browser that does not know the resize options
   gives it whole, and it is brought down on a canvas, before any turn here. One the browser cannot read is
   MeasureError('notAnImage'). One whose header the image package cannot read (only a file not checked first: Fix
   cloth's stored photo) is read whole, and refused with MeasureError('pixelLimit') past the measure's limit
   (2500 × 2500 × 4). The cropper is shown the bytes as picked, or, for a picture brought down or turned, that picture
   at previewLongSide as a JPEG with no EXIF; it lays it out by the size of the picture it cuts from. */
Future<PickedPhoto> readPhoto(Uint8List picked) async {
  final size = pickedSize(picked), turn = _exifTurn(picked), takes = await bitmapOptions();
  // The size it is asked to come out at: upright, when the browser turns it before it resizes.
  int? width, height;
  if (size != null) {
    final swap = takes.upright && turn >= 5;
    final w = swap ? size.height : size.width, h = swap ? size.width : size.height;
    if (math.max(w, h) > pickedLongSide) (:width, :height) = longSideSize(w, h, pickedLongSide);
  }
  web.ImageBitmap picture;
  try {
    picture = await readInBrowser(picked, width: width, height: height);
  } on Object {
    throw const MeasureError('notAnImage');
  }
  if (picture.width == 0 || picture.height == 0) {
    picture.close();
    throw const MeasureError('notAnImage');
  }
  if (size == null && picture.width * picture.height > maxLongSide * maxLongSide * 4) {
    picture.close();
    throw const MeasureError('pixelLimit');
  }
  try {
    // Brought down first, so a photo the browser gave whole is turned at 2560 px, not at its own size.
    final whole = math.max(picture.width, picture.height) > pickedLongSide;
    if (whole) picture = await _shrunk(picture);
    if (turn != 1 && !takes.upright) picture = await _turned(picture, turn);
    if (!whole && width == null && height == null && turn == 1) {
      return PickedPhoto(picked, picture.width, picture.height, picture);
    }
    // The cropper shows Flutter's own reading of the bytes it is given and cuts from the browser's picture; for a photo
    // turned by its EXIF the two can disagree on which way is up, and a photo brought down would be read whole to be
    // shown. It is shown the picture it cuts from, smaller, as a JPEG with no EXIF instead, so what she frames is what
    // is cut.
    return PickedPhoto(await _preview(picture), picture.width, picture.height, picture);
  } on Object {
    picture.close();
    throw const MeasureError('notAnImage');
  }
}

/* The picture at previewLongSide on its long side (as it is, when shorter), as a JPEG. */
Future<Uint8List> _preview(web.ImageBitmap picture) {
  final w = picture.width, h = picture.height;
  final (width: pw, height: ph) = longSideSize(w, h, previewLongSide);
  final (canvas, context) = canvasOf(pw, ph);
  context.drawImage(picture, 0, 0, w, h, 0, 0, pw, ph);
  return jpegOf(canvas, 92);
}

/* The picture turned upright by its EXIF orientation `turn`, by the image package (its bakeOrientation), for a browser
   that does not turn it itself. The picture handed in is closed. */
Future<web.ImageBitmap> _turned(web.ImageBitmap picture, int turn) async {
  final w = picture.width, h = picture.height;
  final (read, context) = canvasOf(w, h);
  context.drawImage(picture, 0, 0);
  picture.close();
  final pixels = context.getImageData(0, 0, w, h).data.toDart;
  release(read);
  final stored = img.Image.fromBytes(width: w, height: h, bytes: pixels.buffer, bytesOffset: pixels.offsetInBytes,
      numChannels: 4)..exif.imageIfd.orientation = turn;
  final upright = img.bakeOrientation(stored);
  final (canvas, uprightContext) = canvasOf(upright.width, upright.height);
  uprightContext.putImageData(
      web.ImageData(Uint8ClampedList.sublistView(upright.toUint8List()).toJS, upright.width, upright.height.toJS), 0, 0);
  try {
    return await web.window.createImageBitmap(canvas).toDart;
  } finally {
    release(canvas);
  }
}

/* The picture brought down to pickedLongSide on its long side, on a canvas, for a browser that gave it whole. Drawn
   from the bitmap readInBrowser made, so its numbers are the file's own, unconverted; the picture handed in is closed. */
Future<web.ImageBitmap> _shrunk(web.ImageBitmap picture) async {
  final w = picture.width, h = picture.height;
  final (width: sw, height: sh) = longSideSize(w, h, pickedLongSide);
  final (canvas, context) = canvasOf(sw, sh);
  context.drawImage(picture, 0, 0, w, h, 0, 0, sw, sh);
  picture.close();
  try {
    return await web.window.createImageBitmap(canvas).toDart;
  } finally {
    release(canvas);
  }
}

/* The EXIF orientation a JPEG names, 1 (upright) when it names none. The EXIF block sits at the file's start, so only
   its first 128 KB are read. */
int _exifTurn(Uint8List picked) {
  try {
    final o = img.decodeJpgExif(Uint8List.sublistView(picked, 0, math.min(picked.length, 128 << 10)))?.imageIfd.orientation;
    return o != null && o >= 1 && o <= 8 ? o : 1;
  } on Object {
    return 1;
  }
}

/* crop_your_image's imageCropper: the square cut from the browser's picture on a canvas, handed on as its RGBA
   pixels, a side × side square (the cropper's square can come out a pixel off; the shorter side is kept),
   rather than saved as the package's quality-100 JPEG and read again. The picture is held here, as on a phone. */
class PhotoCropper extends ImageCropper<Object?> {
  PhotoCropper(Object picture) : _picture = picture as web.ImageBitmap;
  final web.ImageBitmap _picture;

  @override
  RectCropper<Object?> get rectCropper =>
      (_, {required topLeft, required size, required outputFormat}) => _rgbaSquare(_picture, topLeft: topLeft, size: size);

  @override
  CircleCropper<Object?> get circleCropper =>
      (_, {required center, required radius, required outputFormat}) => throw UnsupportedError('the studio crops square');

  /* The cropper keeps its square inside the picture; a canvas draws what lies outside a picture as clear. */
  @override
  RectValidator<Object?> get rectValidator => (_, _, _) => null;
}

Uint8List _rgbaSquare(web.ImageBitmap original, {required Offset topLeft, required Size size}) {
  final x = topLeft.dx.toInt(), y = topLeft.dy.toInt(), side = math.max(1, math.min(size.width.toInt(), size.height.toInt()));
  final (canvas, context) = canvasOf(side, side);
  context.drawImage(original, x, y, side, side, 0, 0, side, side);
  final pixels = context.getImageData(0, 0, side, side).data.toDart.buffer.asUint8List();
  release(canvas);
  return pixels;
}

/* The cropped square (PhotoCropper's RGBA pixels), measured by measureImage — from the crop at its own
   resolution (measureImage brings anything past 2500 px down first) — then brought down to storedLongSide by the
   browser and stored as JPEG, which carries no EXIF — no place, no camera. */
Future<({Uint8List jpeg, Measured measured})> preparePhoto(Uint8List cropped) async {
  final side = math.sqrt(cropped.length / 4).round();
  if (side == 0 || side * side * 4 != cropped.length) throw const MeasureError('notAnImage');
  final measured = measureImage(img.Image.fromBytes(width: side, height: side, bytes: cropped.buffer,
      bytesOffset: cropped.offsetInBytes, numChannels: 4));
  // What is stored is the RGB the measure read, as on a phone: a see-through pixel drawn as it is would come out of
  // the JPEG black, and read as another colour when measured again. So every pixel is made solid, its RGB kept.
  final solid = Uint8List.fromList(cropped);
  for (var i = 3; i < solid.length; i += 4) {
    solid[i] = 255;
  }
  final (whole, wholeContext) = canvasOf(side, side);
  wholeContext.putImageData(web.ImageData(Uint8ClampedList.sublistView(solid).toJS, side, side.toJS), 0, 0);
  final n = longSideSize(side, side, storedLongSide).width;
  if (n == side) return (jpeg: await jpegOf(whole, storedJpegQuality), measured: measured);
  final (stored, storedContext) = canvasOf(n, n);
  storedContext.drawImage(whole, 0, 0, side, side, 0, 0, n, n);
  release(whole);
  return (jpeg: await jpegOf(stored, storedJpegQuality), measured: measured);
}
