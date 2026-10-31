/* The square finder as the Add a piece sheet uses it: every piece in her photo, which are the same cloth, a tap snapped
   to the piece under it, and each piece cut from the photo. On the web it runs in its own worker
   (piece_finder_web.dart, web/finder_worker.dart), which loads OpenCV.js when the sheet first opens. A phone has no
   finder yet (plan Part 1 step 7): there the sheet is as it was, one piece and the crop. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../finder/group_squares.dart' show PrintLook;
import 'prepare.dart' show PickedPhoto;
import 'piece_finder_io.dart' if (dart.library.js_interop) 'piece_finder_web.dart' as impl;

/* What the finder found in one photo. Corners in the picture's own pixels (PickedPhoto's width and height), x0, y0, …
   x3, y3, clockwise from the top left. */
class FinderAnswer {
  const FinderAnswer({required this.squares, required this.groups, required this.tiny, this.look});
  final List<Float32List> squares;
  /* A group number per square: squares of one number are one cloth. */
  final List<int> groups;
  /* How many outlines had a piece's shape but were too small to be one (FoundSquares.tiny). */
  final int tiny;
  /* How the squares sit in the photo (printLook), for 4 squares or more; null otherwise. */
  final PrintLook? look;
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

/* The longest the sheet waits for the finder (its first look includes loading OpenCV.js, about 0.7 MB). Past it, or
   when the finder fails, the photo goes to the crop, as on a phone with no finder. */
const finderWait = Duration(seconds: 30);

enum FoundRoute { crop, tooSmall, check }

/* One piece found whose side is at least this share of the photo's short side is the cloth she photographed: the crop,
   however many tiny outlines its pattern makes. Measured 31 October 2026: the far-off panels photo's one square, 0.16;
   one gingham cloth on a table, 0.37, with 900 to 1,100 tiny outlines. */
const oneClothShare = 0.25;

/* 2 or more pieces: she checks them, unless they are one printed cloth (isPrint). One piece filling a good part of the
   photo: the crop. Otherwise, many tiny outlines: a closer photo; else the crop, as before. `picture` is the photo's
   size in its own pixels. */
FoundRoute routeOf(FinderAnswer a, Size picture) {
  if (a.squares.length >= 2) return isPrint(a, picture) ? FoundRoute.crop : FoundRoute.check;
  if (a.squares.length == 1 && _side(a.squares.single) >= oneClothShare * picture.shortestSide) return FoundRoute.crop;
  return a.tiny >= tooSmallTiny ? FoundRoute.tooSmall : FoundRoute.crop;
}

double _side(Float32List q) {
  var s = 0.0;
  for (var k = 0; k < 4; k++) {
    s += (Offset(q[2 * ((k + 1) % 4)], q[2 * ((k + 1) % 4) + 1]) - Offset(q[2 * k], q[2 * k + 1])).distance;
  }
  return s / 4;
}

/* One printed cloth, not pieces: its squares on one even grid to the photo's edges (onGridToEdges), or looking
   printed (looksPrinted). */
bool isPrint(FinderAnswer a, Size picture) => onGridToEdges(a, picture) || looksPrinted(a);

/* The boxes look like the squares of one print lying on something else: 4 or more, on one even grid (gridStep), all
   one colour (boxSpread 5 or under), all with the same colour round them (ringSpread 5 or under), that colour unlike
   theirs (ringVsBox 15 or more) and unlike what lies beyond them (ringVsOutside 20 or more). Between separate pieces is
   the table, the same as beyond them; pieces of one cloth scattered on a mat have the mat round them, but do not sit
   on a grid. Measured 31 October 2026: see the commit that brought it. */
bool looksPrinted(FinderAnswer a) {
  final l = a.look;
  return a.squares.length >= 4 &&
      l != null &&
      gridStep(a) != null &&
      l.boxSpread <= 5 &&
      l.ringSpread <= 5 &&
      l.ringVsBox >= 15 &&
      (l.ringVsOutside ?? 0) >= 20;
}

/* The boxes are the squares of one printed cloth, not pieces: at least 4 boxes, all one cloth, all turned the same
   way, their centres on one even grid (any spacing) with at most 1 cell in 10 empty, and that grid reaching all four
   edges of the photo (a print fills the frame; pieces laid on a table stop short of it). Measured 31 October 2026 on
   the 9 test photos, the 57 single-cloth photos, five check prints (47 boxes, 1 grid cell empty, spacing 1.7 sides, so
   the squares do not touch) and same-cloth pieces lying apart: only the check prints are a print. Nine pieces of one
   cloth laid on a table in a neat 3 × 3 grid stay pieces, because the grid stops short of two edges. */
bool onGridToEdges(FinderAnswer a, Size picture) {
  if (a.groups.toSet().length != 1) return false;
  final step = gridStep(a);
  if (step == null) return false;
  final xs = [for (final q in a.squares) for (var k = 0; k < 8; k += 2) q[k]];
  final ys = [for (final q in a.squares) for (var k = 1; k < 8; k += 2) q[k]];
  return xs.reduce(math.min) < step &&
      picture.width - xs.reduce(math.max) < step &&
      ys.reduce(math.min) < step &&
      picture.height - ys.reduce(math.max) < step;
}

/* The grid's spacing when the boxes, 4 or more, all turned the same way (within 10 degrees), have their centres on one
   even grid (each within 0.2 of a spacing of its cell, one box to a cell) with at most 1 cell in 10 empty; else null. */
double? gridStep(FinderAnswer a) {
  final n = a.squares.length;
  if (n < 4) return null;
  final centres = [for (final q in a.squares) Offset((q[0] + q[2] + q[4] + q[6]) / 4, (q[1] + q[3] + q[5] + q[7]) / 4)];
  // The common turn, each square's top edge folded into a quarter turn and averaged on the circle at 4 times its angle.
  final turns = [for (final q in a.squares) math.atan2(q[3] - q[1], q[2] - q[0]) % (math.pi / 2)];
  final turn = math.atan2(turns.fold(0.0, (t, x) => t + math.sin(4 * x)), turns.fold(0.0, (t, x) => t + math.cos(4 * x))) / 4;
  for (final x in turns) {
    if (((x - turn + math.pi / 4) % (math.pi / 2) - math.pi / 4).abs() > 10 * math.pi / 180) return null;
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
    if (Offset(a - cell.$1, b - cell.$2).distance > 0.2 || !cells.add(cell)) return null;
  }
  final columns = cells.map((c) => c.$1), rows = cells.map((c) => c.$2);
  final grid = (columns.reduce(math.max) - columns.reduce(math.min) + 1) * (rows.reduce(math.max) - rows.reduce(math.min) + 1);
  return cells.length < 0.9 * grid ? null : step;
}
