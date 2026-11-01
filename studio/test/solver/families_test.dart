@Tags(['chrome-only'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/families.dart';
import 'recorded.dart';

void main() {
  test('colour families, as the snapshot holds them', () {
    final labs = poolLab();
    final all = [for (var i = 0; i < labs.length; i++) i];
    for (final f in recorded['families'] as List) {
      final members = f['case'] == 'pool' ? all : all.sublist(0, 12);
      final got = colourFamilies(labs, members, 3);
      if (f['result'] == null) { expect(got, isNull); continue; }
      expect(got!.medoids, ints(f['result']['medoids']));
      expect(got.family, ints(f['result']['family']));
    }
  });

  test('a large box, past every choice tried, still finds its colours', () {
    // 150 cloths: 50 reds, 50 greens and 50 blues, each a little apart. Every choice of 3 would be 551,300.
    final labs = [
      for (var i = 0; i < 50; i++) ...[
        (l: 45.0 + i % 5, a: 60.0 + i % 7, b: 40.0 - i % 3),
        (l: 50.0 + i % 5, a: -50.0 - i % 7, b: 40.0 + i % 3),
        (l: 35.0 + i % 5, a: 20.0 + i % 3, b: -60.0 - i % 7),
      ],
    ];
    final sw = Stopwatch()..start();
    final f = colourFamilies(labs, [for (var i = 0; i < labs.length; i++) i], 3)!;
    expect(sw.elapsedMilliseconds, lessThan(2000));
    for (var colour = 0; colour < 3; colour++) {
      expect({for (var i = colour; i < labs.length; i += 3) f.family[i]}.length, 1, reason: 'colour $colour is one family');
    }
    expect(f.family.toSet().length, 3);
  });
}
