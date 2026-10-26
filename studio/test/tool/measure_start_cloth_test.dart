@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../../tool/measure_start_cloth.dart';

void main() {
  test('renamed puts the new colour in place of the one colour word, keeping the name\'s form', () {
    expect(renamed('Dimgray 41', 'gray'), 'Gray 41');
    expect(renamed('KF-041 Dimgray', 'gray'), 'KF-041 Gray');
  });

  test('renamed refuses a name with no colour word, or more than one', () {
    expect(() => renamed('KF-041', 'gray'), throwsArgumentError);
    expect(() => renamed('Red and blue 41', 'gray'), throwsArgumentError);
  });

  test('the source note keeps the photos of every run, in the file\'s order', () {
    final json = {
      'source': 'Read 6 October',
      'cloth': [
        for (final n in ['KF-1', 'KF-2', 'KF-3'])
          <String, dynamic>{'photo': '$n.jpg', 'name': 'Red $n', 'lab': [0.0, 0.0, 0.0], 'edge': 0.0, 'busy': null},
      ],
    };
    final first = remeasured(json, {'KF-3.jpg': _red});
    expect(measuredPhotos(first['source'] as String), {'KF-3.jpg'});
    final second = remeasured(first, {'KF-1.jpg': _red});
    expect(measuredPhotos(second['source'] as String), {'KF-1.jpg', 'KF-3.jpg'});
    expect(second['source'], startsWith('Read 6 October; '));
    expect(second['source'], endsWith(': KF-1.jpg, KF-3.jpg'));
    final cloth = (second['cloth'] as List).cast<Map<String, dynamic>>();
    expect(cloth[0]['busy'], isFalse); // no mark: the measure's
    expect(cloth[1]['busy'], isNull); // not measured
  });

  Map<String, dynamic> one(Map<String, dynamic> cloth) =>
      {'source': 'Read 6 October', 'cloth': [{'photo': 'KF-1.jpg', 'name': 'Red 01', 'lab': [0.0, 0.0, 0.0], ...cloth}]};
  Map<String, dynamic> after(Map<String, dynamic> json) =>
      ((remeasured(json, {'KF-1.jpg': _red})['cloth'] as List).single as Map<String, dynamic>);

  test('a hand mark the spread disagrees with survives a measure, its note too', () {
    // _red is plain, so the measure would say false.
    final c = after(one({'busy': true, 'busyBy': 'hand', 'busyNote': 'a print too fine for the photo'}));
    expect(c['busy'], isTrue);
    expect(c['busyBy'], 'hand');
    expect(c['busyNote'], 'a print too fine for the photo');
  });

  test('a measured mark is worked out again on every measure', () {
    final c = after(one({'busy': true, 'busyBy': 'measure'}));
    expect(c['busy'], isFalse);
    expect(c['busyBy'], 'measure');
  });
}

// An 8 x 8 red JPEG.
final _red = img.encodeJpg(img.Image(width: 8, height: 8)..clear(img.ColorRgb8(200, 30, 30)));
