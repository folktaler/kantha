/* The OpenCV calls the square finder makes, and nothing more. On the web they go to OpenCV.js
   (opencv_js.dart, in the finder's Web Worker); phones will put opencv_dart behind the same interface.
   Each call is one OpenCV function with the finder's own fixed options; the method itself is in
   find_squares.dart. A CvMat is OpenCV's memory, not Dart's: whoever makes one disposes it. */
import 'dart:typed_data';

/// An image held by the OpenCV binding.
abstract interface class CvMat {
  int get rows;
  int get cols;
  void dispose();
}

/// The colour conversions the finder uses.
enum CvColour { rgbaToBgr, bgrToLab, bgrToGray, bgrToRgb, bgrToRgba }

/// One findContours result. Points are x, y pairs, in the image the contours were found in.
abstract interface class CvContours {
  int get length;
  Int32List points(int i);
  double arcLength(int i);

  /// approxPolyDP on contour [i], closed.
  Int32List approxPolyDP(int i, double epsilon);
  void dispose();
}

abstract interface class FinderCv {
  /// 8-bit, 4 channels, from RGBA bytes.
  CvMat fromRgba(Uint8List rgba, int width, int height);

  /// 8-bit, 1 channel, from bytes.
  CvMat fromBytes(Uint8List bytes, int width, int height);

  /// 8-bit, 1 channel, all 0.
  CvMat zeros(int width, int height);

  /// A view of part of [m]; disposing it leaves [m].
  CvMat roi(CvMat m, int x, int y, int width, int height);

  Uint8List bytes(CvMat m);
  Float32List floats(CvMat m);

  /// resize by [scale] both ways, INTER_AREA.
  CvMat resizeArea(CvMat m, double scale);
  CvMat gaussianBlur(CvMat m, int size);
  CvMat cvtColor(CvMat m, CvColour code);
  List<CvMat> split(CvMat m);
  CvMat toFloat(CvMat m);
  CvMat canny(CvMat m, double low, double high);

  /// dilate with the default 3 x 3 kernel.
  CvMat dilate(CvMat m);

  /// dilate with getStructuringElement(MORPH_ELLIPSE, [size] x [size]): a band [size] ~/ 2 wide all round.
  CvMat dilateEllipse(CvMat m, int size);
  CvMat threshold(CvMat m, double t);

  /// ADAPTIVE_THRESH_MEAN_C, THRESH_BINARY, C 0.
  CvMat adaptiveThreshold(CvMat m, int blockSize);

  /// morphologyEx MORPH_OPEN with a size x size kernel of ones.
  CvMat open(CvMat m, int size);

  /// Sobel to 32-bit float, kernel 3.
  CvMat sobel(CvMat m, int dx, int dy);
  CvMat addWeighted(CvMat a, double alpha, CvMat b, double beta);
  CvMat magnitude(CvMat x, CvMat y);

  /// RETR_LIST, CHAIN_APPROX_SIMPLE.
  CvContours findContours(CvMat binary);
  double contourArea(Int32List points);
  bool isContourConvex(Int32List points);

  /// convexHull of [points] (x, y pairs), as points.
  Int32List convexHull(Int32List points);

  /// Line segments (x1, y1, x2, y2 each) from createLineSegmentDetector with its defaults.
  Float32List lineSegments(CvMat gray);

  /// Felzenszwalb's graph-based segmentation (ximgproc): one label per pixel.
  Int32List graphSegmentation(CvMat m, double sigma, double k, int minSize);

  /// fillPoly of one polygon, [points] moved by -[dx], -[dy].
  void fillPoly(CvMat m, Int32List points, int value, {int dx = 0, int dy = 0});
  int countNonZero(CvMat m);
  CvMat bitwiseAnd(CvMat a, CvMat b);
  CvMat bitwiseNot(CvMat m);

  /// calcHist of [channels] of [m] under [mask] (all of [m] when null), [bins] bins each over 0 to 256, flattened.
  Float32List calcHist(CvMat m, List<int> channels, CvMat? mask, int bins);
  double compareHistBhattacharyya(Float32List a, Float32List b);

  /// The quad [corners] (x0, y0 … x3, y3) straightened to a [size] x [size] square: getPerspectiveTransform and
  /// warpPerspective with their defaults (bilinear, black outside the picture). Corner 0 goes to the top left,
  /// then round in order.
  CvMat warpQuad(CvMat m, Float32List corners, int size);
}
