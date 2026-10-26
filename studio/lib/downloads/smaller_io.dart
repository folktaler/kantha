/* cloth_images.dart on a phone (and in the Dart VM's tests): the image package, in an isolate. */
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../cloth/jpeg_size.dart';
import 'cloth_images.dart' show embedPx;

/* A JPEG already inside 600 × 600 as it was, known from its header (jpegSize), without the image package's slower
   header read or a copy to another isolate; any other made smaller off the screen's thread. */
Future<Uint8List?> smallerJpeg(Uint8List bytes) {
  final size = jpegSize(bytes);
  if (size != null && size.width > 0 && size.height > 0 && size.width <= embedPx && size.height <= embedPx) {
    return Future.value(bytes);
  }
  return compute(_smaller, bytes);
}

/* The photo inside 600 × 600, as JPEG at quality 85; one already that small as it was. */
Uint8List? _smaller(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final photo = decoder?.decode(bytes);
  if (photo == null) return null;
  if (photo.width <= embedPx && photo.height <= embedPx && decoder is img.JpegDecoder) return bytes;
  final wide = photo.width >= photo.height;
  final fitted = photo.width <= embedPx && photo.height <= embedPx
      ? photo
      : img.copyResize(photo, width: wide ? embedPx : null, height: wide ? null : embedPx, interpolation: img.Interpolation.average);
  // A see-through picture on the cloth's base, as sharp's flatten put it.
  final flat = !fitted.hasAlpha
      ? fitted
      : img.compositeImage(img.Image(width: fitted.width, height: fitted.height)..clear(img.ColorRgb8(0xEA, 0xE5, 0xD5)), fitted);
  return img.encodeJpg(flat, quality: 85);
}
