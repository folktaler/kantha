/* Add pieces from one photo on a phone, on its own finder (opencv_dart in its isolate): a photo of many pieces opens
   "Are these your pieces?", then "Your cloths", and Add puts one cloth per cloth found into her box, all at once.
   Run on a device or emulator: flutter test integration_test/many_pieces_test.dart -d <device>. (The web's finder
   has its own checks: tool/finder_bench.dart and the browser check of the sheet.)
   The photo is drawn here: 9 pieces of 3 cloths laid apart on a table. To run it on a real photo instead, put the
   photo where the app can read it and name it: --dart-define=KANTHA_MANY_PHOTO=/path/on/the/device.jpg (on an Android
   emulator, `adb push` it to /data/local/tmp and `adb shell chmod 644` it; r3-stacks.jpg gave 26 pieces and 24 cloths
   there on 17 November 2026, as on the web). */
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:kantha_studio/cloth/photo_source.dart';
import 'package:kantha_studio/main.dart';
import 'support.dart';

const _photoPath = String.fromEnvironment('KANTHA_MANY_PHOTO');

/* One photo of many pieces: the file named by KANTHA_MANY_PHOTO, or 9 pieces of 3 cloths, 220 px each, a gap of
   100 px between them, on a pale table. */
class ManyPieces implements PhotoSource {
  @override
  Future<Uint8List?> pick({required bool camera}) async {
    if (_photoPath.isNotEmpty) return File(_photoPath).readAsBytes();
    const cloths = [(178, 34, 52), (32, 52, 110), (214, 160, 30)];
    final photo = img.Image(width: 1400, height: 1100)..clear(img.ColorRgb8(236, 230, 214));
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final (r, g, b) = cloths[(row + col) % 3];
        final x = 160 + col * 320, y = 110 + row * 320;
        img.fillRect(photo, x1: x, y1: y, x2: x + 219, y2: y + 219, color: img.ColorRgb8(r, g, b));
      }
    }
    return img.encodePng(photo);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one photo of many pieces: she checks them, then her cloths go into her box', (t) async {
    await runKantha(photos: ManyPieces(), delivery: CaptureDelivery(), database: freshDatabase('many'));
    await settle(t, 5);
    await startFromSample(t);
    final box = await addOwnBox(t);
    final db = appShelf(t).db;

    await clothTab(t);
    await tapIt(t, find.byKey(const ValueKey('add-pieces'))); await settle(t);
    await tapIt(t, inSheet(find.text('Photo of the pieces')));
    final watch = Stopwatch()..start();
    await waitFor(t, find.text('Are these your pieces?'), seconds: 60);
    debugPrint('many_pieces: the finder looked in ${watch.elapsedMilliseconds} ms');
    final count = RegExp(r'^(\d+) pieces$');
    final shown = find.byWidgetPredicate((w) => w is Text && count.hasMatch(w.data ?? ''));
    final found = int.parse(count.firstMatch(t.widget<Text>(inSheet(shown).first).data!)![1]!);
    debugPrint('many_pieces: $found pieces found');
    if (_photoPath.isEmpty) expect(found, 9, reason: 'the 9 pieces drawn');

    await tapIt(t, inSheet(find.text('Next')));
    await waitFor(t, find.text('Your cloths'), seconds: 60);
    final add = find.byWidgetPredicate((w) => w is Text && RegExp(r'^Add \d+ pieces to box$').hasMatch(w.data ?? ''));
    await waitFor(t, inSheet(add));
    await tapIt(t, inSheet(add).first);
    var mine = <Object>[];
    for (var i = 0; i < 600 && mine.isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 100));
      mine = [for (final c in await db.select(db.cloths).get()) if (c.box == box) c];
    }
    debugPrint('many_pieces: ${mine.length} cloths added to her box');
    expect(mine, isNotEmpty, reason: 'her cloths went into the box');
    if (_photoPath.isEmpty) expect(mine, hasLength(3), reason: 'the 3 cloths drawn');
    await waitFor(t, find.textContaining('Photograph the next one.'));
    await tapIt(t, inSheet(find.text('Done'))); await settle(t);
    expect(find.byType(BottomSheet), findsNothing, reason: 'Done closes Add pieces');
  });
}
