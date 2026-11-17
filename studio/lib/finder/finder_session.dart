/* What the Add a piece sheet asks of the finder, on any OpenCV binding: the pieces in a picture, which are one cloth,
   a tap snapped to a piece, and each piece cut from the picture. It keeps the last picture and what the finder read
   of it for the snaps and cuts after. The web runs it in the finder's Web Worker (web/finder_worker.dart, OpenCV.js),
   a phone in an isolate (lib/cloth/piece_finder_io.dart, opencv_dart): one set of rules, two bindings. Plain Dart,
   no Flutter, so both can compile it. */
import 'dart:typed_data';
import 'cv.dart';
import 'find_squares.dart';
import 'group_squares.dart';

class FinderSession {
  FinderSession(this.cv);
  final FinderCv cv;

  /// The picture last asked about, as BGR, its finder, and the working scale.
  CvMat? _kept;
  SquareFinder? _finder;
  double _keptScale = 1;

  /// The kept picture's working scale: the working picture's size over the picture's.
  double get scale => _keptScale;

  /// The pieces in [rgba] ([width] x [height] RGBA pixels), grouped at [groupCut] (see [cutOf]). The answer, in the
  /// working picture's pixels: width, height, scale, side, squares, groups, tiny, look (for 4 squares or more) and
  /// the milliseconds taken. The picture and what the finder read of it are kept for [snap] and [cut].
  Map<String, Object?> find(Uint8List rgba, int width, int height, {double? groupCut}) {
    final clock = Stopwatch()..start();
    forget();
    final four = cv.fromRgba(rgba, width, height);
    final photo = cv.cvtColor(four, CvColour.rgbaToBgr);
    four.dispose();
    final finder = SquareFinder(cv);
    // OpenCV's memory goes back whatever happens; the photo is kept only once all of it worked.
    final FoundSquares f;
    final List<int> groups;
    final Map<String, Object?>? look;
    final int groupMs, lookMs;
    try {
      f = finder.find(photo);
      try {
        groups = f.squares.isEmpty ? <int>[] : groupsOf(cv, squareHistograms(cv, f), cut: cutOf(groupCut));
        groupMs = clock.elapsedMilliseconds;
        look = lookOf(cv, f);
        lookMs = clock.elapsedMilliseconds - groupMs;
      } finally {
        f.dispose();
      }
    } catch (_) {
      photo.dispose();
      rethrow;
    }
    _kept = photo;
    _finder = finder;
    _keptScale = f.scale;
    return {
      'width': f.width, 'height': f.height, 'scale': f.scale, 'side': f.side,
      'squares': [for (final q in f.squares) q], 'groups': groups, 'tiny': f.tiny, 'look': ?look, 'lookMs': lookMs,
      'totalMs': clock.elapsedMilliseconds,
    };
  }

  /// The square around a tap at [x], [y] on the kept picture, in working pixels, or null.
  Float32List? snap(double x, double y) => _finder?.snap(x, y);

  /// Each square (corners in working pixels) cut from the kept picture and straightened at its own size: the side,
  /// and side x side RGBA pixels.
  List<(int, Uint8List)> cut(List<Float32List> squares) {
    final photo = _kept;
    if (photo == null) throw StateError('no picture kept');
    final out = <(int, Uint8List)>[];
    for (final corners in squares) {
      final side = cropSide(corners, _keptScale);
      final cell = cv.warpQuad(photo, Float32List.fromList([for (final v in corners) v / _keptScale]), side);
      final rgba = cv.cvtColor(cell, CvColour.bgrToRgba);
      out.add((side, cv.bytes(rgba)));
      rgba.dispose();
      cell.dispose();
    }
    return out;
  }

  /// The kept picture let go.
  void forget() {
    _kept?.dispose();
    _kept = null;
    _finder = null;
  }
}

/// printLook as JSON, for 4 squares or more (fewer are never one print).
Map<String, Object?>? lookOf(FinderCv cv, FoundSquares f) {
  final l = f.squares.length < 4 ? null : printLook(cv, f);
  return l == null ? null : {
    'boxSpread': l.boxSpread, 'ringSpread': l.ringSpread, 'ringVsBox': l.ringVsBox, 'ringVsOutside': l.ringVsOutside,
  };
}

/// The grouping's cut asked for: a number from 0 to 1 (a mean Bhattacharyya distance); anything else, or none, is
/// the studio's own, groupCut.
double cutOf(double? asked) => asked != null && asked >= 0 && asked <= 1 ? asked : groupCut;
