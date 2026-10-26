import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../solver/geometry.dart' show cells;
import '../studio/shelf_feed.dart';

/* The words the files carry, decided by the owner on 6 Oct:
   the sheet's footer, and the photo's four caption lines. */
({String footer, List<String> caption}) wordsFor(L l, DesignView d) => (
      footer: '${d.name} · ${l.canvasMadeWith}',
      caption: [d.name, '${l.layoutTitle(d.layout)} — ${l.layoutName(d.layout)}', l.canvasUpcycled('$cells'), l.canvasMadeWith],
    );
