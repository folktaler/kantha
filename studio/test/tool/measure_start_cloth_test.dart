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
}

// An 8 x 8 red JPEG.
final _red = img.encodeJpg(img.Image(width: 8, height: 8)..clear(img.ColorRgb8(200, 30, 30)));
