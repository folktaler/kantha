import 'dart:math' as math;

/* The width and height of a w × h picture brought down to `long` px on its long side; as it is when not longer. One
   rounding for a picked photo on the phone and in the browser, so both make a picture the same size, and for the
   browser's photos in the files. The phone's photos in the files are sized by the image package's own rounding
   (smaller_io.dart). */
({int width, int height}) longSideSize(int w, int h, int long) {
  final scale = long / math.max(w, h);
  return scale >= 1 ? (width: w, height: h) : (width: math.max(1, (w * scale).round()), height: math.max(1, (h * scale).round()));
}
