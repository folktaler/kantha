/* One of the studio's own files (pubspec.yaml's assets, `assets/…`), read from the app's files. In the studio its key
   is its path. An app that uses the studio as a package has the studio's files under packages/kantha_studio/ instead,
   and says so once at its start: studioAssetPrefix = studioAsPackage. The studio itself never sets it. */
import 'package:flutter/services.dart';

/* What an app that uses the studio as a package sets studioAssetPrefix to. */
const studioAsPackage = 'packages/kantha_studio/';

/* Put before every studio file's path: '' in the studio. */
String studioAssetPrefix = '';

Future<ByteData> loadStudioAsset(String path, {AssetBundle? bundle}) =>
    (bundle ?? rootBundle).load('$studioAssetPrefix$path');
