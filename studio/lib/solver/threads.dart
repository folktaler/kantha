import 'hue.dart';

class Thread {
  const Thread(this.key, this.hex, this.l, this.a, this.b, {required this.light, this.code});
  final String key, hex;
  final double l, a, b;
  final bool light;
  final String? code;
  String get range => 'Anchor';
}

const threads = [
  Thread('ecru', '#F2EBD9', 93, 0.5, 10, light: true),
  Thread('madder', '#A8412F', 41, 41, 30, light: false),
  Thread('indigo', '#27406A', 29, 9, -27, light: false),
  Thread('turmeric', '#D2A02C', 70, 12, 60, light: true),
  Thread('leaf', '#3F6B4A', 41, -22, 14, light: false),
  Thread('black', '#171A20', 9, 0.5, -3, light: false),
];
const recommend = 3;

class Density {
  const Density(this.key, this.rows, this.per);
  final String key; // 'standard' | 'open'
  final int rows, per;
}
const densities = [Density('standard', 8, 6), Density('open', 5, 5)];
const stitchShare = 0.66;

class ThreadScore {
  const ThreadScore(this.thread, this.worstL, this.meanDE);
  final Thread thread;
  final double worstL, meanDE;
}

List<ThreadScore> rankThreads(List<int> grid, List<Lab> lab) {
  final scored = <(int, ThreadScore)>[];
  for (var k = 0; k < threads.length; k++) {
    final thread = threads[k];
    final Lab t = (l: thread.l, a: thread.a, b: thread.b);
    var worstL = double.infinity, sum = 0.0;
    for (final f in grid) {
      final g = (thread.l - lab[f].l).abs();
      if (g < worstL) worstL = g;
      sum += ciede2000(t, lab[f]).dE;
    }
    scored.add((k, ThreadScore(thread, worstL, sum / grid.length)));
  }
  scored.sort((p, q) {
    final byL = q.$2.worstL.compareTo(p.$2.worstL);
    if (byL != 0) return byL;
    final byDE = q.$2.meanDE.compareTo(p.$2.meanDE);
    return byDE != 0 ? byDE : p.$1.compareTo(q.$1);
  });
  return [for (final s in scored) s.$2];
}
