/* One of the studio's own files (pubspec.yaml's assets, `assets/…`), read from the app's files. In the studio its key
   is its path. In an app that uses the studio as a package, Flutter keeps a package's files under
   packages/kantha_studio/, so a read there finds it under that name instead. Which one answers is kept once known. */
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

const _asPackage = 'packages/kantha_studio/';
String? _prefix;

Future<ByteData> loadStudioAsset(String path, {AssetBundle? bundle}) async {
  final from = bundle ?? rootBundle;
  final known = _prefix;
  if (known != null) return from.load('$known$path');
  try {
    final b = await from.load(path);
    _prefix = '';
    return b;
  } catch (e, s) {
    try {
      final b = await from.load('$_asPackage$path');
      _prefix = _asPackage;
      return b;
    } catch (_) {
      // Neither: the studio's own error, as it was before this fallback.
      Error.throwWithStackTrace(e, s);
    }
  }
}

/* Forgets which name answered, so a test can start again. */
@visibleForTesting
void forgetStudioAssetPrefix() => _prefix = null;
