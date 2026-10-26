import 'dart:typed_data';
import 'hue.dart';

class Families {
  const Families(this.medoids, this.family);
  final List<int> medoids, family;
}

Families? colourFamilies(List<Lab> lab, List<int> members, int k, double minChroma) {
  final items = [for (final i in members) if (chroma(lab[i]) >= minChroma) i];
  if (items.length < k) return null;
  final m = items.length;
  final d = Float64List(m * m);
  for (var a = 0; a < m; a++) {
    for (var b = 0; b < m; b++) { d[a * m + b] = ciede2000(lab[items[a]], lab[items[b]]).dEChroma; }
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

int tileableCells(List<int> members, List<double> l, List<int> stock, double gap) {
  var best = 0;
  for (final i in members) {
    final cut = l[i];
    var dark = 0, light = 0;
    for (final j in members) { if (l[j] <= cut) dark += stock[j]; }
    for (final j in members) { if (l[j] >= cut + gap) light += stock[j]; }
    if (dark != 0 && light != 0) { final t = 2 * (dark < light ? dark : light); if (t > best) best = t; }
  }
  return best;
}
