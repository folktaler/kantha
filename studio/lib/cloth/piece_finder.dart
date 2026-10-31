/* The square finder as the Add a piece sheet uses it: every piece in her photo, which are the same cloth, a tap snapped
   to the piece under it, and each piece cut from the photo. On the web it runs in its own worker
   (piece_finder_web.dart, web/finder_worker.dart), which loads OpenCV.js when the sheet first opens. A phone has no
   finder yet (plan Part 1 step 7): there the sheet is as it was, one piece and the crop. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;
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

/* 2 or more pieces: she checks them, unless they are one printed cloth (isPrint). Fewer, and many tiny outlines: a
   closer photo. Otherwise the crop, as before. `picture` is the photo's size in its own pixels. */
FoundRoute routeOf(FinderAnswer a, Size picture) => a.squares.length >= 2 && !isPrint(a, picture)
    ? FoundRoute.check
    : a.squares.length < 2 && a.tiny >= tooSmallTiny
        ? FoundRoute.tooSmall
        : FoundRoute.crop;

/* The boxes are the squares of one printed cloth, not pieces: at least 4 boxes, all one cloth, all turned the same
   way, their centres on one even grid (any spacing) with at most 1 cell in 10 empty, and that grid reaching all four
   edges of the photo (a print fills the frame; pieces laid on a table stop short of it). Measured 31 October 2026 on
   the 9 test photos, the 57 single-cloth photos, five check prints (47 boxes, 1 grid cell empty, spacing 1.7 sides, so
   the squares do not touch) and same-cloth pieces lying apart: only the check prints are a print. Nine pieces of one
   cloth laid on a table in a neat 3 × 3 grid stay pieces, because the grid stops short of two edges. */
bool isPrint(FinderAnswer a, Size picture) {
  final n = a.squares.length;
  if (n < 4 || a.groups.toSet().length != 1) return false;
  final centres = [for (final q in a.squares) Offset((q[0] + q[2] + q[4] + q[6]) / 4, (q[1] + q[3] + q[5] + q[7]) / 4)];
  // The common turn, each square's top edge folded into a quarter turn and averaged on the circle at 4 times its angle.
  final turns = [for (final q in a.squares) math.atan2(q[3] - q[1], q[2] - q[0]) % (math.pi / 2)];
  final turn = math.atan2(turns.fold(0.0, (t, x) => t + math.sin(4 * x)), turns.fold(0.0, (t, x) => t + math.cos(4 * x))) / 4;
  for (final x in turns) {
    if (((x - turn + math.pi / 4) % (math.pi / 2) - math.pi / 4).abs() > 10 * math.pi / 180) return false;
  }
  // The grid's spacing: the middle of each centre's distance to its nearest other.
  final nearest = [
    for (final (i, c) in centres.indexed)
      [for (final (j, o) in centres.indexed) if (j != i) (c - o).distance].reduce(math.min),
  ]..sort();
  final step = nearest[n ~/ 2];
  final u = Offset(math.cos(turn), math.sin(turn)), v = Offset(-u.dy, u.dx);
  final cells = <(int, int)>{};
  for (final c in centres) {
    final d = c - centres.first;
    final a = (d.dx * u.dx + d.dy * u.dy) / step, b = (d.dx * v.dx + d.dy * v.dy) / step;
    final cell = (a.round(), b.round());
    if (Offset(a - cell.$1, b - cell.$2).distance > 0.2 || !cells.add(cell)) return false;
  }
  final columns = cells.map((c) => c.$1), rows = cells.map((c) => c.$2);
  final grid = (columns.reduce(math.max) - columns.reduce(math.min) + 1) * (rows.reduce(math.max) - rows.reduce(math.min) + 1);
  if (cells.length < 0.9 * grid) return false;
  final xs = [for (final q in a.squares) for (var k = 0; k < 8; k += 2) q[k]];
  final ys = [for (final q in a.squares) for (var k = 1; k < 8; k += 2) q[k]];
  return xs.reduce(math.min) < step &&
      picture.width - xs.reduce(math.max) < step &&
      ys.reduce(math.min) < step &&
      picture.height - ys.reduce(math.max) < step;
}
