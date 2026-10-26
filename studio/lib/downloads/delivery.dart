import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/* Where the files she takes away go: saved, handed to another app, or printed. A test
   passes its own. `origin` is the row or button that asked, in global coordinates: an
   iPad's share sheet is a popover and points at it. */
abstract interface class Delivery {
  Future<void> savePhoto(Uint8List png, String file);
  Future<void> sharePdf(Uint8List pdf, String file, {Rect? origin});
  /* A saved picture handed to another app: Share… on View. */
  Future<void> sharePhoto(Uint8List png, String file, {Rect? origin});
  /* True only when the file is known to have gone somewhere: a backup she did not keep must never
     be taken for one she did, or "save a backup first" would let her replace everything with no copy. */
  Future<bool> saveBackup(Uint8List zip, String file, {Rect? origin});
}

/* The device's own: a download on the web, a save dialog or the share sheet on a phone. */
class PlatformDelivery implements Delivery {
  PlatformDelivery();

  /* A download on the web, a save dialog on a phone; null back from it is her cancelling. */
  @override
  Future<void> savePhoto(Uint8List png, String file) async {
    await FilePicker.saveFile(fileName: file, bytes: png, mimeType: 'image/png');
  }

  /* A download on the web, the share and print sheet on a phone. */
  @override
  Future<void> sharePdf(Uint8List pdf, String file, {Rect? origin}) async {
    await Printing.sharePdf(bytes: pdf, filename: file, bounds: origin);
  }

  /* The phone's share sheet, as a backup is handed over; on the web the browser's own (Web Share), or a download
     where it cannot share a file (share_plus's fallback). */
  @override
  Future<void> sharePhoto(Uint8List png, String file, {Rect? origin}) async {
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: [file], sharePositionOrigin: origin));
  }

  /* Spec decision 14: handed to the share sheet on a phone, a download on the web. The web's download
     always starts (file_picker_web returns null either way). On a phone only `success` counts: the sheet
     dismissed, or a platform that cannot tell what she did (`unavailable`), is not a kept backup. */
  @override
  Future<bool> saveBackup(Uint8List zip, String file, {Rect? origin}) async {
    if (kIsWeb) {
      await FilePicker.saveFile(fileName: file, bytes: zip, mimeType: 'application/zip');
      return true;
    }
    final r = await SharePlus.instance.share(ShareParams(files: [XFile.fromData(zip, mimeType: 'application/zip')],
        fileNameOverrides: [file], sharePositionOrigin: origin));
    return r.status == ShareResultStatus.success;
  }
}
