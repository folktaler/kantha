/* FinderCv on OpenCV.js (web/opencv_finder.js, built by tool/opencv_js/build.sh), for the finder's Web
   Worker. Every Mat made here is OpenCV's memory and is deleted by its owner; a typed list read from one
   is copied out of OpenCV's heap, which may move when it grows. */
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'cv.dart';

// OpenCV's constants, as numbered in its headers.
const _cv8U = 0, _cv8UC4 = 24, _cv32F = 5, _cv32FC2 = 13, _cv32SC2 = 12;
const _interArea = 3, _threshBinary = 0, _adaptiveMeanC = 0, _morphOpen = 2;
const _retrList = 1, _chainApproxSimple = 2, _histcmpBhattacharyya = 3;

extension type _OpenCv._(JSObject _) implements JSObject {
  @JS('Mat')
  external JSFunction get _mat;
  @JS('MatVector')
  external JSFunction get _matVector;
  @JS('LineSegmentDetector')
  external JSFunction get _lsd;
  @JS('ximgproc_segmentation_GraphSegmentation')
  external JSFunction get _graphSegmentation;
  @JS('matFromArray')
  external _Mat _matFromArray(int rows, int cols, int type, JSArray<JSNumber> values);

  external void resize(_Mat src, _Mat dst, _Size dsize, double fx, double fy, int interpolation);
  @JS('GaussianBlur')
  external void gaussianBlur(_Mat src, _Mat dst, _Size ksize, double sigmaX);
  external void cvtColor(_Mat src, _Mat dst, int code);
  external void split(_Mat src, _MatVector out);
  @JS('Canny')
  external void canny(_Mat src, _Mat dst, double low, double high);
  external void dilate(_Mat src, _Mat dst, _Mat kernel);
  external double threshold(_Mat src, _Mat dst, double thresh, double maxval, int type);
  external void adaptiveThreshold(_Mat src, _Mat dst, double maxValue, int method, int type, int blockSize, double c);
  external void morphologyEx(_Mat src, _Mat dst, int op, _Mat kernel);
  @JS('Sobel')
  external void sobel(_Mat src, _Mat dst, int ddepth, int dx, int dy);
  external void addWeighted(_Mat a, double alpha, _Mat b, double beta, double gamma, _Mat dst);
  external void magnitude(_Mat x, _Mat y, _Mat dst);
  external void findContours(_Mat src, _MatVector contours, _Mat hierarchy, int mode, int method);
  external double arcLength(_Mat curve, bool closed);
  external void approxPolyDP(_Mat curve, _Mat out, double epsilon, bool closed);
  external double contourArea(_Mat contour);
  external bool isContourConvex(_Mat contour);
  external void fillPoly(_Mat img, _MatVector pts, JSArray<JSNumber> color, int lineType, int shift, _Point offset);
  external int countNonZero(_Mat src);
  @JS('bitwise_and')
  external void bitwiseAnd(_Mat a, _Mat b, _Mat dst);
  external void calcHist(
    _MatVector images,
    JSArray<JSNumber> channels,
    _Mat mask,
    _Mat hist,
    JSArray<JSNumber> histSize,
    JSArray<JSNumber> ranges,
  );
  external double compareHist(_Mat a, _Mat b, int method);
  external _Mat getPerspectiveTransform(_Mat src, _Mat dst);
  external void warpPerspective(_Mat src, _Mat dst, _Mat m, _Size dsize);
}

extension type _Mat._(JSObject _) implements JSObject {
  external int get rows;
  external int get cols;
  external JSUint8Array get data;
  external JSFloat32Array get data32F;
  external JSInt32Array get data32S;
  external _Mat roi(_Rect r);
  external void convertTo(_Mat dst, int type);
  external void delete();
}

extension type _MatVector._(JSObject _) implements JSObject {
  external int size();
  external _Mat get(int i);
  @JS('push_back')
  external void pushBack(_Mat m);
  external void delete();
}

extension type _Algorithm._(JSObject _) implements JSObject {
  external void detect(_Mat image, _Mat lines);
  external void processImage(_Mat src, _Mat dst);
  external void delete();
}

extension type _Size._(JSObject _) implements JSObject {
  external factory _Size({int width, int height});
}

extension type _Point._(JSObject _) implements JSObject {
  external factory _Point({int x, int y});
}

extension type _Rect._(JSObject _) implements JSObject {
  external factory _Rect({int x, int y, int width, int height});
}

class _JsMat implements CvMat {
  _JsMat(this.m);
  final _Mat m;
  @override
  int get rows => m.rows;
  @override
  int get cols => m.cols;
  @override
  void dispose() => m.delete();
}

class _JsContours implements CvContours {
  _JsContours(this._cv, this._v) : length = _v.size();
  final _OpenCv _cv;
  final _MatVector _v;
  @override
  final int length;
  int _at = -1;
  _Mat? _held;

  _Mat _get(int i) {
    if (i != _at) {
      _held?.delete();
      _held = _v.get(i);
      _at = i;
    }
    return _held!;
  }

  /// A view into OpenCV's heap: read it before the next call.
  @override
  Int32List points(int i) => _get(i).data32S.toDart;
  @override
  double arcLength(int i) => _cv.arcLength(_get(i), true);
  @override
  Int32List approxPolyDP(int i, double epsilon) {
    final out = _Mat._(_cv._mat.callAsConstructor());
    _cv.approxPolyDP(_get(i), out, epsilon, true);
    final p = Int32List.fromList(out.data32S.toDart);
    out.delete();
    return p;
  }

  @override
  void dispose() {
    _held?.delete();
    _v.delete();
  }
}

class OpenCvJs implements FinderCv {
  /// [module] is OpenCV.js once its runtime has started (what its `cv` promise gives).
  OpenCvJs(JSObject module) : _cvm = _OpenCv._(module);
  final _OpenCv _cvm;

  _Mat _new() => _Mat._(_cvm._mat.callAsConstructor());
  _Mat _sized(int rows, int cols, int type) => _Mat._(_cvm._mat.callAsConstructor(rows.toJS, cols.toJS, type.toJS));
  _Mat _m(CvMat m) => (m as _JsMat).m;
  CvMat _wrap(_Mat m) => _JsMat(m);
  CvMat _out(void Function(_Mat dst) f) {
    final d = _new();
    f(d);
    return _wrap(d);
  }

  _Mat _points(Int32List p) => _cvm._matFromArray(p.length ~/ 2, 1, _cv32SC2, [for (final v in p) v.toJS].toJS);

  @override
  CvMat fromRgba(Uint8List rgba, int width, int height) {
    final m = _sized(height, width, _cv8UC4);
    m.data.toDart.setAll(0, rgba);
    return _wrap(m);
  }

  @override
  CvMat fromBytes(Uint8List bytes, int width, int height) {
    final m = _sized(height, width, _cv8U);
    m.data.toDart.setAll(0, bytes);
    return _wrap(m);
  }

  @override
  CvMat zeros(int width, int height) {
    final m = _sized(height, width, _cv8U);
    m.data.toDart.fillRange(0, width * height, 0);
    return _wrap(m);
  }

  @override
  CvMat roi(CvMat m, int x, int y, int width, int height) =>
      _wrap(_m(m).roi(_Rect(x: x, y: y, width: width, height: height)));

  @override
  Uint8List bytes(CvMat m) => Uint8List.fromList(_m(m).data.toDart);
  @override
  Float32List floats(CvMat m) => Float32List.fromList(_m(m).data32F.toDart);

  @override
  CvMat resizeArea(CvMat m, double scale) =>
      _out((d) => _cvm.resize(_m(m), d, _Size(width: 0, height: 0), scale, scale, _interArea));
  @override
  CvMat gaussianBlur(CvMat m, int size) =>
      _out((d) => _cvm.gaussianBlur(_m(m), d, _Size(width: size, height: size), 0));
  @override
  CvMat cvtColor(CvMat m, CvColour code) => _out(
    (d) => _cvm.cvtColor(_m(m), d, switch (code) {
      CvColour.rgbaToBgr => 3, // COLOR_RGBA2BGR
      CvColour.bgrToLab => 44, // COLOR_BGR2Lab
      CvColour.bgrToGray => 6, // COLOR_BGR2GRAY
      CvColour.bgrToRgb => 4, // COLOR_BGR2RGB
      CvColour.bgrToRgba => 2, // COLOR_BGR2RGBA
    }),
  );
  @override
  List<CvMat> split(CvMat m) {
    final v = _MatVector._(_cvm._matVector.callAsConstructor());
    _cvm.split(_m(m), v);
    final out = [for (var i = 0; i < v.size(); i++) _wrap(v.get(i))];
    v.delete();
    return out;
  }

  @override
  CvMat toFloat(CvMat m) => _out((d) => _m(m).convertTo(d, _cv32F));
  @override
  CvMat canny(CvMat m, double low, double high) => _out((d) => _cvm.canny(_m(m), d, low, high));
  @override
  CvMat dilate(CvMat m) => _out((d) {
    final k = _new(); // empty: the default 3 x 3
    _cvm.dilate(_m(m), d, k);
    k.delete();
  });
  @override
  CvMat threshold(CvMat m, double t) => _out((d) => _cvm.threshold(_m(m), d, t, 255, _threshBinary));
  @override
  CvMat adaptiveThreshold(CvMat m, int blockSize) =>
      _out((d) => _cvm.adaptiveThreshold(_m(m), d, 255, _adaptiveMeanC, _threshBinary, blockSize, 0));
  @override
  CvMat open(CvMat m, int size) => _out((d) {
    final k = _sized(size, size, _cv8U);
    k.data.toDart.fillRange(0, size * size, 1);
    _cvm.morphologyEx(_m(m), d, _morphOpen, k);
    k.delete();
  });
  @override
  CvMat sobel(CvMat m, int dx, int dy) => _out((d) => _cvm.sobel(_m(m), d, _cv32F, dx, dy));
  @override
  CvMat addWeighted(CvMat a, double alpha, CvMat b, double beta) =>
      _out((d) => _cvm.addWeighted(_m(a), alpha, _m(b), beta, 0, d));
  @override
  CvMat magnitude(CvMat x, CvMat y) => _out((d) => _cvm.magnitude(_m(x), _m(y), d));

  @override
  CvContours findContours(CvMat binary) {
    final v = _MatVector._(_cvm._matVector.callAsConstructor()), hier = _new();
    _cvm.findContours(_m(binary), v, hier, _retrList, _chainApproxSimple);
    hier.delete();
    return _JsContours(_cvm, v);
  }

  @override
  double contourArea(Int32List points) {
    final m = _points(points);
    final a = _cvm.contourArea(m);
    m.delete();
    return a;
  }

  @override
  bool isContourConvex(Int32List points) {
    final m = _points(points);
    final c = _cvm.isContourConvex(m);
    m.delete();
    return c;
  }

  @override
  Float32List lineSegments(CvMat gray) {
    final lsd = _Algorithm._(_cvm._lsd.callAsConstructor()), lines = _new();
    lsd.detect(_m(gray), lines);
    final out = Float32List.fromList(lines.data32F.toDart);
    lines.delete();
    lsd.delete();
    return out;
  }

  @override
  Int32List graphSegmentation(CvMat m, double sigma, double k, int minSize) {
    final gs = _Algorithm._(_cvm._graphSegmentation.callAsConstructor(sigma.toJS, k.toJS, minSize.toJS));
    final d = _new();
    gs.processImage(_m(m), d);
    final out = Int32List.fromList(d.data32S.toDart);
    d.delete();
    gs.delete();
    return out;
  }

  @override
  void fillPoly(CvMat m, Int32List points, int value, {int dx = 0, int dy = 0}) {
    final p = _points(points), v = _MatVector._(_cvm._matVector.callAsConstructor());
    v.pushBack(p);
    _cvm.fillPoly(_m(m), v, [value.toJS, 0.toJS, 0.toJS, 0.toJS].toJS, 8, 0, _Point(x: -dx, y: -dy));
    v.delete();
    p.delete();
  }

  @override
  int countNonZero(CvMat m) => _cvm.countNonZero(_m(m));
  @override
  CvMat bitwiseAnd(CvMat a, CvMat b) => _out((d) => _cvm.bitwiseAnd(_m(a), _m(b), d));

  @override
  Float32List calcHist(CvMat m, List<int> channels, CvMat? mask, int bins) {
    final v = _MatVector._(_cvm._matVector.callAsConstructor()), hist = _new(), none = _new();
    v.pushBack(_m(m));
    _cvm.calcHist(
      v,
      [for (final c in channels) c.toJS].toJS,
      mask == null ? none : _m(mask),
      hist,
      [for (final _ in channels) bins.toJS].toJS,
      [
        for (final _ in channels) ...[0.toJS, 256.toJS],
      ].toJS,
    );
    final out = Float32List.fromList(hist.data32F.toDart);
    hist.delete();
    none.delete();
    v.delete();
    return out;
  }

  @override
  double compareHistBhattacharyya(Float32List a, Float32List b) {
    final ma = _cvm._matFromArray(1, a.length, _cv32F, [for (final x in a) x.toJS].toJS);
    final mb = _cvm._matFromArray(1, b.length, _cv32F, [for (final x in b) x.toJS].toJS);
    final d = _cvm.compareHist(ma, mb, _histcmpBhattacharyya);
    ma.delete();
    mb.delete();
    return d;
  }

  @override
  CvMat warpQuad(CvMat m, Float32List corners, int size) {
    final s = size.toDouble();
    final src = _cvm._matFromArray(4, 1, _cv32FC2, [for (final v in corners) v.toJS].toJS);
    final dst = _cvm._matFromArray(4, 1, _cv32FC2, [for (final v in [0.0, 0.0, s, 0.0, s, s, 0.0, s]) v.toJS].toJS);
    final t = _cvm.getPerspectiveTransform(src, dst);
    final out = _out((d) => _cvm.warpPerspective(_m(m), d, t, _Size(width: size, height: size)));
    for (final x in [src, dst, t]) {
      x.delete();
    }
    return out;
  }
}
