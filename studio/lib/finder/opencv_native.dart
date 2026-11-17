/* FinderCv on opencv_dart (dartcv4, OpenCV built for the phone by its build hook with the modules pubspec.yaml names),
   for the finder's isolate on a phone (lib/cloth/piece_finder_io.dart). The same OpenCV functions as opencv_js.dart,
   with the options OpenCV.js uses where opencv_dart's own defaults differ: the line detector made with OpenCV's own
   defaults, and the morphology border (morphologyDefaultBorderValue, so the picture's edge changes nothing).
   Every Mat made here is OpenCV's memory and is disposed by its owner; a typed list read from one is a copy. */
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'cv.dart';

class _NativeMat implements CvMat {
  _NativeMat(this.m);
  final cv.Mat m;
  @override
  int get rows => m.rows;
  @override
  int get cols => m.cols;
  @override
  void dispose() => m.dispose();
}

class _NativeContours implements CvContours {
  _NativeContours(this._v, this._hierarchy) : length = _v.length;
  final cv.Contours _v;
  final cv.VecVec4i _hierarchy;
  @override
  final int length;

  @override
  Int32List points(int i) => _ints(_v[i]);
  @override
  double arcLength(int i) => cv.arcLength(_v[i], true);
  @override
  Int32List approxPolyDP(int i, double epsilon) {
    final out = cv.approxPolyDP(_v[i], epsilon, true);
    final p = _ints(out);
    out.dispose();
    return p;
  }

  @override
  void dispose() {
    _hierarchy.dispose();
    _v.dispose();
  }
}

/// A point list's x, y pairs, copied out of OpenCV.
Int32List _ints(cv.VecPoint v) {
  if (v.isEmpty) return Int32List(0);
  final m = cv.Mat.fromVec(v);
  final out = _int32(m, 2 * v.length);
  m.dispose();
  return out;
}

/// The first [n] 32-bit integers of a continuous Mat, copied.
Int32List _int32(cv.Mat m, int n) {
  final d = m.data;
  return Int32List.fromList(Int32List.view(d.buffer, d.offsetInBytes, n));
}

cv.VecPoint _points(Int32List p) => cv.VecPoint.generate(p.length ~/ 2, (i) => cv.Point(p[2 * i], p[2 * i + 1]));

/// A 1 x n float Mat holding [values].
cv.Mat _floatRow(Float32List values) {
  final m = cv.Mat.create(rows: 1, cols: values.length, type: cv.MatType.CV_32FC1);
  final d = m.data;
  Float32List.view(d.buffer, d.offsetInBytes, values.length).setAll(0, values);
  return m;
}

class OpenCvNative implements FinderCv {
  /// OpenCV.js's border for dilate and morphologyEx; opencv_dart's default is 0.
  late final cv.Scalar _morphBorder = cv.morphologyDefaultBorderValue();

  cv.Mat _m(CvMat m) => (m as _NativeMat).m;
  CvMat _wrap(cv.Mat m) => _NativeMat(m);

  cv.Mat _filled(int width, int height, cv.MatType type, Uint8List bytes) {
    final m = cv.Mat.create(rows: height, cols: width, type: type);
    m.data.setAll(0, bytes);
    return m;
  }

  @override
  CvMat fromRgba(Uint8List rgba, int width, int height) => _wrap(_filled(width, height, cv.MatType.CV_8UC4, rgba));
  @override
  CvMat fromBytes(Uint8List bytes, int width, int height) => _wrap(_filled(width, height, cv.MatType.CV_8UC1, bytes));
  @override
  CvMat zeros(int width, int height) => _wrap(cv.Mat.zeros(height, width, cv.MatType.CV_8UC1));
  @override
  CvMat roi(CvMat m, int x, int y, int width, int height) => _wrap(_m(m).region(cv.Rect(x, y, width, height)));

  /// A part of a picture (roi) is not continuous: it is copied whole first.
  cv.Mat _continuous(cv.Mat m) => m.isContinuous ? m : m.clone();

  @override
  Uint8List bytes(CvMat m) {
    final c = _continuous(_m(m));
    final out = Uint8List.fromList(c.data);
    if (!identical(c, _m(m))) c.dispose();
    return out;
  }

  @override
  Float32List floats(CvMat m) {
    final c = _continuous(_m(m));
    final d = c.data;
    final out = Float32List.fromList(Float32List.view(d.buffer, d.offsetInBytes, d.lengthInBytes ~/ 4));
    if (!identical(c, _m(m))) c.dispose();
    return out;
  }

  @override
  CvMat resizeArea(CvMat m, double scale) =>
      _wrap(cv.resize(_m(m), (0, 0), fx: scale, fy: scale, interpolation: cv.INTER_AREA));
  @override
  CvMat gaussianBlur(CvMat m, int size) => _wrap(cv.gaussianBlur(_m(m), (size, size), 0));
  @override
  CvMat cvtColor(CvMat m, CvColour code) => _wrap(cv.cvtColor(_m(m), switch (code) {
        CvColour.rgbaToBgr => cv.COLOR_RGBA2BGR,
        CvColour.bgrToLab => cv.COLOR_BGR2Lab,
        CvColour.bgrToGray => cv.COLOR_BGR2GRAY,
        CvColour.bgrToRgb => cv.COLOR_BGR2RGB,
        CvColour.bgrToRgba => cv.COLOR_BGR2RGBA,
      }));
  @override
  List<CvMat> split(CvMat m) {
    final v = cv.split(_m(m));
    final out = [for (var i = 0; i < v.length; i++) _wrap(v[i])];
    v.dispose();
    return out;
  }

  @override
  CvMat toFloat(CvMat m) => _wrap(_m(m).convertTo(cv.MatType.CV_32FC(_m(m).channels)));
  @override
  CvMat canny(CvMat m, double low, double high) => _wrap(cv.canny(_m(m), low, high));
  @override
  CvMat dilate(CvMat m) {
    final k = cv.Mat.empty(); // empty: the default 3 x 3
    final d = cv.dilate(_m(m), k, borderValue: _morphBorder);
    k.dispose();
    return _wrap(d);
  }

  @override
  CvMat dilateEllipse(CvMat m, int size) {
    final k = cv.getStructuringElement(cv.MORPH_ELLIPSE, (size, size));
    final d = cv.dilate(_m(m), k, borderValue: _morphBorder);
    k.dispose();
    return _wrap(d);
  }

  @override
  CvMat threshold(CvMat m, double t) => _wrap(cv.threshold(_m(m), t, 255, cv.THRESH_BINARY).$2);
  @override
  CvMat adaptiveThreshold(CvMat m, int blockSize) =>
      _wrap(cv.adaptiveThreshold(_m(m), 255, cv.ADAPTIVE_THRESH_MEAN_C, cv.THRESH_BINARY, blockSize, 0));
  @override
  CvMat open(CvMat m, int size) {
    final k = cv.Mat.ones(size, size, cv.MatType.CV_8UC1);
    final d = cv.morphologyEx(_m(m), cv.MORPH_OPEN, k, borderValue: _morphBorder);
    k.dispose();
    return _wrap(d);
  }

  @override
  CvMat sobel(CvMat m, int dx, int dy) => _wrap(cv.sobel(_m(m), cv.MatType.CV_32F, dx, dy));
  @override
  CvMat addWeighted(CvMat a, double alpha, CvMat b, double beta) =>
      _wrap(cv.addWeighted(_m(a), alpha, _m(b), beta, 0));
  @override
  CvMat magnitude(CvMat x, CvMat y) => _wrap(cv.magnitude(_m(x), _m(y)));

  @override
  CvContours findContours(CvMat binary) {
    final (contours, hierarchy) = cv.findContours(_m(binary), cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);
    return _NativeContours(contours, hierarchy);
  }

  @override
  double contourArea(Int32List points) {
    final v = _points(points);
    final a = cv.contourArea(v);
    v.dispose();
    return a;
  }

  @override
  bool isContourConvex(Int32List points) {
    final v = _points(points);
    final c = cv.isContourConvex(v);
    v.dispose();
    return c;
  }

  @override
  Int32List convexHull(Int32List points) {
    final v = _points(points);
    final hull = cv.convexHull(v);
    final out = hull.isEmpty ? Int32List(0) : _int32(hull, 2 * hull.rows);
    hull.dispose();
    v.dispose();
    return out;
  }

  @override
  Float32List lineSegments(CvMat gray) {
    // createLineSegmentDetector with OpenCV's own defaults, as OpenCV.js makes it (LSD_REFINE_STD among them).
    final lsd = cv.LineSegmentDetector.empty();
    final (lines, width, prec, nfa) = lsd.detect(_m(gray));
    final out = Float32List(4 * lines.length);
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      out[4 * i] = l.val1;
      out[4 * i + 1] = l.val2;
      out[4 * i + 2] = l.val3;
      out[4 * i + 3] = l.val4;
    }
    lines.dispose();
    width.dispose();
    prec.dispose();
    nfa.dispose();
    lsd.dispose();
    return out;
  }

  @override
  Int32List graphSegmentation(CvMat m, double sigma, double k, int minSize) {
    final gs = cv.GraphSegmentation.create(sigma: sigma, k: k, minSize: minSize);
    final d = gs.processImage(_m(m));
    final out = _int32(d, d.rows * d.cols);
    d.dispose();
    gs.dispose();
    return out;
  }

  @override
  void fillPoly(CvMat m, Int32List points, int value, {int dx = 0, int dy = 0}) {
    final v = _points(points);
    final vv = cv.VecVecPoint.fromVecPoint(v);
    final colour = cv.Scalar(value.toDouble(), 0, 0, 0), offset = cv.Point(-dx, -dy);
    cv.fillPoly(_m(m), vv, colour, lineType: cv.LINE_8, offset: offset);
    colour.dispose();
    offset.dispose();
    vv.dispose();
    v.dispose();
  }

  @override
  int countNonZero(CvMat m) => cv.countNonZero(_m(m));
  @override
  CvMat bitwiseAnd(CvMat a, CvMat b) => _wrap(cv.bitwiseAND(_m(a), _m(b)));
  @override
  CvMat bitwiseNot(CvMat m) => _wrap(cv.bitwiseNOT(_m(m)));

  @override
  Float32List calcHist(CvMat m, List<int> channels, CvMat? mask, int bins) {
    final images = cv.VecMat.fromList([_m(m)]), none = cv.Mat.empty();
    final chans = cv.VecI32.fromList(channels), sizes = cv.VecI32.fromList([for (final _ in channels) bins]);
    final ranges = cv.VecF32.fromList([for (final _ in channels) ...[0.0, 256.0]]);
    final hist = cv.calcHist(images, chans, mask == null ? none : _m(mask), sizes, ranges);
    final out = floats(_wrap(hist));
    hist.dispose();
    images.dispose();
    chans.dispose();
    sizes.dispose();
    ranges.dispose();
    none.dispose();
    return out;
  }

  @override
  double compareHistBhattacharyya(Float32List a, Float32List b) {
    final ma = _floatRow(a), mb = _floatRow(b);
    final d = cv.compareHist(ma, mb, method: cv.HISTCMP_BHATTACHARYYA);
    ma.dispose();
    mb.dispose();
    return d;
  }

  @override
  CvMat warpQuad(CvMat m, Float32List corners, int size) {
    final s = size.toDouble();
    const unit = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0];
    final src = cv.VecPoint2f.generate(4, (i) => cv.Point2f(corners[2 * i], corners[2 * i + 1]));
    final dst = cv.VecPoint2f.generate(4, (i) => cv.Point2f(unit[2 * i] * s, unit[2 * i + 1] * s));
    final t = cv.getPerspectiveTransform2f(src, dst);
    final out = cv.warpPerspective(_m(m), t, (size, size));
    t.dispose();
    src.dispose();
    dst.dispose();
    return _wrap(out);
  }
}
