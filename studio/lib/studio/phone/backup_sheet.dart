/* The Back up or move sheet (redesign handover, Bottom sheets; decision 13): the two rows run the save and open
   flows (backup_flows.dart), with their questions. A row closes the sheet first, so what happened is said in a toast on the
   studio, where it can be read. */
import 'package:flutter/widgets.dart';
import '../../backup/backup_flows.dart';
import '../../backup/files.dart';
import '../../downloads/delivery.dart';
import '../../l10n/app_localizations.dart';
import '../controller.dart';
import 'phone_sheet.dart';
import 'phone_toast.dart';

Future<void> showBackupSheet(BuildContext context, {required StudioController c, required Delivery delivery,
    required Files files, required Toaster toaster}) {
  final words = L.of(context);
  void say(String text, {bool failed = false}) => text.isEmpty ? toaster.clear() : toaster.say(text);
  // Where an iPad's share sheet points: the row that asked, measured before the sheet goes.
  Rect? rectOf(BuildContext row) {
    final box = row.findRenderObject();
    return box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
  }
  return showPhoneSheet<void>(
    context,
    title: words.deviceBackupTitle,
    intro: words.deviceBackupIntro,
    builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Builder(builder: (row) => SheetRow(name: words.deviceExportButton, onPressed: () {
        final origin = rectOf(row);
        Navigator.of(sheet).pop();
        exportBackupNow(c: c, delivery: delivery, origin: origin, say: say, words: words);
      })),
      Builder(builder: (row) => SheetRow(name: words.deviceImportButton, note: words.deviceImportNote, onPressed: () {
        final origin = rectOf(row);
        Navigator.of(sheet).pop();
        // Asked over the studio, which stays when the sheet has gone.
        if (context.mounted) {
          openBackupNow(context: context, c: c, delivery: delivery, files: files, origin: origin, say: say, words: words);
        }
      })),
    ]),
  );
}
