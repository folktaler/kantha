/* A photo on its way to becoming a cloth: checked and read once before the cropper sees it, then — once
   cropped — measured, sized and stored. On a phone the image package does the work in an isolate (compute);
   on the web the browser's own codecs read, crop, size and save the picture (prepare_web.dart), and only the
   colour measure runs in Dart. The picture is read once: the cropper is handed its size (PickedPhoto.parser) and the
   picture itself (PhotoCropper),
   and hands its square on without saving it as a JPEG first (PhotoCropper). */
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../measure/measure.dart' show MeasureError;
import 'jpeg_size.dart';

export 'prepare_io.dart' if (dart.library.js_interop) 'prepare_web.dart';
import 'prepare_io.dart' if (dart.library.js_interop) 'prepare_web.dart' as platform;

/* The long side a cloth photo is stored at: ≤ 600 px (his decision, 20 Oct, replacing 1500 px of 6 Oct). The colour
   and the print/plain reading hold at 600 px (2 of the 47 start photos change at 400 px), and the files embed 600 px
   (embedPx). To change it, change this one number. Photos stored before keep the size they were stored at. */
const storedLongSide = 600;
/* Stored as JPEG at this quality (his decision, 20 Oct, replacing quality 90 of 6 Oct). */
const storedJpegQuality = 80;

/* A picked photo, read once: its bytes as picked (the cropper shows them), its upright size, and the
   picture itself as this platform read it (an image package Image on a phone, the browser's ImageBitmap
   on the web). */
class PickedPhoto {
  PickedPhoto(this.bytes, this.width, this.height, this.picture);
  final Uint8List bytes;
  final int width, height;
  final Object picture;

  /* Lets go of the picture: on the web the browser's ImageBitmap is closed (it holds the decoded pixels, about
     20 MB for a 2560 × 1920 photo, until then); on a phone nothing is held outside Dart. Not used after. */
  void close() => platform.closePicture(picture);

  /* crop_your_image's imageParser: the picture's size only, so the cropper reads nothing again. It runs the parser
     through compute, which on a phone copies all the parser holds into another isolate and back: it holds two
     numbers, not the picture. The picture reaches the cut through PhotoCropper(picture). The same parser for the
     photo's life: the cropper reads the picture again whenever it is handed another. */
  late final ImageParser parser = _sized(width, height);
}

/* A parser that knows the size and nothing else (a closure over two numbers, not over a PickedPhoto). */
ImageParser _sized(int width, int height) =>
    (_, {inputFormat}) => ImageDetail<Object?>(image: null, width: width.toDouble(), height: height.toDouble());

/* The most pixels a picked photo may have, on a phone and on the web alike, so that reading it stays within about
   300 MB on a phone with 2 GB. Measured on 20 Oct in the Dart VM on this Mac, peak memory above the start:
   - A JPEG is read by the phone's own decoder straight at about 4000 px (prepare_io.dart), so its size hardly
     matters: 12 MP 161 MB, 48 MP 169 MB, 108 MP 255 MB. 52 MP takes every 48 and 50 MP photo (8000 × 6000,
     8160 × 6144) and refuses a 64 MP one or larger, which the web would decode whole on a browser that does not
     know the resize options.
   - Any other picture is decoded whole first (a PNG by the phone's decoder: 48 MP 353 MB, 108 MP 571 MB; one that
     decoder cannot read, by the image package in Dart: 48 MP 369 MB as a PNG), so 30 MP. */
const jpegPixelLimit = 52 * 1000 * 1000, otherPixelLimit = 30 * 1000 * 1000;

/* Before anything reads a picked photo: one whose header the image package can read. Reads the header only, so an
   unreadable file (a HEIC, a file that is not a picture) is refused before her first box is made for it. Throws
   MeasureError('notAnImage'). Past jpegPixelLimit for a JPEG, or otherPixelLimit for any other picture,
   MeasureError('pixelLimit'). */
void checkPicked(Uint8List picked) {
  final jpeg = jpegSize(picked);
  final size = jpeg ?? pickedSize(picked);
  if (size == null || size.width == 0 || size.height == 0) throw const MeasureError('notAnImage');
  if (size.width * size.height > (jpeg != null ? jpegPixelLimit : otherPixelLimit)) throw const MeasureError('pixelLimit');
}

/* The size a picked photo's header names, as stored (before any EXIF turn); null when the image package cannot read
   the header, or it names no pixels. */
({int width, int height})? pickedSize(Uint8List picked) {
  final jpeg = jpegSize(picked);
  if (jpeg != null) return jpeg.width == 0 || jpeg.height == 0 ? null : jpeg;
  final decoder = img.findDecoderForData(picked);
  if (decoder == null) return null;
  try {
    final info = decoder.startDecode(picked);
    if (info == null || info.width == 0 || info.height == 0) return null;
    return (width: info.width, height: info.height);
  } on Object { // the package throws RangeError and others, not only ImageException, on a broken file
    return null;
  }
}

/* crop_your_image's formatDetector: PhotoCropper does not use the format, so nothing is read to find it. */
ImageFormat photoFormat(Uint8List _) => ImageFormat.bmp;
