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
      final got = colourFamilies(labs, members, 3, 10);
      if (f['result'] == null) { expect(got, isNull); continue; }
      expect(got!.medoids, ints(f['result']['medoids']));
      expect(got.family, ints(f['result']['family']));
    }
  });
}
