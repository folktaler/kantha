/* The two steps of Add a piece when the finder found 2 or more pieces in her photo (plan Part 1 steps 4 and 5; the
   owner's mockup and words of 30 October 2026): "Are these your pieces?", the photo with every piece found outlined,
   where a tap on a box removes it (a tap again brings it back), a tap on a piece the finder missed adds one, snapped
   to its edges when the finder sees them, and a box's corners move once it is zoomed in far enough to take a finger;
   then "Your cloths", one swatch per cloth with its count, changed with − and +. Nothing here joins or splits
   cloths (owner, 30 October 2026). Built from Flutter's own InteractiveViewer, CustomPainter and GestureDetector. */
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../studio/phone/phone_theme.dart';
import '../studio/pressable.dart';
import 'parts.dart';
import 'prepare.dart' show PickedPhoto;

/* One piece in the photo: its corners in the picture's pixels (x0, y0, … y3, clockwise from the top left), the cloth
   it was matched to, and whether she removed it. */
class Piece {
  Piece(this.q, this.cloth, {this.removed = false});
  final Float32List q;
  /* The finder's group number, or a key of its own for a piece she added. */
  final Object cloth;
  bool removed;

  Piece copy() => Piece(Float32List.fromList(q), cloth, removed: removed);

  Offset get centre => Offset((q[0] + q[2] + q[4] + q[6]) / 4, (q[1] + q[3] + q[5] + q[7]) / 4);
  Offset corner(int k) => Offset(q[2 * k], q[2 * k + 1]);
  double get side {
    var s = 0.0;
    for (var k = 0; k < 4; k++) {
      s += (corner((k + 1) % 4) - corner(k)).distance;
    }
    return s / 4;
  }

  bool holds(Offset p) {
    // Inside a convex outline: on the same side of every edge.
    var sign = 0;
    for (var k = 0; k < 4; k++) {
      final a = corner(k), b = corner((k + 1) % 4);
      final c = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
      final s = c.sign.toInt();
      if (s == 0) continue;
      if (sign == 0) sign = s;
      if (s != sign) return false;
    }
    return true;
  }
}

/* A square centred on `at`, `side` long, turned `angle`. */
Float32List squareAround(Offset at, double side, double angle) {
  final h = side / 2, d = Offset(math.cos(angle), math.sin(angle)), n = Offset(-d.dy, d.dx);
  final out = Float32List(8);
  for (final (k, (a, b)) in const [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)].indexed) {
    final p = at + d * (a * h) + n * (b * h);
    out[2 * k] = p.dx;
    out[2 * k + 1] = p.dy;
  }
  return out;
}

/* A piece she adds where nothing snapped: the size of the nearest piece found, turned like it, centred on her tap (the
   picture's eighth when there is none). */
Float32List defaultSquare(Offset at, List<Piece> pieces, Size picture) {
  Piece? near;
  for (final p in pieces) {
    if (p.removed) continue;
    if (near == null || (p.centre - at).distance < (near.centre - at).distance) near = p;
  }
  if (near == null) return squareAround(at, picture.shortestSide / 8, 0);
  final e = near.corner(1) - near.corner(0);
  return squareAround(at, near.side, math.atan2(e.dy, e.dx));
}

/* The most a photo is zoomed in. */
const _maxZoom = 4.0;
/* A corner moved stops this far (picture pixels) from the box's other corners, so a box never shrinks to nothing. */
const smallestSide = 16.0;
/* A box shows its corners, to be moved, once its side is this long on the screen: a finger on each, apart. */
const _cornersFrom = 56.0;

/* "Are these your pieces?": the count, Undo and zoom, the hint, and the photo. */
class CheckPieces extends StatefulWidget {
  const CheckPieces({super.key, required this.photo, required this.pieces, required this.words, required this.edit,
      required this.onUndo, required this.canUndo, required this.add, this.held, this.enabled = true});
  final PickedPhoto photo;
  final List<Piece> pieces;
  final L words;
  /* Changes the pieces (her undo keeps what they were before). */
  final void Function(VoidCallback change) edit;
  final VoidCallback onUndo;
  final bool canUndo, enabled;
  /* She tapped where no box is, at this point of the picture. */
  final void Function(Offset at) add;
  /* True while a finger is on the photo, so the sheet holds still. */
  final ValueNotifier<bool>? held;

  @override
  State<CheckPieces> createState() => _CheckPiecesState();
}

class _CheckPiecesState extends State<CheckPieces> {
  final _view = TransformationController();
  /* The corner being moved: the piece and which corner; and whether it has moved yet (kept for Undo when it first
     does). */
  (Piece, int)? _drag;
  bool _moved = false;
  /* The press began on a corner: it is not a tap. */
  bool _onCorner = false;
  double _fit = 1;
  Size _stage = Size.zero;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  double get _zoom => _view.value.getMaxScaleOnAxis();

  /* Zoomed to `to`, the middle of the stage staying where it is, the photo kept filling it. */
  void _zoomTo(double to) {
    final s = to.clamp(1.0, _maxZoom), mid = _stage.center(Offset.zero), c = _view.toScene(mid);
    final tx = (mid.dx - c.dx * s).clamp(_stage.width * (1 - s), 0.0);
    final ty = (mid.dy - c.dy * s).clamp(_stage.height * (1 - s), 0.0);
    _view.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

  /* The picture's pixels under a point on the photo as drawn (its own size times _fit). */
  Offset _picture(Offset local) => local / _fit;

  bool _cornersShown(Piece p) => !p.removed && p.side * _fit * _zoom >= _cornersFrom;

  void _down(PointerDownEvent e) {
    _onCorner = false;
    if (!widget.enabled) return;
    final at = _picture(e.localPosition), reach = 22 / (_fit * _zoom);
    for (final p in widget.pieces.reversed) {
      if (!_cornersShown(p)) continue;
      for (var k = 0; k < 4; k++) {
        if ((p.corner(k) - at).distance <= reach) {
          setState(() {
            _drag = (p, k);
            _moved = false;
            _onCorner = true;
          });
          return;
        }
      }
    }
  }

  void _move(PointerMoveEvent e) {
    final d = _drag;
    if (d == null) return;
    final at = _picture(e.localPosition);
    final w = widget.photo.width.toDouble(), h = widget.photo.height.toDouble();
    final (p, k) = d;
    final to = Offset(at.dx.clamp(0, w), at.dy.clamp(0, h));
    if (to == p.corner(k)) return;
    for (var j = 0; j < 4; j++) {
      if (j != k && (p.corner(j) - to).distance < smallestSide) return;
    }
    void place() {
      p.q[2 * k] = to.dx;
      p.q[2 * k + 1] = to.dy;
    }
    // The first move is one change, kept for Undo; the rest of the same drag carry it on.
    if (_moved) return setState(place);
    _moved = true;
    widget.edit(place);
  }

  void _up(PointerEvent _) {
    if (_drag != null) setState(() => _drag = null);
  }

  void _tap(TapUpDetails d) {
    if (_onCorner || !widget.enabled) return;
    final at = _picture(d.localPosition);
    for (final p in widget.pieces.reversed) {
      if (p.holds(at)) {
        widget.edit(() => p.removed = !p.removed);
        return;
      }
    }
    widget.add(at);
  }

  Widget _tool(String text, String? label, VoidCallback? onPressed) => Pressable(
        label: label,
        onPressed: onPressed,
        builder: (context, st) => focusRing(st.focused, Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: st.hovered && st.enabled ? PhonePalette.hover : PhonePalette.white,
              borderRadius: kControlRadius, border: Border.all(color: st.enabled ? PhonePalette.strong : PhonePalette.border)),
          child: ExcludeSemantics(excluding: label != null,
              child: Text(text, style: pText(PType.control, color: st.enabled ? PhonePalette.text : PhonePalette.strong))),
        )),
      );

  @override
  Widget build(BuildContext context) {
    final words = widget.words;
    final kept = widget.pieces.where((p) => !p.removed).length, gone = widget.pieces.length - kept;
    final count = Semantics(liveRegion: true, child: Text(
        gone == 0 ? words.clothManyCount(kept) : words.clothManyCountRemoved(kept, '$gone'),
        key: const ValueKey('pieces-count'), style: pText(PType.labelStrong, figures: true)));
    final tools = ListenableBuilder(listenable: _view, builder: (context, _) {
      final z = _zoom;
      return Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
        _tool(words.clothManyUndo, null, widget.canUndo && widget.enabled ? widget.onUndo : null),
        _tool('−', words.clothManyZoomOut, z > 1.001 ? () => _zoomTo(z / 1.5) : null),
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 52), child: Text(words.clothManyZoom('${(z * 100).round()}'),
            textAlign: TextAlign.center, style: pText(PType.metadata, figures: true))),
        _tool('+', words.clothManyZoomIn, z < _maxZoom - 0.001 ? () => _zoomTo(z * 1.5) : null),
      ]);
    });
    final height = (MediaQuery.sizeOf(context).height * 0.45).clamp(280.0, 520.0);
    final stage = Container(
      key: const ValueKey('pieces-photo'),
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: PhonePalette.canvas, border: Border.all(color: PhonePalette.border)),
      child: LayoutBuilder(builder: (context, box) {
        _stage = box.biggest;
        final pw = widget.photo.width.toDouble(), ph = widget.photo.height.toDouble();
        _fit = math.min(box.maxWidth / pw, box.maxHeight / ph);
        return InteractiveViewer(
          transformationController: _view,
          minScale: 1,
          maxScale: _maxZoom,
          panEnabled: _drag == null,
          scaleEnabled: _drag == null,
          child: Center(child: SizedBox(
            width: pw * _fit,
            height: ph * _fit,
            child: Listener(
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: GestureDetector(
                onTapUp: _tap,
                child: Stack(fit: StackFit.expand, children: [
                  Image.memory(widget.photo.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                  ListenableBuilder(listenable: _view, builder: (context, _) => CustomPaint(
                      painter: _PiecesPainter(widget.pieces, _fit, _zoom, _cornersShown))),
                ]),
              ),
            ),
          )),
        );
      }),
    );
    final held = widget.held;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      LayoutBuilder(builder: (context, box) => box.maxWidth < 420
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [count, tools])
          : Row(children: [Expanded(child: count), tools])),
      const SizedBox(height: 8),
      cardHint(words.clothManyCheckHint),
      const SizedBox(height: 8),
      held == null ? stage : CropHold(held: held, child: stage),
    ]);
  }
}

/* cropperjs's blue, as the crop step's square. */
const _blue = Color(0xFF3399FF);

class _PiecesPainter extends CustomPainter {
  _PiecesPainter(this.pieces, this.fit, this.zoom, this.corners)
      : _shape = [for (final p in pieces) (p.removed, Float32List.fromList(p.q))];
  final List<Piece> pieces;
  final double fit, zoom;
  final bool Function(Piece) corners;
  /* What was drawn, to know whether anything changed. */
  final List<(bool, Float32List)> _shape;

  @override
  void paint(Canvas canvas, Size size) {
    // Lines keep their width on the screen at any zoom.
    final px = 1 / zoom;
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 * px
      ..color = const Color(0xFFFFFFFF);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * px
      ..color = _blue;
    final shade = Paint()..color = const Color(0x73211E1C);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * px
      ..color = const Color(0xFFFFFFFF);
    for (final p in pieces) {
      final pts = [for (var k = 0; k < 4; k++) p.corner(k) * fit];
      final path = Path()..addPolygon(pts, true);
      if (p.removed) {
        canvas.drawPath(path, shade);
        for (var k = 0; k < 4; k++) {
          _dashed(canvas, pts[k], pts[(k + 1) % 4], dash, 6 * px);
        }
      } else {
        canvas.drawPath(path, halo);
        canvas.drawPath(path, line);
      }
    }
    final dot = Paint()..color = _blue;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = px
      ..color = const Color(0xFFFFFFFF);
    for (final p in pieces) {
      if (!corners(p)) continue;
      for (var k = 0; k < 4; k++) {
        final r = Rect.fromCenter(center: p.corner(k) * fit, width: 9 * px, height: 9 * px);
        canvas.drawRect(r, dot);
        canvas.drawRect(r, rim);
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p, double step) {
    final d = b - a, n = math.max(2, (d.distance / step).floor());
    for (var i = 0; i < n; i += 2) {
      canvas.drawLine(a + d * (i / n), a + d * ((i + 1) / n), p);
    }
  }

  @override
  bool shouldRepaint(_PiecesPainter old) {
    if (old.fit != fit || old.zoom != zoom || old._shape.length != _shape.length) return true;
    for (var i = 0; i < _shape.length; i++) {
      if (old._shape[i].$1 != _shape[i].$1) return true;
      final a = old._shape[i].$2, b = _shape[i].$2;
      for (var k = 0; k < 8; k++) {
        if (a[k] != b[k]) return true;
      }
    }
    return false;
  }
}

/* One of her cloths: the pieces matched to it, its count, and its swatch (one piece, cut from the photo). */
class FoundCloth {
  FoundCloth(this.key, this.found, this.count, this.rgba, this.image);
  final Object key;
  /* How many pieces were matched to it. */
  final int found;
  int count;
  /* The cut, side × side RGBA: what is measured and stored. */
  final Uint8List rgba;
  final ui.Image image;
}

/* "Your cloths": the hint, then a row per cloth: its swatch, how often it was found, and its count. */
class YourCloths extends StatelessWidget {
  const YourCloths({super.key, required this.cloths, required this.words, required this.onCount, this.enabled = true});
  final List<FoundCloth> cloths;
  final L words;
  final void Function(FoundCloth cloth, int count) onCount;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min,
          children: [
        Text(words.clothManyClothsHint, style: pText(PType.bodySmall, color: PhonePalette.text2)),
        const SizedBox(height: 8),
        for (final (i, c) in cloths.indexed) _row(i, c),
      ]);

  Widget _row(int i, FoundCloth c) {
    final swatch = Container(
      width: 64, height: 64,
      decoration: BoxDecoration(border: Border.all(color: PhonePalette.divider)),
      child: RawImage(image: c.image, fit: BoxFit.cover),
    );
    final found = Text(words.clothManyFound(c.found), style: pText(PType.cardLabel));
    final counter = PieceCounter(count: c.count, shown: words.clothPiece(c.count), fewer: words.clothFewer,
        more: words.clothMore, enabled: enabled, onChanged: (n) => onCount(c, n));
    return Container(
      key: ValueKey('cloth-row-$i'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PhonePalette.divider))),
      child: LayoutBuilder(builder: (context, box) => box.maxWidth < 400
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
              Row(children: [swatch, const SizedBox(width: 12), Expanded(child: found)]),
              Align(alignment: AlignmentDirectional.centerEnd, child: counter),
            ])
          : Row(children: [swatch, const SizedBox(width: 12), Expanded(child: found), counter])),
    );
  }
}
