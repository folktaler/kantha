/* The bundled faces the first screen does not draw with, loaded when they are needed instead of before the first
   frame (his decision, 20 Oct): Public Sans, which only the saved photo and the sheet's footer set, and Noto Sans
   Malayalam, the studio's fallback for Malayalam. Malayalam loads just after the first frame (app.dart), or before it
   when a name on the first screen is written in it, so that screen does not change face once drawn. Public Sans's
   files are fetched into memory just after the first frame (app.dart), which lays nothing out again, and the face is
   made from those bytes when a file is first made (take_menus.dart): a studio opened online still makes its files
   once the network has gone. Each is fetched and loaded once; one that failed is tried again next time it is asked
   for. pubspec.yaml lists their files as assets, not as fonts, so the font manifest that loads before the first
   frame does not name them. */
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

Future<void>? _publicSans, _malayalam;
Future<List<ByteData>>? _publicSansFiles;

/* Whether `words` hold any Malayalam letter. */
bool hasMalayalam(String words) => _malayalamLetter.hasMatch(words);
final _malayalamLetter = RegExp('[\u0D00-\u0D7F]');

const _publicSansNames = ['PublicSans-Regular', 'PublicSans-Medium', 'PublicSans-SemiBold', 'PublicSans-Bold'];

/* Public Sans's files, fetched and held in memory. The face is not made from them here. */
Future<List<ByteData>> fetchPublicSans() => _publicSansFiles ??=
    Future.wait([for (final f in _publicSansNames) rootBundle.load('assets/fonts/$f.ttf')])
        .catchError((Object e, StackTrace s) {
      _publicSansFiles = null;
      Error.throwWithStackTrace(e, s);
    });

/* The face, made from the files fetchPublicSans holds (fetched now if they are not held yet). */
Future<void> loadPublicSans() => _publicSans ??= _register('Public Sans', fetchPublicSans(), () => _publicSans = null);

Future<void> loadMalayalam() => _malayalam ??= _load('Noto Sans Malayalam',
    ['NotoSansMalayalam-Regular', 'NotoSansMalayalam-SemiBold', 'NotoSansMalayalam-Bold'], () => _malayalam = null);

/* Lets go of Public Sans's held files and its face, so a test can fetch and load them again. */
@visibleForTesting
void forgetPublicSans() => _publicSans = _publicSansFiles = null;

/* The faces' files, each with its own weight inside it, under one family. */
Future<void> _load(String family, List<String> files, void Function() forget) {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(rootBundle.load('assets/fonts/$f.ttf'));
  }
  return loader.load().catchError((Object e, StackTrace s) {
    forget();
    Error.throwWithStackTrace(e, s);
  });
}

/* A face made from files already fetched. */
Future<void> _register(String family, Future<List<ByteData>> files, void Function() forget) async {
  try {
    final loader = FontLoader(family);
    for (final f in await files) {
      loader.addFont(Future.value(f));
    }
    await loader.load();
  } catch (_) {
    forget();
    rethrow;
  }
}
