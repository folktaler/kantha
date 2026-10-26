/* Run by flutter test before every test file (flutter_test's test config), on the real clock. What the app loads when
   it first needs it — the faces of lib/platform/fonts.dart and the libraries imported `deferred as` — is loaded here
   first. The VM keeps one load per font family and per library: one begun on a widget test's fake clock and left
   unfinished when that test ends would hold every later test in the file. */
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/backup.dart' show loadBackupCode;
import 'package:kantha_studio/data/sample_box.dart' show loadSwatches;
import 'package:kantha_studio/platform/fonts.dart';
import 'package:kantha_studio/studio/phone/cloth_sheet.dart' show loadClothSheets;
import 'package:kantha_studio/studio/take_menus.dart' show loadSheetPdf;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // The browser tests (flutter test --platform chrome) pump no widgets: nothing there runs on a fake clock.
  if (kIsWeb) return testMain();
  TestWidgetsFlutterBinding.ensureInitialized();
  await Future.wait([loadPublicSans(), loadMalayalam(), loadBackupCode(), loadSheetPdf(), loadSwatches(),
      loadClothSheets()]);
  await testMain();
}
