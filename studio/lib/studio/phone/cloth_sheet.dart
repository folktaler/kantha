/* Add a piece and Fix this cloth as sheets (redesign handover, Bottom sheets and "Add a piece sheet (batch entry)";
   decision 3). Add a piece is titled as it is and stays open between adds; Done, Close, back, Escape or a tap on the
   scrim closes it, adding a photo still waiting first (DECISIONS 58). Fix this cloth is titled with the cloth's name and closes once it has saved or removed it.
   Neither is dragged down to close: a downward stroke on the crop square would take the sheet with it; and while a
   finger is on the crop the sheet does not scroll, so the stroke moves the square. One at a time: a second press while
   one is opening or open does nothing (a second fix sheet beneath would hold the cloth as it was before a save). */
import 'package:flutter/material.dart';
// The cards, the cropper and the photo work load when a sheet first opens, or just after the studio's first frame
// (loadClothSheets), not with the first screen (his decision, 20 Oct).
import '../../cloth/add_cloth.dart' deferred as add;
import '../../cloth/fix_cloth.dart' deferred as fix;
import '../../cloth/parts.dart' show reportClothError;
import '../../cloth/photo_source.dart';
import '../../data/database.dart';
import '../../platform/deferred.dart';
import '../controller.dart';
import 'phone_sheet.dart';
import 'phone_theme.dart';

/* What the two sheets need, loaded once: the app asks for it after its first frame, so a sheet opens without waiting.
   A test sets loadClothSheetsWith to stand in a load that fails. */
Future<void> loadClothSheets() => Future.wait([add.loadLibrary(), fix.loadLibrary()]);
@visibleForTesting
Future<void> Function() loadClothSheetsWith = loadClothSheets;

/* A load that failed (offline, or the release gone from the server) is asked for once more (loadTwice); a second
   failure is false, and the sheet says so rather than not opening. */
Future<bool> _sheetsLoaded() async {
  try {
    await loadTwice(loadClothSheetsWith);
    return true;
  } catch (e, s) {
    reportClothError(e, s, 'while the cloth sheets loaded, asked twice');
    return false;
  }
}

/* The studios with a cloth sheet opening or open. */
final _opening = Expando<bool>('cloth sheet');

Future<void> showClothSheet(BuildContext context, {required ClothOpen open, required StudioController c,
    required PhotoSource photos}) async {
  if (_opening[c] ?? false) return;
  _opening[c] = true;
  try {
    await _show(context, open, c, photos);
  } finally {
    _opening[c] = null;
  }
}

Future<void> _show(BuildContext context, ClothOpen open, StudioController c, PhotoSource photos) async {
  final loaded = await _sheetsLoaded();
  if (!context.mounted) return;
  final words = c.words;
  if (!loaded) {
    return showPhoneSheet<void>(context, title: open.kind == ClothOpenKind.add ? words.clothTitle : words.clothFixTitle,
        builder: (context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Semantics(
            liveRegion: true, child: Text(words.clothErrorsPieceFailed, style: pText(PType.bodySmall, color: PhonePalette.red)))));
  }
  // A finger is on the crop: the sheet holds still. (Not disposed: the closing sheet may still be listening.)
  final held = ValueNotifier(false);
  Widget body(Widget card) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: card);
  // The sheet goes, if it is still the one on top: a save may finish after a tap on the scrim has closed it.
  void close(BuildContext context) {
    if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
  }
  if (open.kind == ClothOpenKind.add) {
    final box = open.box;
    // Where there is a finder the title follows the step (Add pieces, Are these your pieces?, Your cloths).
    final title = ValueNotifier(words.clothTitle);
    // Many pieces in: a toast says how many, and in which box.
    void manyAdded(int cloths, int pieces, int box) => c.tell(words.clothManyAdded(cloths, pieces,
        c.isSample(box) ? words.boxesSample : words.boxesName('${c.boxNumbers[box] ?? ''}')));
    return showPhoneSheet<void>(context, title: words.clothTitle, titleOf: title, drag: false, locked: held,
        builder: (context) => body(add.AddCloth(box: box, shelf: c.shelf, photos: photos, words: words,
            cropHeld: held, title: title, onManyAdded: manyAdded, onClose: () => close(context))));
  }
  // The cloth as stored, read first: its name is the sheet's title.
  ClothRow? row;
  var error = '';
  try {
    row = await c.shelf.clothById(open.clothId!);
    if (row == null) error = words.clothErrorsNoSuchCloth;
  } catch (e, s) {
    reportClothError(e, s, 'while a cloth was read to be fixed');
    error = words.clothErrorsPieceFailed;
  }
  if (!context.mounted) return;
  final cloth = row;
  if (cloth == null) {
    return showPhoneSheet<void>(context, title: words.clothFixTitle, builder: (context) => body(Semantics(
        liveRegion: true, child: Text(error, style: pText(PType.bodySmall, color: PhonePalette.red)))));
  }
  // All used: the pieces in stock, less those on the board, are none.
  final index = c.cloth.indexWhere((x) => x.id == cloth.id);
  final used = index < 0 ? 0 : (c.grid ?? const <int>[]).where((f) => f == index).length;
  final allUsed = index >= 0 && c.cloth[index].stock - used <= 0;
  return showPhoneSheet<void>(context, title: cloth.name, drag: false, locked: held, builder: (context) => body(fix.FixCloth(
      cloth: cloth, shelf: c.shelf, words: words, allUsed: allUsed, cropHeld: held, onDone: (_) => close(context),
      usedBy: () => c.designsUsing({cloth.id}).length, remove: () => c.removeCloth(cloth.id))));
}
