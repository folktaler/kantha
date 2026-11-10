import 'dart:convert';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/assets.dart';

/* A bundle that holds only `keys`, each holding its own name, and counts what it was asked for. */
class _Bundle extends CachingAssetBundle {
  _Bundle(this.keys);
  final Set<String> keys;
  final asked = <String>[];
  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    if (!keys.contains(key)) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(utf8.encode(key));
  }
}

String _text(ByteData b) => utf8.decode(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));

void main() {
  setUp(forgetStudioAssetPrefix);

  test('in the studio a file is read at its own path, and only there', () async {
    final b = _Bundle({'assets/fonts/A.ttf', 'assets/fonts/B.ttf'});
    expect(_text(await loadStudioAsset('assets/fonts/A.ttf', bundle: b)), 'assets/fonts/A.ttf');
    expect(_text(await loadStudioAsset('assets/fonts/B.ttf', bundle: b)), 'assets/fonts/B.ttf');
    expect(b.asked, ['assets/fonts/A.ttf', 'assets/fonts/B.ttf']);
  });

  test('in an app that uses the studio as a package, a file is read under packages/kantha_studio/, '
      'and once that is known it is asked for there first', () async {
    final b = _Bundle({'packages/kantha_studio/assets/fonts/A.ttf', 'packages/kantha_studio/assets/sample/c.jpg'});
    expect(_text(await loadStudioAsset('assets/fonts/A.ttf', bundle: b)), 'packages/kantha_studio/assets/fonts/A.ttf');
    expect(_text(await loadStudioAsset('assets/sample/c.jpg', bundle: b)), 'packages/kantha_studio/assets/sample/c.jpg');
    expect(b.asked, ['assets/fonts/A.ttf', 'packages/kantha_studio/assets/fonts/A.ttf',
        'packages/kantha_studio/assets/sample/c.jpg']);
  });

  test('a file in neither place fails with the error for its own path', () async {
    final b = _Bundle({});
    await expectLater(loadStudioAsset('assets/fonts/A.ttf', bundle: b),
        throwsA(isA<FlutterError>().having((e) => e.message, 'message', contains('"assets/fonts/A.ttf"'))));
  });
}
