/* Back up and move, as flows any screen can run (spec decisions 14–17): everything she made saved as one file,
   or a file opened to replace what is on this device — after she is asked, with the offer to save a backup of this
   device first. The Back up sheet runs them (redesign decision 13).
   What happened is said through `say` (`failed` when it went wrong; '' clears what was said); `busy`, when given,
   is told as the work starts. */
import 'package:flutter/material.dart';
import '../data/backup.dart';
import '../downloads/delivery.dart';
import '../l10n/app_localizations.dart';
import '../studio/controller.dart';
import 'files.dart';
import '../platform/report.dart';

typedef Say = void Function(String text, {bool failed});

enum _Answer { saveFirst, replace, cancel }

/* `kept` only when the file was made and is known to have gone somewhere; `notKept` when she dismissed the share
   sheet (nothing is said: nothing was saved); `failed` when it could not be made. */
enum BackupSaved { kept, notKept, failed }

Future<BackupSaved> exportBackupNow({required StudioController c, required Delivery delivery, Rect? origin,
    required Say say, required L words, VoidCallback? busy}) async {
  busy?.call();
  try {
    final bytes = await exportBackup(c.shelf.db, c.side);
    final name = backupFileName(DateTime.now());
    if (!await delivery.saveBackup(bytes, name, origin: origin)) {
      say('');
      return BackupSaved.notKept;
    }
    say(words.deviceExportDone(name));
    return BackupSaved.kept;
  } catch (e, s) {
    if (e is! BackupError) reportError(e, s, 'while a backup was handed over');
    // The zip code would not load (offline, or the release gone): the words an import says then.
    say(e is BackupError && e.key == 'notLoaded' ? words.clothErrorsPieceFailed : words.deviceBackupFailed, failed: true);
    return BackupSaved.failed;
  }
}

/* The file is picked, then she is asked over `context` until she answers replace or cancel. */
Future<void> openBackupNow({required BuildContext context, required StudioController c, required Delivery delivery,
    required Files files, Rect? origin, required Say say, required L words, VoidCallback? busy}) async {
  final picked = await files.pickBackup();
  if (picked == null || !context.mounted) return; // she cancelled
  while (true) {
    if (!context.mounted) return;
    final answer = await showDialog<_Answer>(context: context, builder: (context) => _sure(context, words, picked.name));
    if (!context.mounted) return;
    if (answer == _Answer.saveFirst) {
      // Kept or not, the same question again: it never says a backup exists. A failure stops here, to be read.
      if (await exportBackupNow(c: c, delivery: delivery, origin: origin, say: say, words: words, busy: busy) ==
          BackupSaved.failed) {
        return;
      }
      continue;
    }
    if (answer != _Answer.replace) return;
    busy?.call();
    try {
      await c.importFile(picked.bytes);
      say(words.deviceImportDone(picked.name));
    } on BackupError catch (e) {
      say(switch (e.key) {
        'notBackup' => words.deviceNotBackup,
        'tooNew' => words.deviceTooNew,
        // The studio's own code would not load (offline, or the release gone): the words the cloth sheets say then.
        'notLoaded' => words.clothErrorsPieceFailed,
        _ => words.canvasSaveFailed(words.deviceStorageFailed),
      }, failed: true);
    } catch (e, s) {
      reportError(e, s, 'while a backup replaced this device');
      say(words.canvasSaveFailed(words.deviceStorageFailed), failed: true);
    }
    return;
  }
}

Widget _sure(BuildContext context, L words, String file) {
  Widget answer(_Answer a, String text) => TextButton(onPressed: () => Navigator.of(context).pop(a), child: Text(text));
  // A question to read, not a banner: at most a reading measure wide.
  return AlertDialog(
    constraints: const BoxConstraints(minWidth: 280, maxWidth: 480),
    content: Text(words.deviceImportSure(file)),
    actions: [
      answer(_Answer.saveFirst, words.deviceImportSaveFirst),
      answer(_Answer.replace, words.deviceImportReplace),
      answer(_Answer.cancel, words.deviceImportCancel),
    ],
  );
}
