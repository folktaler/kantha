@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/prepare.dart';
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/studio/phone/menu_panel.dart' show megabytes;
import 'package:kantha_studio/studio/phone/phone_toast.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import '../../support/pump.dart';
import '../../support/targets.dart';

const measured = Measured(lab: (l: 37.8, a: -6.3, b: -4.6), name: 'darkslategray', spread: 3.1, width: 100, height: 100);

/* A photo the size the studio stores: a noisy square, storedLongSide across, at storedJpegQuality. */
Uint8List storedPhoto(int seed) {
  final r = Random(seed);
  final im = img.Image(width: storedLongSide, height: storedLongSide);
  for (final p in im) {
    p..r = r.nextInt(256)..g = r.nextInt(256)..b = r.nextInt(256);
  }
  return img.encodeJpg(im, quality: storedJpegQuality);
}

/* Holds SQLite's VACUUM until `go` completes, so a test sees the studio while it runs. */
class HeldVacuum extends QueryInterceptor {
  var go = Completer<void>()..complete();
  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) async {
    if (statement == 'VACUUM') await go.future;
    return executor.runCustom(statement, args);
  }
}

final menu = find.byKey(const ValueKey('phone-menu')), space = key('menu-space'), freeButton = key('free-space');
Finder toast(String words) => find.descendant(of: find.byKey(const ValueKey('phone-toast')), matching: find.text(words));

void main() {
  late Directory dir;
  late File file;
  late HeldVacuum vacuum;
  setUp(() {
    vacuum = HeldVacuum();
    dir = Directory.systemTemp.createTempSync('kantha_menu_space_');
    file = File('${dir.path}/kantha.sqlite');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /* As a studio made before 20 Oct holds it (auto_vacuum NONE): Box 1 with 8 photos, 6 of them since removed. */
  Future<void> oldDatabase() async {
    final db = KanthaDatabase(NativeDatabase(file));
    final shelf = Shelf(db);
    final box = await shelf.makeBox();
    for (var i = 0; i < 8; i++) {
      await shelf.addCloth(box: box, photo: storedPhoto(i), measured: measured, fabric: 'Cotton', pieces: 1);
    }
    for (var i = 3; i <= 8; i++) {
      await shelf.removeCloth('C-$i');
    }
    await db.close();
  }

  /* The studio on a phone, on that file: `opfs` as drift reports OPFS or a phone's file (connect.dart freesSpace). */
  Future<Shelf> onOldDatabase(WidgetTester tester, {required bool opfs}) async {
    await tester.runAsync(oldDatabase);
    final db = KanthaDatabase(NativeDatabase(file).interceptWith(vacuum), freesSpace: () => opfs);
    addTearDown(() => tester.runAsync(db.close));
    final shelf = Shelf(db);
    await pumpStudio(tester, on: shelf, size: phone);
    return shelf;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(menu);
    await letWork(tester, done: () => space.evaluate().isNotEmpty);
  }

  String using(int bytes) => 'Kantha is using ${megabytes(bytes)} MB on this device';

  testWidgets('on an old database on OPFS or a phone\'s file, most of it empty, the Menu says the room it takes and '
      'offers Free up space; pressed, "Freeing space…" stands over the studio, then a toast says what was freed, and '
      'the Menu no longer offers it', (tester) async {
    final shelf = await onOldDatabase(tester, opfs: true);
    final before = file.lengthSync();
    await openMenu(tester);
    expect(find.descendant(of: space, matching: find.text(using(before))), findsOneWidget);
    expect(freeButton, findsOneWidget);
    expect(find.descendant(of: freeButton, matching: find.text('Free up space')), findsOneWidget);
    checkTargets(tester, 44);

    vacuum.go = Completer<void>();
    await tester.tap(freeButton);
    await tester.pump();
    expect(key('menu-panel'), findsNothing, reason: 'the menu shuts');
    expect(find.text('Freeing space…'), findsOneWidget);
    // Nothing under it is reached: ≡ does not open the menu.
    await tester.tap(menu, warnIfMissed: false);
    await tester.pump();
    expect(key('menu-panel'), findsNothing);
    expect(await tester.binding.handlePopRoute(), isTrue, reason: 'Back is taken');
    await tester.pump();
    expect(find.text('Freeing space…'), findsOneWidget, reason: 'and does not close it');
    vacuum.go.complete();

    await letWork(tester, done: () => find.text('Freeing space…').evaluate().isEmpty);
    final after = file.lengthSync();
    expect(after, lessThan(before ~/ 2));
    expect(toast('Freed ${megabytes(before - after)} MB. Kantha is now using ${megabytes(after)} MB on this device.'),
        findsOneWidget);
    final av = await tester.runAsync(() => shelf.db.customSelect('PRAGMA auto_vacuum').getSingle());
    expect(av!.read<int>('auto_vacuum'), 1);

    await openMenu(tester);
    expect(find.descendant(of: space, matching: find.text(using(after))), findsOneWidget);
    expect(freeButton, findsNothing, reason: 'not offered again');
    await tester.pump(Toaster.showFor);
  });

  /* The Menu open, where no size line is to come: its rows are there, and neither the line nor the button. */
  Future<void> openMenuWithoutSpace(WidgetTester tester) async {
    await tester.tap(menu);
    await letWork(tester);
    expect(key('menu-panel'), findsOneWidget);
    expect(space, findsNothing);
    expect(freeButton, findsNothing);
  }

  testWidgets('on IndexedDB (freesSpace false) the same old database shows no size line and is never offered Free up '
      'space (owner, 22 Oct)', (tester) async {
    await onOldDatabase(tester, opfs: false);
    await openMenuWithoutSpace(tester);
  });

  testWidgets('on a database in memory, kept or not, there is no size line and Free up space is never offered',
      (tester) async {
    await pumpStudio(tester, size: phone);
    await openMenuWithoutSpace(tester);
    await tester.tap(menu);
    await tester.pumpAndSettle();

    await pumpStudio(tester, size: phone, kept: false);
    await openMenuWithoutSpace(tester);
  });

  testWidgets('if freeing fails, the toast says nothing was lost, the file is as it was, and the studio carries on: '
      'the Menu offers it again, and then it works', (tester) async {
    final shelf = await onOldDatabase(tester, opfs: true);
    final bytes = file.readAsBytesSync();
    // Another connection reading: the VACUUM cannot write its result, and fails.
    final reader = sqlite3.open(file.path)..execute('BEGIN');
    reader.select('SELECT count(*) FROM cloths');
    await openMenu(tester);
    await tester.tap(freeButton);
    await letWork(tester, done: () => find.textContaining('Nothing was lost').evaluate().isNotEmpty);
    expect(find.text('Freeing space…'), findsNothing);
    expect(tester.takeException(), isNotNull, reason: 'reported');
    expect(toast('Kantha could not free up space. Nothing was lost.'), findsOneWidget);
    expect(file.readAsBytesSync(), bytes);
    final cloth = await tester.runAsync(() => shelf.db.select(shelf.db.cloths).get());
    expect(cloth!.map((c) => c.id), ['C-1', 'C-2']);
    await tester.pump(Toaster.showFor);
    await tester.pumpAndSettle();

    reader..execute('COMMIT')..close();
    await openMenu(tester);
    expect(freeButton, findsOneWidget, reason: 'offered again');
    await tester.tap(freeButton);
    await letWork(tester, done: () => find.textContaining('Freed').evaluate().isNotEmpty);
    expect(file.lengthSync(), lessThan(bytes.length ~/ 2));
    await tester.pump(Toaster.showFor);
  });
}
