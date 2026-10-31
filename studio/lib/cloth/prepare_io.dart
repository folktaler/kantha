/* prepare.dart on a phone (and in the Dart VM's tests): the image package, in an isolate. */
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Size;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../measure/measure.dart';
import 'long_side.dart';
import 'photo_source.dart' show pickedLongSide, previewLongSide;
import 'prepare.dart' show PickedPhoto, storedJpegQuality, storedLongSide;

/* PickedPhoto.close: an image package Image is Dart memory, let go of with the photo. */
void closePicture(Object picture) {}

/* `picture` brought down to `long` px on its long side by the image package's area average; as it is when not longer. */
img.Image _averaged(img.Image picture, int long) {
  final size = longSideSize(picture.width, picture.height, long);
  return size.width == picture.width && size.height == picture.height ? picture
      : img.copyResize(picture, width: size.width, height: size.height, interpolation: img.Interpolation.average);
}

/* The long side the phone's own decoder (dart:ui) reads a picked photo at: a JPEG it decodes straight at a smaller
   size, by its own 1/8 steps and then bilinear, so a 48 MP photo is never held whole (169 MB at its peak, not 369 MB;
   checkPicked). The area average then brings it down to pickedLongSide. Measured on 20 Oct against the web on the
   striped photo: a 12 MP one reads as by the image package alone, within 0.2 of it; on a 48 MP one neither is inside
   the stripe limits, since the browser keeps the stripes' contrast, and 4000 px came as near the web as 5120 px did at
   half the memory (5120 px: 365 MB). */
const _platformLongSide = 4000;

/* After checkPicked: the whole picture read, upright, once, and brought down to pickedLongSide on its long side by the
   image package's area average, as the web's browser brings it down (prepare_web.dart), so the measure is handed the
   same pixels on both. The phone's own decoder reads it first, at _platformLongSide, upright by its EXIF; a picture
   that decoder cannot read is read whole by the image package. The area average runs in an isolate (compute). The
   picker is not asked to shrink it: image_picker_android shrinks by nearest pixel and saves it again at JPEG quality
   100. A photo brought down is shown to the cropper smaller still, at previewLongSide, as a JPEG, so the screen does
   not decode the whole photo to show it; the cut is from the picture.
   A file with a good header and a broken body (a garbled Huffman table, a scan that names components it does not
   have) passes the header read and fails here, so the card says so rather than waiting for a cropper that would never
   be ready.
   Throws MeasureError('notAnImage'). */
Future<PickedPhoto> readPhoto(Uint8List picked) async {
  final read = await compute(_read, await _platformRead(picked) ?? (pixels: picked, width: 0, height: 0));
  if (read == null) throw const MeasureError('notAnImage');
  return PickedPhoto(read.shown ?? picked, read.picture.width, read.picture.height, read.picture);
}

/* The picture as the phone's own decoder reads it, at no more than _platformLongSide on its long side: its RGBA
   pixels and size. Null when that decoder cannot read it. */
Future<({Uint8List pixels, int width, int height})?> _platformRead(Uint8List picked) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(picked);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = longSideSize(descriptor.width, descriptor.height, _platformLongSide);
    codec = await descriptor.instantiateCodec(targetWidth: size.width, targetHeight: size.height);
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return null;
    return (pixels: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), width: image.width, height: image.height);
  } on Object {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/* In the isolate: the pixels the phone's decoder read (width > 0), or else the file itself, read whole by the image
   package; then brought down to pickedLongSide, with its preview. */
({img.Image picture, Uint8List? shown})? _read(({Uint8List pixels, int width, int height}) given) {
  try {
    var picture = given.width > 0
        ? img.Image.fromBytes(width: given.width, height: given.height, bytes: given.pixels.buffer,
            bytesOffset: given.pixels.offsetInBytes, numChannels: 4)
        : img.decodeImage(given.pixels);
    if (picture == null) return null;
    // decodeJpg already turns a photo by its EXIF; this is for a picture whose decoder does not.
    final turn = picture.exif.imageIfd.orientation;
    if (turn != null && turn != 1) picture = img.bakeOrientation(picture);
    final smaller = math.max(picture.width, picture.height) > pickedLongSide;
    picture = _averaged(picture, pickedLongSide);
    return (picture: picture, shown: smaller ? img.encodeJpg(_averaged(picture, previewLongSide), quality: 92) : null);
  } on Object { // ImageException, RangeError and others from a broken body
    return null;
  }
}

/* crop_your_image's imageCropper: the square cut from the picture readPhoto read, handed on as BMP, which loses
   nothing and is quick to read again, rather than as the package's quality-100 JPEG. The picture is held here, not
   handed through the parser (PickedPhoto.parser), so it is copied to the crop's isolate once, when she crops. */
class PhotoCropper extends ImageCropper<Object?> {
  PhotoCropper(Object picture) : _picture = picture as img.Image;
  final img.Image _picture;

  @override
  RectCropper<Object?> get rectCropper =>
      (_, {required topLeft, required size, required outputFormat}) => _bmpSquare(_picture, topLeft: topLeft, size: size);

  @override
  CircleCropper<Object?> get circleCropper =>
      (_, {required center, required radius, required outputFormat}) => throw UnsupportedError('the studio crops square');

  @override
  RectValidator<Object?> get rectValidator => (_, topLeft, bottomRight) => defaultRectValidator(_picture, topLeft, bottomRight);
}

Uint8List _bmpSquare(img.Image original, {required Offset topLeft, required Size size}) =>
    img.encodeBmp(img.copyCrop(original, x: topLeft.dx.toInt(), y: topLeft.dy.toInt(),
        width: size.width.toInt(), height: size.height.toInt()));

/* The cropped square, upright, measured by measureImage — from the crop at its
   own resolution (measureImage brings anything past 2500 px down first) — then brought down
   to storedLongSide and stored as JPEG. What is stored is the plain 8-bit RGB the measure
   read: a grey or a see-through picture stored as it is would read as another colour when
   measured again. The stored file carries no EXIF — no place, no camera — as the old app's
   re-encoded PNG carried none. */
Future<({Uint8List jpeg, Measured measured})> preparePhoto(Uint8List cropped) => compute(_prepare, cropped);

({Uint8List jpeg, Measured measured}) _prepare(Uint8List cropped) {
  final decoded = img.decodeImage(cropped);
  if (decoded == null) throw const MeasureError('notAnImage');
  // decodeJpg already turns a photo by its EXIF; this is for a picture whose decoder does not.
  var upright = img.bakeOrientation(decoded);
  final measured = measureImage(upright);
  upright = _averaged(upright.convert(format: img.Format.uint8, numChannels: 3), storedLongSide);
  upright.exif = img.ExifData();
  return (jpeg: img.encodeJpg(upright, quality: storedJpegQuality), measured: measured);
}

/* A piece the finder cut (side × side RGBA pixels), measured and stored as preparePhoto does a cropped square. */
Future<({Uint8List jpeg, Measured measured})> preparePiece(Uint8List rgba) => compute(_preparePiece, rgba);

({Uint8List jpeg, Measured measured}) _preparePiece(Uint8List rgba) {
  final side = math.sqrt(rgba.length / 4).round();
  if (side == 0 || side * side * 4 != rgba.length) throw const MeasureError('notAnImage');
  return _prepare(img.encodeBmp(img.Image.fromBytes(width: side, height: side, bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes, numChannels: 4)));
}
