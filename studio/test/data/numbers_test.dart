import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/box_view.dart';
import 'package:kantha_studio/data/numbers.dart';

void main() {
  test('numbers come from the rows, not from position; sample boxes have none', () {
    final views = [BoxView(id: 1, number: null, sample: true), BoxView(id: 2, number: 1, sample: false), BoxView(id: 4, number: 3, sample: false)];
    expect(boxNumbers(views), {2: 1, 4: 3});
  });
  test('busy and edge follow spread', () {
    expect(busyOf(9.9), isFalse); expect(busyOf(10), isTrue);
    expect(edgeOf(20), closeTo(0.1, 1e-9)); expect(edgeOf(0), 0);
  });

  test('a box asked for that is hers wins, even one that cannot fill a panel', () {
    expect(openingBox(wanted: 41, own: [(box: 40, pieces: 90), (box: 41, pieces: 2)]), 41);
  });
  test('a box asked for that is not hers is ignored', () {
    expect(openingBox(wanted: 99, own: [(box: 40, pieces: 90)]), 40);
  });
  test('her newest box that can fill a panel opens — not her first, and not a newer one that cannot', () {
    expect(openingBox(own: [(box: 40, pieces: 90), (box: 41, pieces: 35), (box: 42, pieces: 3)]), 41);
  });
  test('with none able to fill a panel, her newest box opens', () {
    expect(openingBox(own: [(box: 40, pieces: 34), (box: 41, pieces: 0)]), 41);
  });
  test('with no box at all, nothing opens', () => expect(openingBox(own: []), isNull));
  test('Add a piece starts at 1', () => expect(startCount, 1));
}
