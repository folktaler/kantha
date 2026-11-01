import 'dart:typed_data';
import 'cam16.dart';
import 'hue.dart';

class Families {
  const Families(this.medoids, this.family);
  final List<int> medoids, family;
}

/* k colour families among the coloured cloths (k-medoids, every choice of medoids tried up to [_exhaustiveUpTo] choices), by CAM16-UCS a′b′ distance, or
   with `lightness` by ΔE′ (J′a′b′), so a family is one colour at one lightness. */
Families? colourFamilies(List<Lab> lab, List<int> members, int k, {bool lightness = false}) {
  final items = [for (final i in members) if (coloured(lab[i])) i];
  if (items.length < k) return null;
  final m = items.length;
  final d = Float64List(m * m), ucs = [for (final i in items) ucsOf(lab[i])];
  for (var a = 0; a < m; a++) {
    for (var b = 0; b < m; b++) { d[a * m + b] = lightness ? deUcs(ucs[a], ucs[b]) : chromaUcs(ucs[a], ucs[b]); }
  }

  double costOf(List<int> pick) {
    var cost = 0.0;
    for (var a = 0; a < m; a++) {
      var dd = double.infinity;
      for (final p in pick) { final v = d[a * m + p]; if (v < dd) dd = v; }
      cost += dd;
    }
    return cost;
  }

  var best = <int>[];
  var bestCost = double.infinity;
  lastSearch = _choices(m, k) <= _exhaustiveUpTo ? Search.everyChoice : Search.pam;
  if (lastSearch == Search.everyChoice) {
    final pick = <int>[];
    void walk(int from) {
      if (pick.length == k) {
        final cost = costOf(pick);
        if (cost < bestCost - 1e-12) { bestCost = cost; best = List.of(pick); }
        return;
      }
      for (var p = from; p <= m - (k - pick.length); p++) { pick.add(p); walk(p + 1); pick.removeLast(); }
    }
    walk(0);
  } else {
    // A large box: PAM (Kaufman and Rousseeuw 1990), its BUILD then its SWAP to a local optimum, so a change of box
    // stays quick. Every choice tried would cost choose(m, k) passes over the cloths. In-house because no maintained
    // Dart package offers k-medoids (pub.dev, 1 November 2026).
    for (var j = 0; j < k; j++) {
      var add = -1;
      var addCost = double.infinity;
      for (var p = 0; p < m; p++) {
        if (best.contains(p)) continue;
        final c = costOf([...best, p]);
        if (c < addCost - 1e-12) { addCost = c; add = p; }
      }
      best.add(add);
      bestCost = addCost;
    }
    for (var improved = true; improved;) {
      improved = false;
      for (var j = 0; j < k; j++) {
        for (var p = 0; p < m; p++) {
          if (best.contains(p)) continue;
          final trial = List.of(best)..[j] = p;
          final c = costOf(trial);
          if (c < bestCost - 1e-12) { bestCost = c; best = trial; improved = true; }
        }
      }
    }
    // In ascending order, as every choice tried gives them, so the families' numbers do not jump at the threshold.
    best.sort();
  }

  final family = List<int>.filled(lab.length, -1);
  for (var a = 0; a < items.length; a++) {
    var q = 0;
    for (var j = 1; j < k; j++) { if (d[a * m + best[j]] < d[a * m + best[q]]) q = j; }
    family[items[a]] = q;
  }
  return Families([for (final p in best) items[p]], family);
}

/* How the last call found its medoids, for the tests. */
enum Search { everyChoice, pam }
Search? lastSearch;

/* Every choice of medoids is tried while there are at most this many: 47 cloths in 3 families are 16,215, which
   compile in a few milliseconds. Past it, PAM. */
const _exhaustiveUpTo = 20000;

double _choices(int m, int k) {
  var c = 1.0;
  for (var j = 0; j < k; j++) { c = c * (m - j) / (j + 1); }
  return c;
}
