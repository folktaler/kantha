/* The studio's drawings: the printed grid, the grid over the cloth, the stitches, and a
   template's icon. Each draws in its own units, scaled to its box. */
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../solver/geometry.dart';
import '../solver/js_math.dart';
import '../solver/threads.dart';
import 'sheet_geometry.dart';

/* A cloth's ground under its photo, on the board and in the Cloth box tab's swatches. */
const swatchBase = Color(0xFFEAE5D5);

Color hexColor(String hex, [double opacity = 1]) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16)).withValues(alpha: opacity);

/* One straight stroke cut into dashes as stroke-dasharray cuts it, from its start: on, off, on… */
void _dash(List<Offset> out, Offset a, Offset b, double on, double off) {
  final len = (b - a).distance;
  if (len == 0) return;
  final dir = (b - a) / len;
  for (var t = 0.0; t < len; t += on + off) {
    out..add(a + dir * t)..add(a + dir * math.min(t + on, len));
  }
}

Paint _stroke(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..color = c
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

/* The printed grid: dotted lines on every 4 cm, ticks in the
   bleed and a dot at every crossing. Drawn over (a4.bw + 2·bleed) × (a4.bh + 2·bleed) cm. */
class PaperGridPainter extends CustomPainter {
  const PaperGridPainter();
  static final double gw = a4.bw + bleedCm * 2, gh = a4.bh + bleedCm * 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / gw, size.height / gh);
    final lines = <Offset>[], ticks = <Offset>[];
    for (var c = 0; c <= a4.cols; c++) {
      final x = bleedCm + c * patchCm;
      _dash(lines, Offset(x, 0), Offset(x, gh), 0.07, 0.21);
      ticks..add(Offset(x, 0))..add(Offset(x, bleedCm))..add(Offset(x, gh - bleedCm))..add(Offset(x, gh));
    }
    for (var r = 0; r <= a4.rows; r++) {
      final y = bleedCm + r * patchCm;
      _dash(lines, Offset(0, y), Offset(gw, y), 0.07, 0.21);
      ticks..add(Offset(0, y))..add(Offset(bleedCm, y))..add(Offset(gw - bleedCm, y))..add(Offset(gw, y));
    }
    canvas.drawPoints(ui.PointMode.lines, lines, _stroke(const Color(0xFFDBD5C4), 0.05));
    canvas.drawPoints(ui.PointMode.lines, ticks, _stroke(const Color(0xFFA9A18B), 0.11));
    final dot = Paint()..color = const Color(0xFFB3AC99);
    for (var c = 0; c <= a4.cols; c++) {
      for (var r = 0; r <= a4.rows; r++) {
        canvas.drawCircle(Offset(bleedCm + c * patchCm, bleedCm + r * patchCm), 0.075, dot);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PaperGridPainter old) => false;
}

/* The grid laid over the cloth: a pale dotted line with a dark
   one just under it, and a pale dot at every crossing. Drawn over a4.bw × a4.bh cm. */
class GhostGridPainter extends CustomPainter {
  const GhostGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / a4.bw, size.height / a4.bh);
    final d = <Offset>[];
    for (var c = 1; c < a4.cols; c++) {
      _dash(d, Offset(c * patchCm, 0), Offset(c * patchCm, a4.bh), 0.06, 0.28);
    }
    for (var r = 1; r < a4.rows; r++) {
      _dash(d, Offset(0, r * patchCm), Offset(a4.bw, r * patchCm), 0.06, 0.28);
    }
    canvas.save();
    canvas.translate(0.035, 0.035);
    canvas.drawPoints(ui.PointMode.lines, d, _stroke(const Color(0xFF1E2027).withValues(alpha: 0.28), 0.05));
    canvas.restore();
    canvas.drawPoints(ui.PointMode.lines, d, _stroke(const Color(0xFFFBF9F2).withValues(alpha: 0.5), 0.05));
    final dot = Paint()..color = const Color(0xFFFBF9F2).withValues(alpha: 0.75);
    for (var c = 0; c <= a4.cols; c++) {
      for (var r = 0; r <= a4.rows; r++) {
        canvas.drawCircle(Offset(c * patchCm, r * patchCm), 0.06, dot);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GhostGridPainter old) => false;
}

/* The stitches: rows of running stitch across the squares, each row drifting a
   little and each stitch wobbling, from the same seed every time so they fall where they
   fell on the web. Drawn over a4.bw × a4.bh cm. */
class StitchPainter extends CustomPainter {
  StitchPainter({required this.density, required this.thread});
  final Density density;
  final Thread thread;

  static final _paths = <String, Path>{};
  static Path pathFor(Density d) => _paths.putIfAbsent(d.key, () {
        final row = patchCm / d.rows, period = patchCm / d.per, stitch = period * stitchShare;
        final r = rng(20260910), p = Path();
        for (var y = row / 2; y < a4.bh; y += row) {
          final drift = (r() - 0.5) * 0.04;
          for (var x = -period * r(); x < a4.bw; x += period) {
            final x0 = math.max(0.0, x), x1 = math.min(a4.bw, x + stitch);
            if (x1 - x0 > 0.06) {
              final wob = drift + (r() - 0.5) * 0.025;
              p..moveTo(x0, y + wob)..lineTo(x1, y + wob + (r() - 0.5) * 0.018);
            }
          }
        }
        return p;
      });

  @override
  void paint(Canvas canvas, Size size) {
    final path = pathFor(density);
    canvas.save();
    canvas.scale(size.width / a4.bw, size.height / a4.bh);
    canvas.save();
    canvas.translate(0.022, 0.022);
    canvas.drawPath(path, _stroke(thread.light ? hexColor('#1E2027', 0.26) : hexColor('#FBF8EE', 0.5), 0.1));
    canvas.restore();
    canvas.drawPath(path, _stroke(hexColor(thread.hex, 0.96), 0.055));
    canvas.restore();
  }

  @override
  bool shouldRepaint(StitchPainter old) => old.density.key != density.key || old.thread.key != thread.key;
}

/* A template's icon: 5 × 7 grey squares on a card, 26 × 36 units, the card blue-grey when it is the one showing. */
class LayoutIconPainter extends CustomPainter {
  const LayoutIconPainter({required this.levels, required this.active});
  final List<int> levels;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26, size.height / 36);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 26, 36), const Radius.circular(1.5)),
        Paint()..color = active ? const Color(0xFFE4EAF3) : const Color(0xFFF3F0E6));
    for (var r = 0; r < a4.rows; r++) {
      for (var c = 0; c < a4.cols; c++) {
        final g = levels[r * a4.cols + c];
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c * 5 + 1, r * 5 + 1, 4.2, 4.2), const Radius.circular(0.6)),
            Paint()..color = Color.fromARGB(255, g, jsRound(g * 0.985), jsRound(g * 0.93)));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LayoutIconPainter old) => old.active != active || !identical(old.levels, levels);
}

/* A dashed outline, as a CSS `1px dashed` border draws one. */
class DashedRectPainter extends CustomPainter {
  const DashedRectPainter({required this.color, this.width = 1, this.dash = 3, this.gap = 3, this.sides = const {0, 1, 2, 3}});
  final Color color;
  final double width, dash, gap;
  final Set<int> sides; // 0 top, 1 right, 2 bottom, 3 left

  @override
  void paint(Canvas canvas, Size size) {
    final h = width / 2, pts = <Offset>[];
    final r = Rect.fromLTRB(h, h, size.width - h, size.height - h);
    if (sides.contains(0)) _dash(pts, r.topLeft, r.topRight, dash, gap);
    if (sides.contains(1)) _dash(pts, r.topRight, r.bottomRight, dash, gap);
    if (sides.contains(2)) _dash(pts, r.bottomLeft, r.bottomRight, dash, gap);
    if (sides.contains(3)) _dash(pts, r.topLeft, r.bottomLeft, dash, gap);
    canvas.drawPoints(ui.PointMode.lines, pts, Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt);
  }

  @override
  bool shouldRepaint(DashedRectPainter old) => old.color != color || old.width != width;
}
