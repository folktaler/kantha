import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/data/database.dart';
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/platform/solver_runner.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/solver/solve_layout.dart';
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/shelf_feed.dart';
import '../fixtures/fixtures.g.dart' as g;
import 'db.dart';
import 'files_fixture.dart' show testSideDb;
import 'spread.dart';

export 'spread.dart';

/* Her Box 1 as the pool fixture: 33 cloths of hers, C-1 … C-33, in the recorded pool's colours, pieces
   spread to 105, each with the same small photo. Written straight into the database, as an import writes
   rows, with the cloth counter past them, so the next cloth made is C-34 and the next box Box 2. */
Future<int> seedFixtureBox(Shelf shelf) async {
  final p = jsonDecode(g.pool) as Map<String, dynamic>;
  final stock = spread([for (final s in p['stock'] as List) s as int]);
  final labs = p['lab'] as List;
  double d(Object? v) => (v as num).toDouble();
  final box = await shelf.makeBox();
  final db = shelf.db, t0 = DateTime.utc(2026, 10, 7);
  await db.batch((b) {
    b.insertAll(db.cloths, [
      for (var i = 0; i < labs.length; i++)
        ClothsCompanion.insert(id: 'C-${i + 1}', box: box, name: 'C-${i + 1} cloth', fabric: 'Cotton', pieces: stock[i],
            l: d(labs[i][0]), a: d(labs[i][1]), b: d(labs[i][2]), spread: 0, colour: 'cloth', photo: fixtureJpeg,
            added: t0.add(Duration(seconds: i))),
    ]);
    b.insert(db.counters, CountersCompanion.insert(name: 'cloth', next: labs.length + 1), mode: InsertMode.insertOrReplace);
  });
  return box;
}

/* The small photo every fixture cloth carries, and a measurement for a cloth a test stores directly. */
final fixtureJpeg = img.encodeJpg(img.Image(width: 8, height: 8)..clear(img.ColorRgb8(200, 190, 170)));
Measured measuredFor({double l = 50, double a = 0, double b = 0, double spread = 0}) =>
    Measured(lab: (l: l, a: a, b: b), name: 'grey', spread: spread, width: 8, height: 8);

var _madeForTest = 0;

/* A solver that answers at once: each seed deals the members in a different turn,
   and turns the squares differently, so a fresh deal is visibly a different grid. */
class QuickSolver implements SolverRunner {
  int calls = 0;
  @override
  void setPool(Base base) {}
  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) async {
    calls++;
    return LayoutSolve(true, [for (var i = 0; i < cells; i++) members[(i + seed) % members.length]],
        [for (var i = 0; i < cells; i++) (i + seed) % 4]);
  }
  @override
  void dispose() {}
}

/* As the real solver answers: a box short of 35 pieces has no arrangement (decision 14). QuickSolver deals any box. */
class StockSolver extends QuickSolver {
  List<int> _stock = const [];
  @override
  void setPool(Base base) => _stock = base.stock;
  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) async =>
      members.fold(0, (n, m) => n + _stock[m]) < cells ? const LayoutSolve(false, null, null) : super.solve(layout, members, mount, seed);
}

/* A solver that fails, as a worker that is missing or crashed does. */
class FailingSolver implements SolverRunner {
  @override
  void setPool(Base base) {}
  @override
  Future<LayoutSolve> solve(LayoutKey layout, List<int> members, Mount mount, int seed) async =>
      throw StateError('the solver is not there');
  @override
  void dispose() {}
}

/* A shelf whose saves wait until the test lets them through. */
class SlowShelf extends Shelf {
  SlowShelf(super.db);
  Completer<void>? gate;
  @override
  Future<({DesignRow design, bool replaced})> saveDesign(DesignInput d, {String? replacing}) async {
    await gate?.future;
    return super.saveDesign(d, replacing: replacing);
  }
}

/* A shelf whose making or deleting of a box, or renaming, duplicating or deleting of a design, fails with the error the
   test sets, until it clears it. */
class FlakyShelf extends Shelf {
  FlakyShelf(super.db);
  ShelfError? failMake, failDelete, failDesign;
  @override
  Future<({int id, int? number})> makeNumberedBox({bool sample = false}) =>
      failMake != null ? Future.error(failMake!) : super.makeNumberedBox(sample: sample);
  @override
  Future<void> deleteBox(int id, {required Set<String> cloth}) =>
      failDelete != null ? Future.error(failDelete!) : super.deleteBox(id, cloth: cloth);
  @override
  Future<DesignRow> renameDesign(String id, String name) => failDesign != null ? Future.error(failDesign!) : super.renameDesign(id, name);
  @override
  Future<DesignRow> duplicateDesign(String id, String name) =>
      failDesign != null ? Future.error(failDesign!) : super.duplicateDesign(id, name);
  @override
  Future<void> deleteDesign(String id) => failDesign != null ? Future.error(failDesign!) : super.deleteDesign(id);
}

/* The studio's controller on a test shelf, fed and started. `seeded`: her Box 1 holds the pool fixture
   (when the shelf has no box yet), so the board is arranged; without it the studio starts empty, on the card. */
Future<({StudioController c, Shelf shelf})> studio({SolverRunner? solver, int? wantedBox, Shelf? on, bool seeded = true}) async {
  final shelf = on ?? Shelf(memoryDb());
  if (seeded && (await shelf.watchBoxes().first).isEmpty) await seedFixtureBox(shelf);
  var seed = 0;
  final c = StudioController(shelf: shelf, solver: solver ?? QuickSolver(), words: lookupL(const Locale('en')),
      seeds: () => ++seed, side: testSideDb);
  final feed = shelfFeed(shelf);
  final first = Completer<void>();
  final sub = feed.listen((s) { c.restock(s); if (!first.isCompleted) first.complete(); });
  addTearDown(sub.cancel);
  await first.future;
  c.start(wantedBox: wantedBox);
  controllerOf[shelf] = c;
  await pumpEventQueue();
  return (c: c, shelf: shelf);
}

/* The controller each test's shelf feeds, so a helper on the shelf can turn the studio to a box. */
final controllerOf = Expando<StudioController>('controller');

extension ShelfForTest on Shelf {
  /* One cloth of hers in `box` with `pieces` pieces, measured as a colour of its own (each call a little
     further round the hue wheel). Run it inside tester.runAsync in a widget test. Returns the cloth's id. */
  Future<String> addPiecesForTest(int box, int pieces) async {
    final n = _madeForTest++, turn = n * 1.1;
    final photo = img.encodeJpg(img.Image(width: 8, height: 8)..clear(img.ColorRgb8(40 + 30 * (n % 6), 90, 160 - 20 * (n % 6))));
    final row = await addCloth(box: box, photo: photo, fabric: 'Cotton', pieces: pieces,
        measured: Measured(lab: (l: 30.0 + 8 * (n % 6), a: 40 * math.cos(turn), b: 40 * math.sin(turn)),
            name: 'cloth', spread: 1, width: 8, height: 8));
    return row.id;
  }

  /* A new box (Box 2 beside the seeded fixture; Box 1 on an unseeded shelf) with one cloth of hers in it
     (a plain teal photo, `fabric` as stored, `boxPieces` pieces), and the studio turned to it. Returns the
     cloth's id. Run it inside tester.runAsync. */
  Future<String> addClothForTest({required int boxPieces, String fabric = 'Cotton'}) async {
    final box = await makeBox();
    final photo = img.encodeJpg(img.Image(width: 400, height: 400)..clear(img.ColorRgb8(30, 120, 140)), quality: 90);
    final row = await addCloth(box: box, photo: photo, measured: measureBytes(photo), fabric: fabric, pieces: boxPieces);
    // The watch answers on the event loop: let it reach the studio before it turns to the box.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controllerOf[this]?.openBox(box);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return row.id;
  }

  /* The cloth gone and its designs left, as an older tab removes it, or as a backup made before 20 Oct may hold it:
     the way a design whose cloth has gone still comes about. */
  Future<void> removeClothLeavingDesigns(String id) => (db.delete(db.cloths)..where((c) => c.id.equals(id))).go();
}

Future<void> settle() => pumpEventQueue();
