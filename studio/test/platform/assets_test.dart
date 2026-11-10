import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/assets.dart';

/* A bundle whose every file holds its own key, and that counts what it was asked for. */
class _Bundle extends CachingAssetBundle {
  final asked = <String>[];
  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    return ByteData.sublistView(utf8.encode(key));
  }
}

void main() {
  tearDown(() => studioAssetPrefix = '');

  test('in the studio a file is read at its own path, once', () async {
    final b = _Bundle();
    await loadStudioAsset('assets/fonts/A.ttf', bundle: b);
    expect(b.asked, ['assets/fonts/A.ttf']);
  });

  test('an app that uses the studio as a package reads it under packages/kantha_studio/, once', () async {
    studioAssetPrefix = studioAsPackage;
    final b = _Bundle();
    await loadStudioAsset('assets/sample/c.jpg', bundle: b);
    expect(b.asked, ['packages/kantha_studio/assets/sample/c.jpg']);
  });
}
