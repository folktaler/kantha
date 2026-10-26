/* cloth_images.dart on the web: the browser reads, sizes and saves the photo (platform/canvas_web.dart), so making
   the files does not hold the page still. */
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../cloth/jpeg_size.dart';
import '../cloth/long_side.dart';
import '../platform/canvas_web.dart';
import 'cloth_images.dart' show embedPx;

/* The photo inside 600 × 600, as JPEG at quality 85; a JPEG already that small as it was, known
   from its header without reading the picture. A see-through picture is set on the cloth's base, as sharp's flatten
   put it. Null when the browser cannot read it. */
Future<Uint8List?> smallerJpeg(Uint8List bytes) async {
  final size = jpegSize(bytes);
  if (size != null && size.width > 0 && size.height > 0 && size.width <= embedPx && size.height <= embedPx) return bytes;
  final web.ImageBitmap picture;
  try {
    picture = await readInBrowser(bytes);
  } on Object {
    return null;
  }
  final w = picture.width, h = picture.height;
  final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  if (w <= embedPx && h <= embedPx && isJpeg) {
    picture.close();
    return bytes;
  }
  final (width: fw, height: fh) = longSideSize(w, h, embedPx);
  final (canvas, context) = canvasOf(fw, fh);
  context
    ..fillStyle = '#EAE5D5'.toJS
    ..fillRect(0, 0, fw, fh)
    ..drawImage(picture, 0, 0, w, h, 0, 0, fw, fh);
  picture.close();
  return jpegOf(canvas, 85);
}
