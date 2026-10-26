import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../solver/geometry.dart' show cells;
import '../studio/shelf_feed.dart';
import 'paper.dart';

/* The words the files carry, decided by the owner on 6 Oct:
   the sheet's footer, and the photo's four caption lines. */
({String footer, List<String> caption}) wordsFor(L l, DesignView d) => (
      footer: '${d.name} · ${l.canvasMadeWith}',
      caption: [d.name, '${l.layoutTitle(d.layout)} — ${l.layoutName(d.layout)}', l.canvasUpcycled('$cells'), l.canvasMadeWith],
    );

/* Each page's footer on `paper`: one page's is the footer alone; on more than one, each starts with which page it is,
   so a long name cut short never takes the page number with it. */
List<String> footersFor(L l, DesignView d, Paper paper) {
  final footer = wordsFor(l, d).footer, pages = pagesOf(paper).length;
  return [for (var p = 1; p <= pages; p++) pages == 1 ? footer : '${l.canvasSheetPage('$p', '$pages')} · $footer'];
}
