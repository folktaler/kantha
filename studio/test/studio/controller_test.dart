import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/backup.dart' show exportBackup;
import 'package:kantha_studio/data/shelf.dart';
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/studio/controller.dart';
import 'package:kantha_studio/studio/memory.dart';
import 'package:kantha_studio/studio/shelf_feed.dart' show DesignView;
import '../support/db.dart';
import '../support/files_fixture.dart' show testSideDb;
import '../support/studio_fixture.dart';

void main() {
  test('with her Box 1 able to fill a panel, the studio opens on it, arranged', () async {
    final s = await studio();
    expect((s.c.box, s.c.starting), (1, false));
    expect(s.c.grid, hasLength(cells));
    expect(s.c.solving, isFalse);
    expect(s.c.name, 'Chess');
  });

  test('going back to a template shows the arrangement she left there; pressing it again deals a new one', () async {
    final s = await studio();
    final first = List.of(s.c.grid!);
    s.c.loadLayout(LayoutKey.gradient);
    await settle();
    expect(s.c.grid, isNot(first));
    s.c.loadLayout(LayoutKey.contrast);
    expect(s.c.grid, first, reason: 'remembered, not solved again');
    s.c.loadLayout(LayoutKey.contrast);
    await settle();
    expect(s.c.grid, isNot(first), reason: 'the template already showing deals anew');
  });

  test('going back to a template shows the mount she chose and the name she typed there', () async {
    final s = await studio();
    s.c.setMount(Mount.frame);
    s.c.setName('For Amma');
    s.c.loadLayout(LayoutKey.wave);
    await settle();
    expect((s.c.mount, s.c.name), (Mount.frame, 'Wave'));
    s.c.setMount(Mount.tote);
    s.c.loadLayout(LayoutKey.contrast);
    expect((s.c.mount, s.c.name), (Mount.frame, 'For Amma'));
  });

  test('saving twice keeps one design, with the latest change', () async {
    final s = await studio();
    final id = await s.c.save();
    s.c.setName('Zinnia');
    expect(await s.c.save(), id);
    await settle();
    expect(s.c.saved.map((d) => (d.id, d.name)), [(id, 'Zinnia')]);
    expect(s.c.note, 'Saved to My designs.');
  });

  test('every note said is counted, so the same words said again are a new note', () async {
    final s = await studio();
    final c = s.c;
    expect(c.notes, 0);
    c.note = 'x';
    expect(c.notes, 1);
    c.note = '';
    expect(c.notes, 1, reason: 'clearing the note says nothing');
    c.note = 'x';
    expect(c.notes, 2);
  });

  test('the first save on this device says where it is kept; later saves, and a later visit, say Saved', () async {
    final s = await studio();
    expect(await s.shelf.setting(StudioController.savedOnceKey), isNull);
    await s.c.save();
    expect(s.c.note, 'Saved on this device. Back up from the menu to keep a copy.');
    expect(await s.shelf.setting(StudioController.savedOnceKey), isNotNull);
    await s.c.save();
    expect(s.c.note, 'Saved to My designs.');
    final again = await studio(on: s.shelf);
    await again.c.save();
    expect(again.c.note, 'Saved to My designs.', reason: 'the device remembers it was said');
  });

  test('in a browser that keeps nothing, every save says so, and nothing is remembered', () async {
    final s = await studio();
    s.c.storageKept = false;
    await s.c.save();
    expect(s.c.note, startsWith('This browser is not keeping'));
    expect(s.c.note, s.c.words.deviceNotKept);
    expect(await s.shelf.setting(StudioController.savedOnceKey), isNull);
    await s.c.save();
    expect(s.c.note, s.c.words.deviceNotKept);
    expect(await s.shelf.setting(StudioController.savedOnceKey), isNull);
  });

  test('zoom by percent: 60 to 160 of the fitted scale; 100 is Fit; never past the scale\'s limits', () async {
    final s = await studio();
    final c = s.c;
    c.zoomTo(160);
    expect((c.percent, c.zoomed), (160, true));
    c.zoomTo(100);
    expect((c.percent, c.zoomed), (100, false));
    c.zoomTo(60);
    expect(c.percent, 60);
    c.fitPpc = 30;
    c.zoomTo(160);
    expect(c.ppc, zoomMax);
  });

  test('saving a template she came back to keeps one design', () async {
    final s = await studio();
    final id = await s.c.save();
    s.c.loadLayout(LayoutKey.gradient);
    await settle();
    s.c.loadLayout(LayoutKey.contrast);
    expect(await s.c.save(), id);
    await settle();
    expect(s.c.saved, hasLength(1));
  });

  test('after deleting a saved design, coming back to its template and saving makes a new one', () async {
    final s = await studio();
    final id = await s.c.save();
    await s.c.deleteSaved(id!);
    s.c.loadLayout(LayoutKey.gradient);
    await settle();
    s.c.loadLayout(LayoutKey.contrast);
    final again = await s.c.save();
    expect(again, isNot(id));
    await settle();
    expect(s.c.saved.map((d) => d.id), [again]);
  });

  test('renamed from its card, the design on the board counts as saved under the new name', () async {
    final s = await studio();
    await s.c.save();
    await settle();
    await s.c.rename(s.c.saved.single, 'Zinnia border');
    expect(s.c.name, 'Zinnia border');
    expect(await s.c.takeAwayNow(), s.c.savedId, reason: 'DIY does not save it again');
  });

  test('+ New design deals a fresh arrangement on the same template, not yet saved', () async {
    final s = await studio();
    await s.c.save();
    final before = List.of(s.c.grid!);
    s.c.newDesign();
    await settle();
    expect((s.c.savedId, s.c.layout, s.c.name), (null, LayoutKey.contrast, 'Chess'));
    expect(s.c.grid, isNot(before));
  });

  test('opening a saved design opens the box it was made from; one whose cloth is gone opens nothing', () async {
    final s = await studio();
    final grid = List.of(s.c.grid!), rot = List.of(s.c.rot);
    expect(rot.toSet(), hasLength(greaterThan(1)), reason: 'the squares are turned, so a lost turn would show');
    await s.c.save();
    await settle();
    final d = s.c.saved.single;
    s.c.loadLayout(LayoutKey.heart);
    await settle();
    expect(s.c.grid, isNot(grid));
    expect(s.c.openSaved(d), isTrue);
    expect((s.c.layout, s.c.box, s.c.savedId), (LayoutKey.contrast, 1, d.id));
    expect(s.c.grid, grid, reason: 'a saved design reopens with its exact grid');
    expect(s.c.rot, rot, reason: 'and its exact turns');
    final gone = d.copyWithGrid(['C-999', ...d.grid.skip(1)]);
    expect(s.c.openSaved(gone), isFalse);
    expect(s.c.note, 'That design uses cloth that is no longer in the box.');
    expect(s.c.warn, isTrue);
  });

  test('when the device will not keep a save, she is told, and nothing else changes', () async {
    final s = await studio();
    await s.shelf.db.customStatement("CREATE TRIGGER refuse BEFORE INSERT ON designs BEGIN SELECT RAISE(ABORT, 'full'); END");
    expect(await s.c.save(), isNull);
    expect(s.c.note, 'Could not save: this device did not keep it');
    expect((s.c.warn, s.c.busy, s.c.savedId), (true, false, null));
  });

  test('a box that cannot fill a template says why, on the template and on the board', () async {
    final s = await studio();
    final heart = s.c.feasible[LayoutKey.heart]!;
    if (!heart.fills) {
      s.c.loadLayout(LayoutKey.heart);
      expect(s.c.note, startsWith('This box cannot fill this layout:'));
    }
    expect(s.c.feasible.length, LayoutKey.values.length);
  });

  test('opening a box of her own that cannot fill the template on the board says why there; her new cloth joins the end', () async {
    final s = await studio();
    s.c.loadLayout(LayoutKey.heart);
    await settle();
    expect(s.c.feasible[LayoutKey.heart]!.fills, isTrue, reason: 'Box 1 fills the heart');
    final before = s.c.cloth.length;
    final mine = await s.shelf.makeBox();
    await s.shelf.addCloth(box: mine, photo: Uint8List.fromList(List.filled(8, 1)),
        measured: const Measured(lab: (l: 40, a: 5, b: 5), name: 'dimgray', spread: 2, width: 10, height: 10),
        fabric: 'Cotton', pieces: 3);
    await settle();
    expect(s.c.cloth.length, before + 1);
    expect(s.c.cloth.last.box, mine, reason: 'Box 1 keeps its places; the new cloth goes on the end');
    s.c.openBox(mine);
    expect(s.c.feasible[LayoutKey.heart]!.fills, isFalse, reason: 'one grey cloth has no red for the heart');
    expect(s.c.note, startsWith('This box cannot fill this layout:'));
    expect((s.c.warn, s.c.mayEdit, s.c.box), (true, true, mine));
  });

  test('turning from an arranged full box to one of 10 pieces the solver cannot arrange: the board is empty under the note, '
      'not the full box\'s cloth (decision 14)', () async {
    final s = await studio(solver: StockSolver());
    await settle();
    expect(s.c.grid, isNotNull);
    expect(s.c.rot, isNot(noTurns()), reason: 'the full box\'s arrangement has turned pieces');
    final short = await s.shelf.makeBox();
    await s.shelf.addCloth(box: short, photo: fixtureJpeg, measured: measuredFor(l: 40), fabric: '', pieces: 5);
    await s.shelf.addCloth(box: short, photo: fixtureJpeg, measured: measuredFor(l: 60), fabric: '', pieces: 5);
    await settle();
    expect(s.c.piecesIn(short), 10);
    s.c.openBox(short);
    await settle();
    expect((s.c.box, s.c.solving, s.c.grid), (short, false, null));
    expect(s.c.rot, noTurns(), reason: 'no turns kept from the full box\'s arrangement');
    expect((s.c.note, s.c.warn), (s.c.words.canvasCantSolve, true));
  });

  test('when the solver fails, the board stops solving and says it could not arrange; the error is reported', () async {
    final reported = <Object>[];
    final was = FlutterError.onError;
    FlutterError.onError = (d) => reported.add(d.exception);
    addTearDown(() => FlutterError.onError = was);
    final s = await studio(solver: FailingSolver());
    expect(s.c.solving, isFalse);
    expect(s.c.note, s.c.words.canvasCantSolve);
    expect(s.c.warn, isTrue);
    expect(reported, [isA<StateError>()]);
  });

  test('a save that lands after she has dealt a new design does not claim the new one as saved', () async {
    final shelf = SlowShelf(memoryDb());
    final s = await studio(on: shelf);
    final old = List.of(s.c.grid!);
    shelf.gate = Completer<void>();
    final saving = s.c.save();
    s.c.newDesign();
    await settle();
    expect(s.c.grid, isNot(old));
    final fresh = List.of(s.c.grid!);
    shelf.gate!.complete();
    final id = await saving;
    expect(id, isNotNull, reason: 'the old arrangement was still saved');
    expect((s.c.savedId, s.c.savedGrid, s.c.busy), (null, null, false));
    expect(s.c.memory[keyOf(1, LayoutKey.contrast)]!.grid, fresh, reason: 'the new deal stays the remembered one');
    expect(s.c.memory[keyOf(1, LayoutKey.contrast)]!.savedId, isNull);
    final again = await s.c.save();
    expect(again, isNot(id), reason: 'saving the new design never overwrites the old one');
  });

  test('changing the mount re-fits and tells the screen even when the pane is too small to fit', () async {
    final s = await studio();
    s.c.applyFit(const Size(100, 100));
    var told = 0;
    s.c.addListener(() => told++);
    s.c.setMount(Mount.frame);
    expect(told, greaterThan(0));
  });

  test('fitting the same pane again tells the screen nothing new', () async {
    final s = await studio();
    s.c.applyFit(const Size(1200, 760));
    var told = 0;
    s.c.addListener(() => told++);
    s.c.applyFit(const Size(1200, 760));
    expect(told, 0);
    s.c.applyFit(const Size(1400, 900));
    expect(told, 1);
  });

  test('a room smaller than one 24 px square (a route turning, the keyboard) leaves the scale as it was', () async {
    final s = await studio();
    s.c.applyFit(const Size(358, 400));
    final was = s.c.ppc;
    expect(was, greaterThan(fitLeast));
    for (final room in [const Size(358, 10), const Size(10, 400), Size.zero]) {
      s.c.applyFit(room);
      expect(s.c.ppc, was, reason: '$room');
    }
    s.c.applyFit(const Size(358, 30));
    expect(s.c.ppc, fitLeast, reason: 'a room a square fits in is fitted, and scrolls');
  });

  test('the thread on show is the one that clears this cloth best, and the stitches are Open', () async {
    final s = await studio();
    expect(s.c.thread, s.c.recommended.first.thread.key);
    expect((s.c.density.key, s.c.density.rows, s.c.density.per), ('open', 5, 5));
  });

  group('until a box of hers holds 35 pieces: the empty board, and nothing arranged', () {
    test('with no box of hers: starting, on no box, nothing arranged, and the solver never asked', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      expect((s.c.starting, s.c.box, s.c.grid, s.c.solving), (true, null, null, false));
      expect(solver.calls, 0);
    });

    test('a box made and left empty: the studio turns to it and is still starting; no other box is made', () async {
      final s = await studio(seeded: false);
      final box = await s.shelf.makeBox();
      await settle();
      expect((s.c.box, s.c.starting), (box, true));
      expect(s.c.ownBoxes, [box]);
    });

    test('the start lasts until her box holds 35 pieces; then the board arranges, on that box', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final box = await s.shelf.makeBox();
      for (var i = 0; i < 4; i++) {
        await s.shelf.addPiecesForTest(box, 7);
      }
      await settle();
      expect((s.c.piecesIn(box), s.c.starting, solver.calls), (28, true, 0));
      await s.shelf.addPiecesForTest(box, 7);
      await settle();
      expect((s.c.piecesIn(box), s.c.starting, s.c.box), (35, false, box));
      expect(solver.calls, 1, reason: 'arranged once the box can fill a panel');
      expect(s.c.grid, hasLength(cells));
    });

    test('35 pieces of one cloth end the start too: the box is hers to add to, and the board tries it', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final box = await s.shelf.makeBox();
      await s.shelf.addPiecesForTest(box, 35);
      await settle();
      expect((s.c.starting, s.c.box, s.c.mayEdit), (false, box, true));
      expect(solver.calls, 1);
    });

    test('the studio opens on her newest box that can fill a panel — not her first, nor a newer one that cannot', () async {
      final shelf = Shelf(memoryDb());
      await shelf.addPiecesForTest(await shelf.makeBox(), 40);
      final two = await shelf.makeBox();
      await shelf.addPiecesForTest(two, 36);
      await shelf.addPiecesForTest(await shelf.makeBox(), 3);
      final s = await studio(on: shelf);
      expect((s.c.box, s.c.starting), (two, false));
      expect(s.c.grid, hasLength(cells));
    });

    test('with no box able to fill a panel, it opens on her newest box, still starting', () async {
      final shelf = Shelf(memoryDb());
      await shelf.addPiecesForTest(await shelf.makeBox(), 20);
      final two = await shelf.makeBox();
      final s = await studio(on: shelf);
      expect((s.c.box, s.c.starting, s.c.grid), (two, true, null));
    });

    test('a full box fixed to 34 pieces: the empty board returns, nothing arranged on it, Save disabled', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final box = await s.shelf.makeBox();
      final ids = [for (var i = 0; i < 5; i++) await s.shelf.addPiecesForTest(box, 7)];
      await settle();
      expect(await s.c.save(), isNotNull);
      await settle();
      final calls = solver.calls;
      await s.shelf.editCloth(ids.last, fabric: 'Cotton', pieces: 6); // Fix this cloth: one fewer
      await settle();
      expect((s.c.piecesIn(box), s.c.starting), (34, true));
      expect((s.c.grid, s.c.solving, s.c.savedId, s.c.savedGrid, s.c.note), (null, false, null, null, ''));
      expect(await s.c.save(), isNull, reason: "nothing to save: the header's Save is drawn disabled when grid is null");
      expect(solver.calls, calls, reason: 'nothing is arranged on the empty board');
    });

    test('while the box is short, a saved design opens and takes the board; New design brings the empty board back', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final box = await s.shelf.makeBox();
      final ids = [for (var i = 0; i < 5; i++) await s.shelf.addPiecesForTest(box, 7)];
      await settle();
      await s.c.save();
      await settle();
      final design = s.c.saved.single;
      await s.shelf.editCloth(ids.last, fabric: 'Cotton', pieces: 6);
      await settle();
      expect(s.c.starting, isTrue);
      final calls = solver.calls;
      expect(s.c.openSaved(design), isTrue);
      expect((s.c.starting, s.c.savedId, s.c.box), (false, design.id, box), reason: 'the saved design holds the board while it is open');
      expect([for (final f in s.c.grid!) s.c.cloth[f].id], design.grid, reason: 'the board shows the saved design');
      s.c.newDesign();
      await settle();
      expect((s.c.starting, s.c.grid, s.c.savedId), (true, null, null), reason: 'the box is still short: the empty board is back');
      expect(solver.calls, calls, reason: 'nothing was arranged');
    });

    test('while the box is short, choosing a template keeps the empty board', () async {
      final s = await studio(seeded: false);
      final box = await s.shelf.makeBox();
      await s.shelf.addPiecesForTest(box, 20);
      await settle();
      s.c.loadLayout(LayoutKey.gradient);
      await settle();
      expect((s.c.layout, s.c.starting, s.c.grid, s.c.solving), (LayoutKey.gradient, true, null, false));
    });

    /* A box of five cloths, seven pieces each, with a design saved on it; then one cloth fixed to six, so
       the box is a piece short. Returns the box, the cloths' ids and the design. */
    Future<({int box, List<String> ids, DesignView design})> savedThenShort(({StudioController c, Shelf shelf}) s,
        {String? name}) async {
      final box = await s.shelf.makeBox();
      final ids = [for (var i = 0; i < 5; i++) await s.shelf.addPiecesForTest(box, 7)];
      await settle();
      if (name != null) s.c.setName(name);
      await s.c.save();
      await settle();
      final design = s.c.saved.single;
      await s.shelf.editCloth(ids.last, fabric: 'Cotton', pieces: 6);
      await settle();
      return (box: box, ids: ids, design: design);
    }

    test('holding a saved design while no box can fill and there is no Sample box, a template with an arrangement remembered from when the box was full brings the empty board back, not that arrangement', () async {
      final s = await studio(seeded: false);
      final box = await s.shelf.makeBox();
      final ids = [for (var i = 0; i < 5; i++) await s.shelf.addPiecesForTest(box, 7)];
      await settle();
      s.c.loadLayout(LayoutKey.gradient); // remembered for (box, gradient)
      await settle();
      s.c.loadLayout(LayoutKey.contrast);
      await settle();
      await s.c.save();
      await settle();
      final design = s.c.saved.single;
      await s.shelf.editCloth(ids.last, fabric: 'Cotton', pieces: 6);
      await settle();
      expect(s.c.openSaved(design), isTrue);
      s.c.loadLayout(LayoutKey.gradient);
      await settle();
      expect((s.c.starting, s.c.grid), (true, null), reason: 'the empty board comes back, nothing on it');
    });

    test('the screen is told when New design leaves a held design while the box is short: the empty board, no grid, no spinner', () async {
      final s = await studio(seeded: false);
      final d = await savedThenShort(s);
      expect(s.c.openSaved(d.design), isTrue);
      (bool, List<int>?, bool)? told;
      s.c.addListener(() => told = (s.c.starting, s.c.grid, s.c.solving));
      s.c.newDesign();
      await settle();
      expect(told, (true, null, false), reason: 'what the screen last heard is what the controller holds');
    });

    test('the screen is told when a box is opened while she is starting: no spinner left on', () async {
      final s = await studio(seeded: false);
      final one = await s.shelf.makeBox();
      await s.shelf.addPiecesForTest(one, 20);
      final two = await s.shelf.makeBox();
      await settle();
      expect((s.c.starting, s.c.box), (true, one));
      (bool, List<int>?, bool)? told;
      s.c.addListener(() => told = (s.c.starting, s.c.grid, s.c.solving));
      s.c.openBox(two);
      await settle();
      expect(told, (true, null, false));
    });

    test('a box dropping under 35 on a template it cannot fill leaves no note on the empty board', () async {
      final s = await studio(seeded: false);
      final box = await s.shelf.makeBox();
      final ids = [for (var i = 0; i < 5; i++) await s.shelf.addPiecesForTest(box, 7)];
      await settle();
      s.c.loadLayout(LayoutKey.heart);
      await settle();
      await s.shelf.editCloth(ids.last, fabric: 'Cotton', pieces: 6);
      await settle();
      expect(s.c.feasible[LayoutKey.heart]!.fills, isFalse, reason: 'this box cannot fill the heart');
      expect((s.c.starting, s.c.layout, s.c.note, s.c.warn), (true, LayoutKey.heart, '', false));
    });

    test('a saved design open when the box drops: filled again, the fresh board has the template\'s name, unsaved', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final d = await savedThenShort(s, name: 'Zinnia');
      expect(d.design.name, 'Zinnia');
      expect(s.c.name, 'Chess', reason: 'the cleared board keeps no saved name');
      await s.shelf.editCloth(d.ids.last, fabric: 'Cotton', pieces: 7);
      await settle();
      expect((s.c.starting, s.c.name, s.c.savedId), (false, 'Chess', null));
    });

    test('a box that drops and fills again is arranged afresh', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final d = await savedThenShort(s);
      final calls = solver.calls;
      expect((s.c.starting, s.c.grid), (true, null));
      await s.shelf.editCloth(d.ids.last, fabric: 'Cotton', pieces: 7);
      await settle();
      expect((s.c.starting, s.c.box, s.c.solving), (false, d.box, false));
      expect(s.c.grid, hasLength(cells));
      expect(solver.calls, calls + 1);
    });

    test('her box filling while she holds a saved design: the design stays on the board, nothing is arranged', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final d = await savedThenShort(s);
      expect(s.c.openSaved(d.design), isTrue);
      final calls = solver.calls, grid = List.of(s.c.grid!);
      await s.shelf.editCloth(d.ids.last, fabric: 'Cotton', pieces: 7);
      await settle();
      expect((s.c.starting, s.c.savedId, s.c.solving), (false, d.design.id, false));
      expect(s.c.grid, grid);
      expect(solver.calls, calls);
    });

    test('on a short box, another box filling turns the studio to it, arranged', () async {
      final solver = QuickSolver();
      final s = await studio(seeded: false, solver: solver);
      final short = await s.shelf.makeBox();
      await s.shelf.addPiecesForTest(short, 20);
      await settle();
      final other = await s.shelf.makeBox();
      await settle();
      s.c.openBox(short);
      await settle();
      expect((s.c.box, s.c.starting, solver.calls), (short, true, 0));
      await s.shelf.addPiecesForTest(other, 35);
      await settle();
      expect((s.c.box, s.c.starting, solver.calls), (other, false, 1));
      expect(s.c.grid, hasLength(cells));
    });

    test('while starting, a piece added on a template the box cannot fill leaves no note on the empty board; once full, it says so', () async {
      final s = await studio(seeded: false);
      final box = await s.shelf.makeBox();
      for (var i = 0; i < 2; i++) {
        await s.shelf.addPiecesForTest(box, 7);
      }
      await settle();
      s.c.loadLayout(LayoutKey.heart);
      await settle();
      await s.shelf.addPiecesForTest(box, 7);
      await settle();
      expect(s.c.feasible[LayoutKey.heart]!.fills, isFalse, reason: 'this box cannot fill the heart');
      expect((s.c.starting, s.c.layout, s.c.note, s.c.warn), (true, LayoutKey.heart, '', false));
      // Once the box fills, the note says why the heart cannot be made, as before (the test's solver then
      // answers at once and its arrangement replaces the note, so what the screen was told is read).
      final told = <String>[];
      s.c.addListener(() => told.add(s.c.note));
      for (var i = 0; i < 2; i++) {
        await s.shelf.addPiecesForTest(box, 7);
      }
      await settle();
      expect((s.c.starting, s.c.layout), (false, LayoutKey.heart));
      expect(s.c.feasible[LayoutKey.heart]!.fills, isFalse);
      expect(told, contains(startsWith('This box cannot fill this layout:')));
    });

    test('a first visit with no box: the empty board, and no note or warning on it', () async {
      final s = await studio(seeded: false);
      expect((s.c.starting, s.c.box, s.c.note, s.c.warn), (true, null, '', false));
    });

    test('while starting, a template chosen, a box opened, and an import of short boxes leave no note', () async {
      final s = await studio(seeded: false);
      final one = await s.shelf.makeBox();
      await s.shelf.addPiecesForTest(one, 7);
      final two = await s.shelf.makeBox();
      await settle();
      s.c.loadLayout(LayoutKey.heart);
      await settle();
      expect((s.c.starting, s.c.note, s.c.warn), (true, '', false));
      s.c.openBox(two);
      await settle();
      expect((s.c.starting, s.c.box, s.c.note, s.c.warn), (true, two, '', false));
      final from = Shelf(memoryDb());
      await from.addPiecesForTest(await from.makeBox(), 20);
      await s.c.importFile(await exportBackup(from.db, testSideDb));
      await settle();
      expect((s.c.starting, s.c.layout, s.c.note, s.c.warn), (true, LayoutKey.heart, '', false));
    });
  });

  test('an empty box beside a full one: nothing is arranged, the board is the empty sheet, and there is nothing to save', () async {
    final shelf = Shelf(memoryDb());
    await seedFixtureBox(shelf);
    final solver = QuickSolver();
    final c = (await studio(on: shelf, solver: solver)).c;
    final empty = await shelf.makeBox();
    await Future<void>.delayed(const Duration(milliseconds: 50)); // the watch answers on the event loop
    final calls = solver.calls;
    c.openBox(empty);
    await pumpEventQueue();
    expect(c.box, empty);
    expect(c.grid, isNull, reason: 'the empty sheet — and with no grid, Save is off (header.dart:118 reads grid != null)');
    expect(c.solving, isFalse);
    expect(solver.calls, calls, reason: 'the solver was not asked');
    expect(c.starting, isFalse, reason: 'another box can fill: not starting');
    expect(c.feasible.values.every((f) => !f.fills), isTrue, reason: 'an empty box fills no template');
    expect((c.note, c.warn), ('', false), reason: 'decision 13: the bar\'s shortfall line is the only line');
    c.loadLayout(c.layout == LayoutKey.gradient ? LayoutKey.contrast : LayoutKey.gradient);
    await pumpEventQueue();
    expect((c.grid, c.note, c.warn, solver.calls), (null, '', false, calls), reason: 'a template tap on an empty box changes nothing');
  });

  test('a box emptied while it is on the board: the empty sheet, no note, and a remembered template does not come back', () async {
    final shelf = Shelf(memoryDb());
    await seedFixtureBox(shelf);
    final solver = QuickSolver();
    final c = (await studio(on: shelf, solver: solver)).c;
    final two = await shelf.makeBox();
    final ids = [
      for (var i = 0; i < 5; i++)
        (await shelf.addCloth(box: two, photo: fixtureJpeg, measured: measuredFor(l: 25.0 + 15 * i, a: 10.0 * i), fabric: '', pieces: 7)).id,
    ];
    await Future<void>.delayed(const Duration(milliseconds: 50)); // the watch answers on the event loop
    c.openBox(two);
    await pumpEventQueue();
    final first = c.layout, other = first == LayoutKey.gradient ? LayoutKey.contrast : LayoutKey.gradient;
    c.loadLayout(other);
    await pumpEventQueue();
    c.loadLayout(first);
    await pumpEventQueue();
    expect((c.box, c.solving), (two, false));
    expect(c.grid, isNotNull, reason: 'Box 2 arranged on two templates');
    for (final id in ids) {
      await shelf.removeCloth(id);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((c.box, c.piecesIn(two)), (two, 0));
    expect((c.grid, c.note, c.warn, c.solving), (null, '', false, false), reason: 'decision 13: emptied is the empty sheet, nothing to save');
    final calls = solver.calls;
    c.loadLayout(other);
    await pumpEventQueue();
    expect((c.grid, c.note, c.warn, solver.calls), (null, '', false, calls), reason: 'the arrangement remembered for Box 2 does not come back');
  });

  test('her box beside the Sample box comes to hold 35 pieces: it arranges, once', () async {
    final shelf = Shelf(memoryDb());
    final sample = await shelf.makeBox(sample: true);
    for (var i = 0; i < 5; i++) {
      await shelf.addCloth(box: sample, photo: fixtureJpeg, measured: measuredFor(l: 20.0 + 15 * i), fabric: '', pieces: 7);
    }
    final solver = QuickSolver();
    final c = (await studio(on: shelf, seeded: false, solver: solver)).c;
    final mine = await shelf.makeBox();
    expect(mine, 2);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c.openBox(mine);
    await pumpEventQueue();
    final before = solver.calls;
    for (var i = 0; i < 5; i++) {
      await shelf.addCloth(box: mine, photo: fixtureJpeg, measured: measuredFor(l: 25.0 + 15 * i, a: 10.0 * i), fabric: '', pieces: 7);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(c.piecesIn(mine), 35);
    expect(solver.calls, before + 1, reason: 'arranged once, when Box 1 came to fill — the Sample box already could');
    expect(c.grid, isNotNull);
    expect(c.note, '');
  });
}
