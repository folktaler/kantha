import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../backup/files.dart';
import '../data/backup.dart';
import '../data/numbers.dart' as numbers;
import '../data/sample_box.dart' as sample;
import '../data/shelf.dart';
import '../data/side_db.dart';
import '../l10n/app_localizations.dart';
import '../l10n/words.dart';
import '../platform/solver_runner.dart';
import '../solver/compile.dart';
import '../solver/fabrics.dart';
import '../solver/geometry.dart';
import '../solver/layouts.dart';
import '../solver/solve_layout.dart';
import '../solver/threads.dart';
import 'memory.dart';
import 'shelf_feed.dart';
import '../platform/report.dart';

enum ClothOpenKind { fix, add }

/* Which cloth the add or fix panel opens on: one of hers to fix, or a new piece for a box. */
class ClothOpen {
  const ClothOpen.fix(String this.clothId) : kind = ClothOpenKind.fix, box = null;
  const ClothOpen.add(int this.box) : kind = ClothOpenKind.add, clothId = null;
  /* A piece for a box not yet made: her first photo makes it (when no box of hers is on the board). */
  const ClothOpen.addToNew() : kind = ClothOpenKind.add, clothId = null, box = null;
  final ClothOpenKind kind;
  final String? clothId;
  final int? box;
}

class Feasible {
  const Feasible(this.why);
  final Unfillable? why;
  bool get fills => why == null;
}

const double zoomMin = 4, zoomMax = 34;
/* The least fitted scale on the panel: a 4 cm square at 24 px, the owner's floor for the squares she taps (31 Oct 2026;
   WCAG 2.2 AA's target size minimum). A frame or a tote, where nothing is tapped, fits to zoomMin. Zoom out may
   still go to zoomMin. */
const double fitLeast = 24 / patchCm;
List<int> noTurns([int? n]) => List<int>.filled(n ?? cells, 0);

/* The studio's state and behaviour, without a screen: the studio's screens only
   render this and call its methods. */
class StudioController extends ChangeNotifier {
  StudioController({required this.shelf, required this.solver, required this.words, int Function()? seeds, DateTime Function()? now,
      SideDb? side})
      : _seeds = seeds ?? (() => math.Random.secure().nextInt(0x100000000)),
        _now = now ?? DateTime.now,
        side = side ?? createSideDb(),
        name = words.canvasDefaultName(words.layoutTitle(LayoutKey.contrast)) {
    started = _now().toUtc().toIso8601String();
  }

  final Shelf shelf;
  /* Where a backup is written into or read from, beside the live database. */
  final SideDb side;
  final SolverRunner solver;
  /* The words for the app's language: KanthaApp gives them again when the device's language changes. */
  L words;
  final int Function() _seeds;
  final DateTime Function() _now;

  // What the shelf holds.
  List<ClothView> cloth = const [];
  List<int> ownBoxes = const [];
  /* A box she has just made in Your boxes and opened, with its number, until the feed lists it: hers from the moment it
     opens, so Add pieces and the empty squares add to it rather than making another, and named Box N at once (22 Oct 2026). */
  Map<int, int> _made = const {};
  List<DesignView> saved = const [];
  /* Every saved picture: of a saved design, or Picture only once the design has gone (owner, 20 Oct). */
  List<PictureView> pictures = const [];
  PictureView? pictureOf(String design) => pictures.where((p) => p.design == design).firstOrNull;
  /* Draws a design's picture (Save photo's photo) and its small copy: the app's TakeAway. Null in a test that does not
     draw, where no picture is made. */
  Future<({Uint8List png, Uint8List thumb})?> Function(DesignView)? drawPicture;
  /* The picture the last save is making, while it is made (a test waits for it). */
  Future<bool>? pictureMaking;
  /* Each box's stored number (decision 8); the sample box has none and is absent. */
  Map<int, int> boxNumbers = const {};
  /* The sample box, while there is one (spec 2026-10-07 sample box, decision 2). */
  int? sampleBox;
  bool isSample(int id) => id == sampleBox;
  var _pool = poolOf(const []);
  Map<String, int> _idIndex = const {};
  bool _pooled = false, _started = false;

  // The board.
  LayoutKey layout = LayoutKey.contrast;
  List<int>? grid;
  List<int> rot = noTurns();
  String name;
  int? box;
  Mount mount = Mount.none;
  /* The thread is the one that clears this design's cloth best (_recommendThread); the stitches are always Open, 5 rows
     of 5 a piece (owner, 20 Oct). */
  String thread = 'ecru';
  /* The one spacing, read by the board and by the Design tab's line alike, so the two cannot disagree. */
  Density get density => densities.firstWhere((d) => d.key == 'open');
  Thread get threadShown => threads.firstWhere((t) => t.key == thread, orElse: () => threads.first);
  double ppc = 13, fitPpc = 13;
  bool zoomed = false, stitch = false, warn = false, solving = true, busy = false;
  Memory memory = const {};
  /* What the studio last said. Every note said is counted in `notes`, so the same words said again are a new
     note (each is a toast as it comes); clearing it says nothing. */
  String _note = '';
  String get note => _note;
  set note(String v) {
    _note = v;
    if (v.isNotEmpty) notes++;
  }
  int notes = 0;
  /* drift's word on this browser (false: it keeps nothing). The app sets it once the shelf answers. */
  bool storageKept = true;
  int? seed;
  late final String started;
  String? firstSolve, savedId, savedGrid;
  Map<LayoutKey, Feasible> feasible = const {};
  int _reqId = 0;
  /* Counts the boards a tap on another pattern's tile put up; the board drops each one's squares in (owner, 21 Oct).
     `_dropFor` is the solve such a tap asked for: any later solve replaces it, and its board does not drop. */
  int drops = 0;
  int? _dropFor;

  /* The board is the size she chose with Rows and Columns, each boardMin to boardMax, from Level 1's 7 rows of 5 on A4
     (owner, 31 Oct 2026: one board, no levels). Remembered on the device (loadBoard). */
  BoardSize chosen = level1;
  BoardSize get size => chosen;
  /* The squares the board has, and so the pieces a box needs to fill it. */
  int get squares => size.rows * size.cols;
  SheetGrid get sheet => sheetFor(size);
  /* Level 1's A4 board: only it is offered the print sheet, the frame and the tote. */
  bool get onA4 => size == level1;
  static const levelKey = 'boardLevel', sizeKey = 'boardSize';
  /* From 30 to 31 Oct 2026 the board had two levels, kept under levelKey: 'beginner' was 5 × 7 whatever sizeKey held,
     'patchworker' the size in sizeKey. A device that still says 'beginner' opens on 5 × 7; one that says 'patchworker'
     on its size. Every write since says 'patchworker', so a build of those two days, still cached, opens her size too. */
  static const levelBeginner = 'beginner', levelChosen = 'patchworker';
  /* What a board that could not be arranged says: 35 pieces on Level 1, the board's own number on another size. */
  String get cantSolveWords => onA4 ? words.canvasCantSolve : words.canvasCantSolveSize('$squares');

  int piecesIn(int b) => cloth.fold(0, (n, c) => n + (c.box == b ? c.stock : 0));
  bool get mayEdit => box != null && ownBoxes.contains(box);
  /* Whether a box of hers holds the board's pieces (35 on Level 1). */
  bool get _canFill => ownBoxes.any((b) => piecesIn(b) >= squares);
  /* A saved design she opened while no box can fill a panel: it holds the board until she leaves it. */
  bool _holding = false;
  /* Spec 2026-10-07, decisions 2 and 4, narrowed by decision 11 of the 2026-10-07 sample-box spec: until a
     box of hers holds a panel's 35 pieces the studio is starting — the board is the empty sheet, and nothing
     is arranged — except while a saved design she opened is on the board, or while a Sample box is there. */
  bool get starting => !_canFill && !_holding && sampleBox == null;
  /* Whether a pattern pressed deals an arrangement: a box of hers or the Sample box can fill, and the box on the board
     holds cloth. Else a press only chooses the pattern, over the empty sheet (loadLayout). */
  bool get canDeal => (_canFill || sampleBox != null) && members(box).isNotEmpty;

  int? _opening([int? wanted]) =>
      numbers.openingBox(wanted: wanted, own: [for (final b in ownBoxes) (box: b, pieces: piecesIn(b))], need: squares);

  /* The template's own name, which a design has until she gives it one. */
  String _defaultName(LayoutKey l) => words.canvasDefaultName(words.layoutTitle(l));

  /* A note said as a warning. */
  void _warn(String n) { note = n; warn = true; notifyListeners(); }

  /* The board with nothing on it and nothing to save (decision 4): the empty sheet.
     What newDesign leaves behind goes too — the saved design and its name, the note. */
  void _clearBoard() {
    _reqId++; // a solve still out is dropped when it lands
    grid = null; rot = noTurns(squares); solving = false; savedId = null; savedGrid = null; note = ''; warn = false; _holding = false;
    name = _defaultName(layout);
  }
  int get percent => (ppc / fitPpc * 100).round();
  List<ThreadScore> get recommended => grid == null ? const [] : rankThreads(grid!, _pool.pool.lab);

  /* Restock: the pool is rebuilt, and the solver told, only
     when the cloth itself changed. When her box comes to hold 35 pieces the board arranges (a saved design
     she had open stays); when no box can fill any more, the board is cleared (decision 4). With no box on the board, or one that cannot fill while another now
     can, the studio turns to the box it would open on (decision 5). */
  void restock(ShelfState s) {
    final wasFull = _canFill;
    // Whether the box on the board could fill before this change: beside a box that already could (the Sample
    // box), `filled` never fires when hers comes to hold 35, so that box's own turn is read here.
    final b0 = box, boxWasFull = b0 != null && piecesIn(b0) >= squares, boxHeld = b0 != null && members(b0).isNotEmpty;
    final next = stableCloth(cloth, s.cloth);
    final listed = [for (final b in s.boxes) b.id];
    _made = {for (final e in _made.entries) if (!listed.contains(e.key)) e.key: e.value};
    ownBoxes = [...listed, ..._made.keys];
    sampleBox = s.boxes.where((b) => b.sample).firstOrNull?.id;
    saved = s.designs;
    pictures = s.pictures;
    // The watch has caught up with the last save (or the design has gone): its own answer is no longer needed.
    final just = _justSaved;
    if (just != null) {
      final now = saved.where((d) => d.id == just.id).firstOrNull;
      if (now == null || now.sameAs(just)) _justSaved = null;
    }
    boxNumbers = {...numbers.boxNumbers(s.boxes), ..._made};
    final changed = !identical(next, cloth) || !_pooled;
    if (changed) _repool(next);
    if (_started) {
      // No box can fill any more: the board clears, so cloth just removed is not painted on it — the Sample box
      // as much as hers. Only `starting` waits on there being no Sample box (decision 11).
      final filled = !wasFull && _canFill, dropped = wasFull && !_canFill;
      final b = box;
      final turn = b == null || !ownBoxes.contains(b) || (filled && piecesIn(b) < squares);
      if (turn) box = _opening();
      final came = b != null && b == b0 && !boxWasFull && piecesIn(b) >= squares;
      // The box on the board has just been emptied: the empty sheet, nothing to save (decision 13, "or emptied").
      final emptied = b != null && b == box && boxHeld && members(b).isEmpty;
      if (dropped || emptied) {
        _clearBoard();
        _checkFeasible(box);
      } else if (changed || turn || filled || came) {
        final fresh = turn || ((filled || came) && !_holding);
        if (filled) _holding = false; // her box can fill now: a saved design she had open simply stays
        _checkFeasible(box);
        if (solving || fresh) {
          solving = true;
          _requestSolve();
        }
        _recommendThread();
      }
    }
    notifyListeners();
  }

  void _repool(List<ClothView> next) {
    cloth = next;
    _pool = poolOf([for (final c in cloth) Fabric(id: c.id, name: c.name, lab: c.lab, busy: c.busy, edge: c.edge, grain: c.grain, stock: c.stock)]);
    _idIndex = {for (var i = 0; i < cloth.length; i++) cloth[i].id: i};
    _pooled = true;
    solver.setPool(Base(_pool.pool, _pool.edge, _pool.stock));
  }

  /* How many backups have replaced this device since the studio opened: what was made from the device as it was
     (Save photo's photo) is not taken for what is there now. */
  int imports = 0;

  /* A backup file has replaced everything on this device (Task 16). What this session remembered
     belonged to the device as it was: the arrangements, the design on the board, the save just
     made. Her cloth is read again whole — not kept in place as gone, as restock would — and the
     studio opens on the box it would open on (decision 5): a fresh arrangement, or the empty sheet. */
  Future<void> afterImport() async {
    imports++;
    _reqId++; // a solve still out was asked of the device as it was
    memory = const {}; savedId = null; savedGrid = null; _justSaved = null; note = ''; warn = false;
    notifyListeners();
    final now = await shelfNow(shelf);
    _reqId++;
    _made = const {};
    ownBoxes = [for (final b in now.boxes) b.id];
    sampleBox = now.boxes.where((b) => b.sample).firstOrNull?.id;
    saved = now.designs;
    pictures = now.pictures;
    boxNumbers = numbers.boxNumbers(now.boxes);
    _repool(now.cloth);
    box = _opening();
    name = _defaultName(layout);
    note = ''; warn = false;
    _checkFeasible(box);
    grid = null; solving = true;
    _requestSolve();
    _recommendThread();
    notifyListeners();
  }

  /* Opens a backup file and replaces this device with it, then afterImport. The Back up
     screen asks her first; this is that path without the question. False when she cancelled. */
  Future<bool> importFrom(Files files) async {
    final picked = await files.pickBackup();
    if (picked == null) return false;
    await importFile(picked.bytes);
    return true;
  }

  /* Throws BackupError, and then nothing on this device has changed. Once the import is in, it is in:
     a studio that then fails to re-open is reported, never passed off as the import failing. */
  Future<void> importFile(Uint8List bytes) async {
    await importBackup(bytes, shelf, side);
    try {
      await afterImport();
    } catch (e, s) {
      reportError(e, s, 'while the studio re-opened after an import');
    }
    // A backup made before 22 Oct brings no swap marker: its Sample box is swapped now, as on an open.
    try {
      await replaceDrawnSample();
    } catch (e, s) {
      reportError(e, s, 'while the Sample box was given its real cloth');
    }
  }

  /* The opening box, then the first solve.
     The shelf comes first: restock must have run, so the solver holds the pool before it is asked to solve. */
  void start({int? wantedBox}) {
    if (!_pooled) throw StateError('StudioController.start: call restock(ShelfState) first, so the solver has the pool');
    _started = true;
    box = _opening(wantedBox);
    _checkFeasible(box);
    _requestSolve();
    notifyListeners();
  }

  /* 197-200, narrowed by decision 13 of the 2026-10-07 sample-box spec: only the cloth in box `b` — none for an
     empty box, which is an empty board, never one arranged from other boxes' cloth. No cloth is in no box. */
  List<int> members(int? b) =>
      b == null ? const [] : [for (var i = 0; i < cloth.length; i++) if (cloth[i].box == b) i];

  /* A solver that fails (a missing or crashed worker) answers "no arrangement",
     so the board says it could not arrange rather than solving for ever. */
  void _requestSolve() {
    _holding = false; // a fresh arrangement is asked for: she has left any saved design she opened
    // Nothing is arranged while she is starting (the board is the empty sheet), nor on an empty box
    // (decision 13: the empty sheet, and nothing to save).
    if (starting || members(box).isEmpty) { _clearBoard(); notifyListeners(); return; }
    final id = ++_reqId, s = _seeds();
    final runner = solver, g = size;
    final asked = g == level1 ? runner.solve(layout, members(box), mount, s)
        : runner is SizedSolverRunner ? runner.solveOn(g, layout, members(box), mount, s)
        : Future.value(const LayoutSolve(false, null, null));
    asked
        .catchError((Object e, StackTrace st) {
          reportError(e, st, 'while the solver arranged the cloth');
          return const LayoutSolve(false, null, null);
        })
        .then((r) => _solved(id, r, s));
  }

  /* While she is starting the board is the empty sheet, so the templates are still measured but
     no "cannot fill" note is said, on any path. An empty box fills no template and is not measured — a
     template of lightness rules alone would answer that it fills, from no cloth — and nothing is said over
     the board (decision 13). */
  void _checkFeasible(int? b) {
    final mem = members(b);
    if (mem.isEmpty) {
      feasible = {for (final k in layoutKeys) k: const Feasible(Unfillable.fewPieces)};
      note = ''; warn = false;
      return;
    }
    feasible = {
      for (final k in layoutKeys)
        k: Feasible(modelFor(k, ObjectiveInput(pool: _pool.pool, edge: _pool.edge, members: mem, mount: mount, stock: _pool.stock,
            size: onA4 ? null : size)).why),
    };
    final now = feasible[layout];
    if (now != null && !now.fills && !starting) {
      if (!warn) note = words.canvasCantFill(words.notFillable(now.why!));
      warn = true;
    }
  }

  void _solved(int id, LayoutSolve r, int s) {
    if (id != _reqId) return;
    // No arrangement: the board is empty under the note, never the last box's cloth (decision 14).
    if (r.grid == null) { grid = null; rot = noTurns(squares); solving = false; note = cantSolveWords; warn = true; notifyListeners(); return; }
    grid = r.grid; rot = r.rot ?? noTurns(squares); seed = s; solving = false; warn = false; savedId = null; note = '';
    if (id == _dropFor) drops++;
    if (id == _pressFor) unawaited(_patternAgain(id));
    firstSolve ??= _now().toUtc().toIso8601String();
    memory = remember(memory, keyOf(box, layout, size), Arrangement(grid: grid!, rot: rot, seed: s, name: name, mount: mount));
    _recommendThread();
    notifyListeners();
  }

  /* The thread on show is the one that clears this cloth best: the first rankThreads gives (owner, 20 Oct). */
  void _recommendThread() {
    final best = recommended.firstOrNull;
    if (best != null) thread = best.thread.key;
  }

  /* The template she leaves is remembered as she last saw it: the mount she chose and the name she typed. */
  void loadLayout(LayoutKey next) {
    // With no box that can fill and no Sample box (decision 11), a template is only chosen: the board is the
    // empty sheet, and a saved design she held open is left for it. On an empty box the same: the
    // empty sheet stays, and no arrangement remembered from when it held cloth comes back (decision 13).
    if (!canDeal) {
      layout = next;
      name = _defaultName(next);
      _clearBoard();
      notifyListeners();
      return;
    }
    final fresh = _defaultName(next);
    final left = keyOf(box, layout, size);
    final was = recall(memory, left);
    final mem = was != null ? remember(memory, left, was.copyWith(name: name, mount: mount)) : memory;
    // While no box can fill (a Sample box trimmed under 35), an arrangement remembered from when it could holds cloth
    // since removed: the tap arranges what is there now.
    final kept = next == layout || !_canFill ? null : recall(mem, keyOf(box, next, size));
    final changed = next != layout;
    memory = mem;
    layout = next;
    if (kept != null) {
      _reqId++;
      drops++;
      final moved = kept.mount != mount;
      name = kept.name; mount = kept.mount; grid = kept.grid; rot = kept.rot; seed = kept.seed; solving = false;
      savedId = kept.savedId; savedGrid = kept.savedGrid; note = ''; warn = false;
      if (moved) fit();
      _recommendThread();
      notifyListeners();
      return;
    }
    name = fresh;
    solving = true;
    final f = feasible[next];
    if (f != null && !f.fills) {
      note = words.canvasCantFill(words.notFillable(f.why!)); warn = true;
    }
    notifyListeners();
    _requestSolve();
    _dropFor = changed ? _reqId : null;
    _pressFor = _reqId;
  }

  /* `made`: the number of a box the shelf has just made for her; it is hers, and named, before the feed lists it. */
  void openBox(int b, {int? made}) {
    if (made != null && !ownBoxes.contains(b)) {
      _made = {..._made, b: made};
      ownBoxes = [...ownBoxes, b];
      boxNumbers = {...boxNumbers, b: made};
    }
    if (b == box) return;
    box = b; solving = true;
    _checkFeasible(b);
    notifyListeners();
    _requestSolve();
  }

  void setMount(Mount m) { mount = onA4 ? m : Mount.none; fit(); }

  /* The board's size as she last left it on this device; one that cannot be read, or a Beginner's of the two levels,
     is 5 × 7. Read before start. */
  Future<void> loadBoard() async {
    try {
      final level = await shelf.setting(levelKey), saved = await shelf.setting(sizeKey);
      if (level == levelBeginner) return;
      final parts = saved?.split('x');
      final g = parts?.length == 2 ? (rows: int.tryParse(parts![0]) ?? 0, cols: int.tryParse(parts[1]) ?? 0) : null;
      if (g != null && boardSizeAllowed(g)) chosen = g;
    } on Object {
      // 5 × 7, as before Level 2.
    }
  }

  Future<void> _keepBoard() async {
    try {
      await shelf.setSetting(levelKey, levelChosen);
      await shelf.setSetting(sizeKey, '${chosen.rows}x${chosen.cols}');
    } on Object {
      // Not remembered: the next visit opens on the board it last remembered.
    }
  }

  /* Rows and Columns, their minus and plus: each kept to boardMin..boardMax. */
  void setBoardSize(BoardSize g) {
    final next = (rows: g.rows.clamp(boardMin, boardMax), cols: g.cols.clamp(boardMin, boardMax));
    if (next == chosen) return;
    _resize(() => chosen = next);
  }

  /* The board as a saved design's size, as she chose it for the design. */
  void _takeSize(BoardSize g) {
    chosen = g;
    if (!onA4) mount = Mount.none;
    unawaited(_keepBoard());
  }

  /* The board takes its new size: the arrangement she last saw on it, on this box and template, comes back (as a
     template's does in loadLayout); else a fresh one. Off A4 the mount is Plain. */
  void _resize(void Function() change) {
    final was = size;
    final left = keyOf(box, layout, was), kept0 = recall(memory, left);
    if (kept0 != null) memory = remember(memory, left, kept0.copyWith(name: name, mount: mount));
    change();
    unawaited(_keepBoard());
    if (size == was) { notifyListeners(); return; }
    if (!onA4) mount = Mount.none;
    _checkFeasible(box);
    final kept = _canFill && members(box).isNotEmpty ? recall(memory, keyOf(box, layout, size)) : null;
    if (kept != null) {
      _reqId++;
      name = kept.name; mount = kept.mount; grid = kept.grid; rot = kept.rot; seed = kept.seed; solving = false;
      savedId = kept.savedId; savedGrid = kept.savedGrid; note = ''; warn = false;
      _recommendThread();
      fit();
      return;
    }
    grid = null; rot = noTurns(squares); name = _defaultName(layout); savedId = null; savedGrid = null;
    solving = true; note = ''; warn = false;
    fit();
    if (!_started) return;
    _requestSolve();
  }
  void setName(String v) { name = v; notifyListeners(); }
  void setStitch(bool on) { stitch = on; notifyListeners(); }

  /* What was saved, to tell whether the board has changed since (a new name counts);
     and the name a save gives the design — hers, or the template's when she left it blank. */
  String stamp(List<int>? g, List<int> r, Mount m, String n) => jsonEncode({'grid': g, 'rot': r, 'mount': m.name, 'name': n});
  String nameToSave() => name.trim().isNotEmpty ? name.trim() : _defaultName(layout);

  DesignInput _input(String n, LayoutKey l, Mount m, int? b, int? s, String? st, String? fs, List<String> ids, List<int> r) =>
      DesignInput(name: n, layout: l.name, mount: m.name, box: b, seed: s, started: st, firstSolve: fs,
          grid: [for (var i = 0; i < ids.length; i++) GridCell(ids[i], r[i])], cols: size.cols);

  /* The setting that says a save has been made on this device, so the first save's note is said once. */
  static const savedOnceKey = 'savedOnce';

  /* The setting that says "Press {pattern} again for a new arrangement." has been shown on this device (owner, 31 Oct
     2026): after her first press of a pattern that deals an arrangement, once. */
  static const patternAgainKey = 'patternAgainSaid';
  /* The solve a pattern press asked for, so the note follows that press only. */
  int? _pressFor;

  /* After a press whose solve dealt an arrangement: the note, unless this device has had it, or another note has gone
     out since, or the board has moved on; then it waits for the next press that deals. */
  Future<void> _patternAgain(int id) async {
    final before = notes;
    try {
      if (await shelf.setting(patternAgainKey) != null) return;
      if (id != _reqId || notes != before || grid == null) return;
      note = words.canvasPatternAgain(words.layoutTitle(layout));
      notifyListeners();
      await shelf.setSetting(patternAgainKey, _now().toUtc().toIso8601String());
    } on Object {
      // Not read: not said. Said but not written: said again on a later press, which is the safe way to be wrong.
    }
  }

  /* A setting that cannot be read counts as seen: nothing is said twice by mistake. */
  Future<bool> _savedBefore() async {
    try {
      return await shelf.setting(savedOnceKey) != null;
    } on Object {
      return true;
    }
  }

  /* Saving again changes the design she saved; if she has deleted it, this is saved as a new one.
     The first save on this device says where it is kept, and is remembered; in a browser that keeps nothing,
     every first save says that instead, and nothing is remembered, since nothing there can be. */
  Future<String?> save() async {
    final g = grid;
    if (g == null) return null;
    busy = true;
    notifyListeners();
    final n = nameToSave(), l = layout, m = mount, b = box, s = seed, r = rot;
    try {
      final out = await shelf.saveDesign(_input(n, l, m, b, s, started, firstSolve, [for (final f in g) cloth[f].id], r),
          replacing: savedId);
      final first = await _savedBefore() == false;
      final st = stamp(g, r, m, n);
      busy = false;
      // Only if the board still holds what was saved: had she dealt or opened another design while
      // it saved, claiming that one as saved would let the next Save overwrite this design.
      if (identical(grid, g) && layout == l && box == b) {
        savedId = out.design.id; savedGrid = st;
        memory = remember(memory, keyOf(b, l, size), Arrangement(grid: g, rot: r, seed: s, name: out.design.name, mount: m,
            savedId: out.design.id, savedGrid: st));
      }
      note = !first ? words.canvasSaved : storageKept ? words.canvasSavedFirst : words.deviceNotKept;
      warn = false;
      _justSaved = DesignView.of(out.design);
      // Its picture, made each time it is saved, after the toast: the save itself does not wait for it.
      pictureMaking = _keepPicture(_justSaved!);
      notifyListeners();
      if (first && storageKept) {
        try {
          await shelf.setSetting(savedOnceKey, _now().toUtc().toIso8601String());
        } on Object {
          // Not remembered: the next save says it again, which is the safe way to be wrong.
        }
      }
      return out.design.id;
    } on ShelfError {
      busy = false;
      _warn(words.canvasSaveFailed(words.deviceStorageFailed));
      return null;
    }
  }

  /* Enter or leaving the field saves the name; Escape (null) leaves it. False when storage failed, which the
     board says. */
  Future<bool> rename(DesignView p, String? wanted) async {
    if (wanted == null) return true;
    final w = wanted.trim();
    if (w.isEmpty || w == p.name) return true;
    try {
      final panel = DesignView.of(await shelf.renameDesign(p.id, w));
      if (_justSaved?.id == panel.id) _justSaved = panel;
      // A rename is a save: its picture is made again, captioned with the new name.
      pictureMaking = _keepPicture(panel);
      if (savedId != panel.id) return true;
      // The design on the board: the rename was its save, unless the board had changed since.
      if (savedGrid != stamp(grid, rot, mount, p.name)) { name = panel.name; notifyListeners(); return true; }
      final sg = stamp(grid, rot, mount, panel.name);
      final key = keyOf(box, layout, size), kept = recall(memory, key);
      if (kept?.savedId == panel.id) memory = remember(memory, key, kept!.copyWith(name: panel.name, savedGrid: sg));
      name = panel.name; savedGrid = sg;
      notifyListeners();
      return true;
    } on ShelfError {
      _warn(words.canvasSaveFailed(words.deviceStorageFailed));
      return false;
    }
  }

  /* False when storage failed, which the board says. */
  Future<bool> duplicate(DesignView p) async {
    try {
      final copy = await shelf.duplicateDesign(p.id, words.canvasCopyName(p.name));
      // The copy's own picture, captioned with its own name, as a save makes one.
      pictureMaking = _keepPicture(DesignView.of(copy));
      return true;
    } on ShelfError {
      _warn(words.canvasSaveFailed(words.deviceStorageFailed));
      return false;
    }
  }

  /* A fresh arrangement on the template and box she is on, under the template's name, not yet saved. */
  void newDesign() {
    name = _defaultName(layout);
    savedId = null; savedGrid = null; solving = true; note = ''; warn = false;
    notifyListeners();
    _requestSolve();
  }

  /* Its own box, so the cloth beside it is its cloth, and saving it again keeps that box. */
  bool openSaved(DesignView p) {
    final g = [for (final id in p.grid) _idIndex[id]];
    if (g.any((i) => i == null)) { _warn(words.canvasMissingCloth); return false; }
    final gi = g.cast<int>();
    _reqId++;
    final b = p.box != null && ownBoxes.contains(p.box) ? p.box : box;
    // The board takes the design's size.
    final resized = p.size != size;
    if (resized) _takeSize(p.size);
    if (b != box || resized) _checkFeasible(b);
    final st = stamp(gi, p.rot, p.mount, p.name);
    grid = gi; rot = p.rot; layout = p.layout; name = p.name; mount = p.mount; box = b; solving = false;
    note = ''; warn = false; savedId = p.id; savedGrid = st;
    // Opened while no box can fill a panel, it takes the board while it is open (decision 4).
    _holding = !_canFill;
    memory = remember(memory, keyOf(b, p.layout, size),
        Arrangement(grid: gi, rot: p.rot, seed: p.seed, name: p.name, mount: p.mount, savedId: p.id, savedGrid: st));
    _recommendThread();
    // Another size is fitted afresh, as _resize does.
    if (resized) { fit(); } else { notifyListeners(); }
    return true;
  }

  /* False when storage failed, which the board says. */
  Future<bool> deleteSaved(String id) async {
    try {
      await shelf.deleteDesign(id);
      if (savedId == id) savedId = null;
      if (_justSaved?.id == id) _justSaved = null;
      memory = forget(memory, id);
      notifyListeners();
      return true;
    } on ShelfError {
      _warn(words.canvasDeleteFailed(words.deviceStorageFailed));
      return false;
    }
  }

  /* True while a delete makes its pictures and removes what she was asked about: Delete box and Remove this piece are
     busy, and a second press does nothing. */
  bool deleting = false;

  /* A design's picture, drawn and stored with it. True only once it was written: false when it could not be drawn or
     kept, or the design was saved again (renamed, too) or has gone meanwhile (Shelf.savePicture). A failure to draw or
     keep it is reported with the design's id. */
  Future<bool> _keepPicture(DesignView d) async {
    final draw = drawPicture;
    if (draw == null) return false;
    try {
      final made = await draw(d);
      return made != null && await shelf.savePicture(d.id, d.saved, name: d.name, png: made.png, thumb: made.thumb);
    } catch (e, s) {
      reportError(e, s, 'while the picture of design ${d.id} was made');
      return false;
    }
  }

  /* The saved designs that use any of this cloth. */
  List<DesignView> designsUsing(Set<String> cloth) =>
      [for (final d in saved) if (d.grid.any(cloth.contains)) d];

  /* A picture belongs to one save of a design. Before cloth goes (`drop`), the picture the last save is still making is
     waited for; then every saved design made from the cloth, as the shelf holds it now, is given a picture of its latest
     save where it has none (a rename is a save), so each stays as she last saw it. The shelf refuses the drop,
     'noPicture', when a design was saved meanwhile (here or in another tab): its picture is made, and the drop tried
     again, twice at most. One that cannot be made is tried once more; then it is reported with the design's id,
     ShelfError('noPicture') is thrown, and nothing goes. */
  Future<void> _picturesBefore(Set<String> cloth, Future<void> Function() drop) async {
    for (var tries = 0, refused = 0;; tries++) {
      await pictureMaking;
      final missing = await shelf.designsWithoutPicture(cloth);
      if (missing.isEmpty) {
        try {
          return await drop();
        } on ShelfError catch (e) {
          if (e.key != 'noPicture' || ++refused > 2) rethrow;
          tries = -1; // each design saved meanwhile is tried twice, as the first were
          continue;
        }
      }
      if (tries == 2) {
        reportError(StateError('no picture could be made of ${[for (final d in missing) d.id].join(', ')}'), null,
            'before the cloth they use was deleted');
        throw const ShelfError('noPicture');
      }
      for (final d in missing) {
        await _keepPicture(DesignView.of(d));
      }
    }
  }

  /* Remove this piece: its designs' pictures first, then the piece and those designs (Shelf.removeCloth). Throws
     ShelfError, and then nothing has gone; 'busy' while another delete runs. */
  Future<void> removeCloth(String id) async {
    if (deleting) throw const ShelfError('busy');
    deleting = true;
    notifyListeners();
    try {
      await _picturesBefore({id}, () => shelf.removeCloth(id));
    } finally {
      deleting = false;
      notifyListeners();
    }
  }

  /* A Sample box made before 22 Oct gets the real cloth, once (sample_box.dart replaceDrawnSample): the designs made
     from its drawn swatches get their pictures first, as Remove this piece's do, then go. Throws ShelfError, and then
     nothing has changed and the next open tries again. While another delete runs it waits for the next open. Once
     the swatches have gone, a board made of them is dealt again from the box (_dealAgainWithout). */
  Future<void> replaceDrawnSample() async {
    if (deleting) return;
    deleting = true;
    notifyListeners();
    var swatches = const <String>{};
    try {
      await sample.replaceDrawnSample(shelf, picturesFirst: (cloth, drop) {
        swatches = cloth;
        return _picturesBefore(cloth, drop);
      });
    } finally {
      deleting = false;
      notifyListeners();
    }
    if (swatches.isNotEmpty) await _dealAgainWithout(swatches);
  }

  /* After the swap, the board and the arrangements remembered for other patterns may be made of the swatches that
     went (`gone`), as when the swap waited for the studio to start. The cloth is read whole first, as the feed's
     restock reads it, so the pool holds the real cloth (the feed's own answer, before or after, then changes
     nothing). The arrangements that use a swatch are forgotten, and a board that uses one is dealt again from the
     box; a solve still out was asked again by restock, on the new pool. */
  Future<void> _dealAgainWithout(Set<String> gone) async {
    restock(await shelfNow(shelf));
    final at = {for (final id in gone) ?_idIndex[id]};
    bool uses(List<int> g) => g.any(at.contains);
    memory = {for (final e in memory.entries) if (!uses(e.value.grid)) e.key: e.value};
    final g = grid;
    if (_started && g != null && uses(g)) {
      grid = null;
      solving = true;
      _checkFeasible(box);
      _requestSolve();
    }
    notifyListeners();
  }

  /* She deletes a picture, as a file: false when storage failed, which the board says. */
  Future<bool> deletePicture(int id) async {
    try {
      await shelf.deletePicture(id);
      return true;
    } on ShelfError {
      _warn(words.canvasDeleteFailed(words.deviceStorageFailed));
      return false;
    }
  }

  /* A box goes with its pieces and their photos (owner, 20 Oct), the designs made from them staying as pictures.
     `cloth` is the cloth she was asked about. The feed's next answer runs restock, whose turn moves the studio off the
     gone box to the box it would open on at launch, else the empty sheet. True once it has gone: a box already gone
     (another tab deleted it) is what she asked for, and nothing is said. Null when the box now holds other cloth: nothing
     has gone, and she is asked again. False when it could not go, which the board says: the storage words, or, when a
     picture could not be made first, "That did not work. Try again in a moment." (cloth.errors.pieceFailed). False,
     and nothing done, while another delete runs. */
  Future<bool?> deleteBox(int id, Set<String> cloth) async {
    if (deleting) return false;
    deleting = true;
    notifyListeners();
    try {
      await _picturesBefore(cloth, () => shelf.deleteBox(id, cloth: cloth));
      _made = {..._made}..remove(id);
      return true;
    } on ShelfError catch (e) {
      if (e.key == 'noSuchBox') {
        // A box just made that another tab deleted before the feed listed it: no feed answer will drop it, so it is read here.
        if (_made.containsKey(id)) {
          _made = {..._made}..remove(id);
          restock(await shelfNow(shelf));
        }
        return true;
      }
      if (e.key == 'boxNotEmpty') return null;
      note = e.key == 'noPicture' ? words.clothErrorsPieceFailed : words.canvasDeleteFailed(words.deviceStorageFailed);
      warn = true;
      return false;
    } finally {
      deleting = false;
      notifyListeners();
    }
  }

  /* Share or DIY on the board: saved as it is first, then its menu. */
  Future<String?> takeAwayNow() async =>
      savedId != null && savedGrid == stamp(grid, rot, mount, nameToSave()) ? savedId : await save();

  /* A saved design as it is now. The shelf's watch answers a turn after a save, so for that turn
     the save's own answer stands in for it — Share and DIY open on the design just saved. */
  DesignView? _justSaved;
  DesignView? designFor(String id) {
    final just = _justSaved;
    if (just != null && just.id == id) return just;
    return saved.where((s) => s.id == id).firstOrNull;
  }

  /* Whether a saved design uses cloth that has left every box she reads. */
  bool usesGoneCloth(String? id) {
    final p = id == null ? null : designFor(id);
    return p != null && p.grid.any((c) { final i = _idIndex[c]; return i == null || cloth[i].box == null; });
  }

  /* The scale that fits the board's room: the canvas less its padding, and on A4 less the 4 cm line over the sheet
     (phone_studio.dart _canvas). */
  Size _pane = Size.zero;
  /* Tells the screen only when the scale changed, so a LayoutBuilder may call it on every build. */
  void applyFit(Size room) {
    if (_fitTo(room)) notifyListeners();
  }

  bool _fitTo(Size pane) {
    _pane = pane;
    final w = pane.width, h = pane.height;
    // Less room than one 24 px square is a pane on its way somewhere (a route turning, the keyboard): the scale stays.
    // Any more is fitted, and a board that needs more room scrolls.
    if (w < fitLeast * patchCm || h < fitLeast * patchCm) return false;
    final vw = mount == Mount.frame ? frame.outer.$1 + 1 : mount == Mount.tote ? tote.w + 2 : sheet.w;
    final vh = mount == Mount.frame ? frame.outer.$2 + 1 : mount == Mount.tote ? tote.h + 2 : sheet.h;
    // On the panel, whose empty squares she taps, never less than fitLeast, so a square is at least 24 px (owner,
    // 31 Oct 2026). In a frame or on a tote, where nothing is tapped, as small as zoomMin (a phone's canvas is narrower
    // than a frame or a tote at 9 px a cm). A board that would need less scrolls.
    final least = mount == Mount.none ? fitLeast : zoomMin;
    final next = math.min(w / vw, h / vh).floorToDouble().clamp(least, zoomMax);
    final changed = next != fitPpc || (!zoomed && ppc != next);
    fitPpc = next;
    if (!zoomed) ppc = next;
    return changed;
  }

  /* 60–160 % of the fitted scale in steps of 20; 100 is Fit. Clamped to zoomMin..zoomMax. */
  void zoomTo(int percent) {
    if (percent == 100) { fit(); return; }
    zoomed = true;
    ppc = math.min(zoomMax, math.max(zoomMin, fitPpc * percent / 100));
    notifyListeners();
  }

  /* Always tells the screen: Fit, or a new mount (setMount), changed the board even when the pane
     is too small to fit and the scale stays. */
  void fit() {
    zoomed = false;
    if (_pane == Size.zero) { ppc = fitPpc; } else { _fitTo(_pane); }
    notifyListeners();
  }

  @override
  void dispose() {
    _reqId++; // a solve still out is dropped when it lands
    solver.dispose();
    super.dispose();
  }
}
