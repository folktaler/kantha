import 'dart:typed_data';
import 'cam16.dart';
import 'hue.dart';

class Families {
  const Families(this.medoids, this.family);
  final List<int> medoids, family;
}

/* k colour families among the coloured cloths (k-medoids, every choice of medoids tried), by CAM16-UCS a′b′ distance, or
   with `lightness` by ΔE′ (J′a′b′), so a family is one colour at one lightness. */
Families? colourFamilies(List<Lab> lab, List<int> members, int k, {bool lightness = false}) {
  final items = [for (final i in members) if (coloured(lab[i])) i];
  if (items.length < k) return null;
  final m = items.length;
  final d = Float64List(m * m), ucs = [for (final i in items) ucsOf(lab[i])];
  for (var a = 0; a < m; a++) {
    for (var b = 0; b < m; b++) { d[a * m + b] = lightness ? deUcs(ucs[a], ucs[b]) : chromaUcs(ucs[a], ucs[b]); }
  }

  var best = <int>[];
  var bestCost = double.infinity;
  final pick = <int>[];
  void walk(int from) {
    if (pick.length == k) {
      var cost = 0.0;
      for (var a = 0; a < m; a++) {
        var dd = double.infinity;
        for (final p in pick) { final v = d[a * m + p]; if (v < dd) dd = v; }
        cost += dd;
      }
      if (cost < bestCost - 1e-12) { bestCost = cost; best = List.of(pick); }
      return;
    }
    for (var p = from; p <= m - (k - pick.length); p++) { pick.add(p); walk(p + 1); pick.removeLast(); }
  }
  walk(0);

  final family = List<int>.filled(lab.length, -1);
  for (var a = 0; a < items.length; a++) {
    var q = 0;
    for (var j = 1; j < k; j++) { if (d[a * m + best[j]] < d[a * m + best[q]]) q = j; }
    family[items[a]] = q;
  }
  return Families([for (final p in best) items[p]], family);
}
