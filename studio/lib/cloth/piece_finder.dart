/* The square finder as the Add a piece sheet uses it: every piece in her photo, which are the same cloth, a tap snapped
   to the piece under it, and each piece cut from the photo. On the web it runs in its own worker
   (piece_finder_web.dart, web/finder_worker.dart), which loads OpenCV.js when the sheet first opens. A phone has no
   finder yet (plan Part 1 step 7): there the sheet is as it was, one piece and the crop. */
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'prepare.dart' show PickedPhoto;
import 'piece_finder_io.dart' if (dart.library.js_interop) 'piece_finder_web.dart' as impl;

/* What the finder found in one photo. Corners in the picture's own pixels (PickedPhoto's width and height), x0, y0, …
   x3, y3, clockwise from the top left. */
class FinderAnswer {
  const FinderAnswer({required this.squares, required this.groups, required this.tiny});
  final List<Float32List> squares;
  /* A group number per square: squares of one number are one cloth. */
  final List<int> groups;
  /* How many outlines had a piece's shape but were too small to be one (FoundSquares.tiny). */
  final int tiny;
}

abstract interface class PieceFinder {
  /* The pieces in `photo`. The photo is kept for snap and cut until the next find, or forget. */
  Future<FinderAnswer> find(PickedPhoto photo);
  /* The piece around a tap at `at` (picture pixels) on the kept photo, or null when nothing there looks like one. */
  Future<Float32List?> snap(Offset at);
  /* Each square cut from the kept photo and straightened at its own size, as side × side RGBA pixels, which
     preparePhoto takes as it takes the cropper's square. */
  Future<List<Uint8List>> cut(List<Float32List> squares);
  /* The kept photo let go. */
  void forget();
}

/* The finder this platform has, or null (a phone). Started when the sheet opens, not with the studio. A test sets
   pieceFinderWith. */
PieceFinder? pieceFinder() => pieceFinderWith();
@visibleForTesting
PieceFinder? Function() pieceFinderWith = impl.create;

/* At this many tiny outlines (FinderAnswer.tiny) with fewer than 2 pieces found, the pieces are there but too small in
   the photo to find. Measured 30 October 2026: three sewn panels photographed from far off, 137; every other test photo
   10 or under, and the 57 single-cloth photos (the Sample box's 10 and the 47 start cloths) 28 at most. */
const tooSmallTiny = 60;

enum FoundRoute { crop, tooSmall, check }

/* 2 or more pieces: she checks them. Fewer, and many tiny outlines: a closer photo. Otherwise the crop, as before. */
FoundRoute routeOf(FinderAnswer a) =>
    a.squares.length >= 2 ? FoundRoute.check : a.tiny >= tooSmallTiny ? FoundRoute.tooSmall : FoundRoute.crop;
