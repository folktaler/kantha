/* Add a piece, the Add a piece sheet's body (redesign handover, decision 3): a photo of the piece,
   cropped square, and how many; Add measures it on the device and puts it in the box. The fabric is not asked:
   one line says what works best (spec 2026-10-07 sample box, decision 9). The sheet stays open for the next one;
   after an add a banner says what went in, until the sheet closes. Every close (Done, the ×, the scrim, back, Escape)
   with a photo waiting adds it as Add does, then closes; if the add fails the sheet stays open with the error and the
   photo (owner, 22 October 2026).
   Where there is a finder (the web, piece_finder.dart), the photo may hold many pieces (plan Part 1, owner's mockup of
   30 October 2026): once read, the finder looks. 2 or more pieces: "Are these your pieces?", then "Your cloths", then
   one cloth per cloth found goes in through the same add, its count as she left it, and the sheet closes. 0 or 1: the
   crop, as before, its square on the piece found. Pieces there but too small to find: she is asked for a closer
   photo. Every close adds what is waiting: the pieces as matched, or the cloths as counted. A phone has no finder, and
   the sheet is as it was. */
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../data/numbers.dart' show startCount;
import '../data/shelf.dart';
import '../l10n/app_localizations.dart';
import '../measure/measure.dart';
import '../studio/phone/phone_sheet.dart' show PhoneButton, PhoneButtonKind;
import '../studio/phone/phone_theme.dart';
import '../studio/pressable.dart';
import 'crop_step.dart';
import 'many_pieces.dart';
import 'parts.dart';
import 'piece_finder.dart';
import 'photo_source.dart';
import 'prepare.dart';

class AddCloth extends StatefulWidget {
  const AddCloth({super.key, required this.box, required this.shelf, required this.photos, required this.words,
      required this.onClose, this.cropHeld, this.read = readPhoto, this.title, this.onManyAdded, this.boxName});
  /* The box the pieces go into; null when she has none yet: her first photo makes it (spec 2026-10-07, decision 2). */
  final int? box;
  final Shelf shelf;
  final PhotoSource photos;
  final L words;
  final VoidCallback onClose;
  /* True while a finger is on the crop, so the sheet holds still. */
  final ValueNotifier<bool>? cropHeld;
  /* Reads a picked photo (readPhoto); a test passes one that fails. */
  final Future<PickedPhoto> Function(Uint8List) read;
  /* The sheet's title, which follows the step where there is a finder. */
  final ValueNotifier<String>? title;
  /* Many pieces went in and the sheet closed: how many cloths, how many pieces, and the box. */
  final void Function(int cloths, int pieces, int box)? onManyAdded;
  /* A box's name as she sees it ("Box 2", "Sample box"), for what went in. */
  final String Function(int box)? boxName;

  @override
  State<AddCloth> createState() => _AddClothState();
}

class _AddClothState extends State<AddCloth> {
  L get words => widget.words;
  final _crop = CropController();
  /* What went in last, shown above the next photo. */
  String? _added;
  Uint8List? _picture;
  /* The picture, once it has been read whole: only then is the cropper given it. */
  PickedPhoto? _photo;
  /* _reading: the picture is being read (on a slow phone's browser that can hold the page still, so it is shown). */
  bool _ready = false, _reading = false, _busy = false, _howTo = false;
  String _error = '';
  int _count = startCount;
  late int? _box = widget.box;
  /* Her first box while it is being made: a second photo in that moment waits for the same box. */
  Future<int>? _making;
  /* Done or a close was asked for with a photo waiting: the sheet closes once that photo is in the box. */
  bool _closeAfter = false;

  /* The finder, where this platform has one; null on a phone, and the sheet is as it was. */
  final PieceFinder? _finder = pieceFinder();
  bool get _many => _finder != null;
  _Step _step = _Step.pick;
  /* The pieces found, as she has left them, and what they were before each change, for Undo. */
  List<Piece> _pieces = [];
  final _undo = <List<Piece>>[];
  /* Counted up at each change of the pieces: the cloths made from them are made again when it moves. */
  int _version = 0, _clothsVersion = -1;
  List<FoundCloth> _cloths = [];
  /* Counts she set, by cloth, kept while the pieces of that cloth stay as many. */
  final _counts = <Object, (int found, int count)>{};
  /* The one piece found, where the crop starts. */
  Rect? _cropStart;
  /* Pieces she added, each its own cloth. */
  int _tapped = 0;

  /* The picture let go of (replaced, reset, saved, or the card closed): on the web its decoded bitmap is closed now,
     not left for the garbage collector. Called inside setState, or from dispose. */
  void _letGo() {
    _photo?.close();
    _photo = null;
    _forgetPieces();
  }

  /* The pieces and cloths of the photo let go, and the finder's copy of it. */
  void _forgetPieces() {
    _finder?.forget();
    for (final c in _cloths) {
      c.image.dispose();
    }
    _cloths = [];
    _pieces = [];
    _undo.clear();
    _counts.clear();
    _cropStart = null;
    _version++;
    _step = _Step.pick;
  }

  @override
  void initState() {
    super.initState();
    // After the first frame: the sheet's header is built in the same frame as this card.
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _title(); });
  }

  /* The sheet's title for the step. */
  void _title() {
    final t = widget.title;
    if (t == null || !_many) return;
    t.value = switch (_step) {
      _Step.check => words.clothManyCheckTitle,
      _Step.cloths => words.clothManyClothsTitle,
      _ => words.clothManyTitle,
    };
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _title();
  }

  @override
  void dispose() {
    _letGo();
    super.dispose();
  }

  String? get _fileName => switch (widget.photos) { final NamedPhotoSource n => n.lastName, _ => null };

  /* The camera on a phone; on the web, the browser's own file box, which offers the camera too. */
  Future<void> _pick({required bool camera}) async {
    setState(() => _error = '');
    final Uint8List? bytes;
    try {
      bytes = await widget.photos.pick(camera: camera);
    } catch (e, s) {
      reportClothError(e, s, 'while a photo was taken or chosen');
      if (mounted) setState(() => _error = words.clothErrorsPieceFailed);
      return;
    }
    if (bytes == null || !mounted) return;
    try {
      checkPicked(bytes);
    } on Exception catch (e) {
      // Whatever the package says of a file it cannot read, she hears that this one could not be read.
      final named = e is MeasureError ? e : const MeasureError('notAnImage');
      return setState(() => _error = clothError(words, named, fileName: _fileName));
    }
    // Her first photo makes her box, when she has none yet.
    if (_box == null) {
      try {
        _box = await (_making ??= widget.shelf.makeBox());
      } catch (e, s) {
        _making = null;
        reportClothError(e, s, 'while her first box was made');
        if (mounted) setState(() => _error = clothError(words, e, fileName: _fileName));
        return;
      }
      if (!mounted) return;
    }
    // "Measuring…" is drawn before the picture is read: that work can hold the page still.
    // The stage is shown empty until the whole picture has been read; only then is the cropper given it.
    setState(() { _picture = bytes; _letGo(); _reading = true; _ready = false; });
    await paintedFirst();
    final PickedPhoto photo;
    try {
      photo = await widget.read(bytes);
    } catch (e, s) {
      // The cropper would never say it is ready: she hears now that this file could not be read. Anything else that
      // stopped the read (the reading isolate gone, out of memory) is reported, and she hears the same.
      if (e is! MeasureError) reportClothError(e, s, 'while a picked photo was read');
      if (mounted && identical(_picture, bytes)) {
        final named = e is MeasureError ? e : const MeasureError('notAnImage');
        setState(() { _picture = null; _reading = false; _error = clothError(words, named, fileName: _fileName); });
      }
      return;
    }
    if (mounted && identical(_picture, bytes)) {
      setState(() => _photo = photo);
      if (_many) unawaited(_find(photo));
    } else {
      photo.close(); // another picture was picked, or the card closed, while this one was read
    }
  }

  void _reset() => setState(() { _picture = null; _letGo(); _ready = false; _reading = false; _error = ''; });

  /* The finder looks at the photo; what it finds says which step comes next. One it cannot run (its worker did not
     load) is the crop, as before. */
  Future<void> _find(PickedPhoto photo) async {
    setState(() => _step = _Step.finding);
    FinderAnswer? found;
    try {
      found = await _finder!.find(photo).timeout(finderWait);
    } catch (e, s) {
      reportClothError(e, s, 'while the pieces in a photo were found');
    }
    if (!mounted || !identical(_photo, photo)) return;
    final route = found == null ? FoundRoute.crop : routeOf(found, Size(photo.width.toDouble(), photo.height.toDouble()));
    setState(() {
      // Done pressed while the photo was read said to wait: the finder has looked now.
      if (_error == words.clothErrorsNotReady) _error = '';
      switch (route) {
        case FoundRoute.crop:
          _step = _Step.crop;
          final q = found == null || found.squares.length != 1 ? null : found.squares.single;
          _cropStart = q == null ? null : _boundsOf(q);
        case FoundRoute.tooSmall:
          _step = _Step.tooSmall;
          _reading = false;
        case FoundRoute.check:
          _step = _Step.check;
          _reading = false;
          _pieces = [for (final (i, q) in found!.squares.indexed) Piece(q, found.groups[i])];
          _version++;
      }
    });
    if (!_closeAfter) return;
    // A close asked for while the finder looked: what it found is added now (the crop's, once the cropper is ready).
    if (route == FoundRoute.tooSmall) return widget.onClose();
    if (route == FoundRoute.check) unawaited(_addMany());
  }

  /* Done, and every other close: with no photo waiting the sheet closes; with one, it is added first, by the same
     path as Add. With many pieces, those waiting go in. The ×, back, Escape and the scrim (`dismiss`) while the photo
     is read or looked at close the sheet at once with nothing added: nothing has been found to add yet, and a finder
     that is slow or stuck must not hold the sheet open. */
  void _done({bool dismiss = false}) {
    if (_picture == null || _step == _Step.tooSmall) return widget.onClose();
    if (dismiss && _many && (_step == _Step.pick || _step == _Step.finding)) return widget.onClose();
    _closeAfter = true;
    if (_busy) return;
    switch (_step) {
      case _Step.finding:
        return; // added once the finder has looked
      case _Step.check || _Step.cloths:
        unawaited(_addMany());
      case _Step.pick || _Step.crop || _Step.tooSmall:
        _submit();
    }
  }

  /* It's one piece: the photo goes to the crop, as a photo of one piece does, framed from the cropper's own start. */
  void _onePiece() => setState(() {
        _step = _Step.crop;
        _cropStart = null;
        _error = '';
        _reading = true; // until the cropper is ready
        _ready = false;
      });

  /* A change to the pieces, kept for Undo. */
  void _edit(VoidCallback change) => setState(() {
        _undo.add([for (final p in _pieces) p.copy()]);
        change();
        _version++;
      });

  void _undoOne() {
    if (_undo.isEmpty) return;
    setState(() {
      _pieces = _undo.removeLast();
      _version++;
    });
  }

  /* A tap where no box is: the piece there, snapped to its edges if the finder sees them, else the default square. */
  Future<void> _addAt(Offset at) async {
    Float32List? q;
    try {
      q = await _finder!.snap(at);
    } catch (e, s) {
      reportClothError(e, s, 'while a tap was snapped to a piece');
    }
    // Next pressed while the finder looked (_busy), or the step left: the piece she has not seen is not added.
    if (!mounted || _step != _Step.check || _busy) return;
    final photo = _photo!;
    final square = q ?? defaultSquare(at, _pieces, Size(photo.width.toDouble(), photo.height.toDouble()));
    _edit(() => _pieces.add(Piece(square, 'added ${_tapped++}')));
  }

  /* The cloths of the pieces left: one per cloth found, the most pieces first, each cut from the photo for its swatch
     and its measure. Made again only when the pieces changed. */
  Future<void> _matchCloths() async {
    if (_clothsVersion == _version) return;
    final version = _version;
    final by = <Object, List<Piece>>{};
    for (final p in _pieces) {
      if (p.removed) continue;
      (by[p.cloth] ??= []).add(p);
    }
    final groups = by.entries.toList()..sort((a, b) => b.value.length - a.value.length);
    final cuts = await _finder!.cut([for (final g in groups) g.value.first.q]);
    final made = <FoundCloth>[];
    for (final (i, g) in groups.indexed) {
      final side = _sideOf(cuts[i]);
      final image = await _imageOf(cuts[i], side);
      // A stack counts 1, as every piece does (owner, 30 October 2026); a count she set stays while the cloth does.
      final n = g.value.length, kept = _counts[g.key];
      made.add(FoundCloth(g.key, n, kept != null && kept.$1 == n ? kept.$2 : n, cuts[i], image));
    }
    for (final c in _cloths) {
      c.image.dispose();
    }
    _cloths = made;
    _clothsVersion = version;
  }

  static int _sideOf(Uint8List rgba) => math.sqrt(rgba.length / 4).round();

  static Future<ui.Image> _imageOf(Uint8List rgba, int side) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, side, side, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  /* Next: her cloths. */
  Future<void> _next() async {
    if (_busy) return;
    setState(() { _busy = true; _error = ''; });
    try {
      await _matchCloths();
      if (mounted) setState(() => _step = _Step.cloths);
    } catch (e, s) {
      reportClothError(e, s, 'while the pieces were cut for her cloths');
      if (mounted) setState(() => _error = words.clothErrorsPieceFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* Every cloth waiting into the box in one write, each prepared as one piece is. Then the sheet is ready for the next
     photo, saying what went in, or, after a close, closes. One that fails keeps the sheet open with the error, and
     nothing in: all still waiting. */
  Future<void> _addMany() async {
    if (_busy) return;
    setState(() { _busy = true; _error = ''; });
    try {
      await _matchCloths();
      final waiting = [..._cloths];
      // All at once: a browser busy drawing saves each JPEG only once it has waited about a second for a quiet moment
      // (measured 31 October 2026 at 6 times slower), so one after another that second is waited for each cloth.
      final prepared = await Future.wait([for (final c in waiting) preparePiece(c.rgba)]);
      final ready = [
        for (final (i, out) in prepared.indexed) (photo: out.jpeg, measured: out.measured, pieces: waiting[i].count),
      ];
      // Every box removed: nothing goes in, and nothing is said.
      if (ready.isEmpty) {
        if (_closeAfter) widget.onClose();
        return;
      }
      await widget.shelf.addCloths(box: _box!, cloth: ready);
      if (!mounted) return;
      final cloths = ready.length, pieces = ready.fold(0, (n, c) => n + c.pieces), box = _box!;
      setState(() {
        _added = words.clothManyAddedNext(cloths, pieces, widget.boxName?.call(box) ?? '');
        _picture = null;
        _letGo();
        _ready = false;
      });
      if (_closeAfter) {
        widget.onManyAdded?.call(cloths, pieces, box);
        widget.onClose();
      }
    } catch (e, s) {
      reportClothError(e, s, 'while many pieces were added');
      if (mounted) setState(() { _closeAfter = false; _error = clothError(words, e, fileName: _fileName); });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_picture == null) return setState(() { _closeAfter = false; _error = words.clothErrorsNoPhoto; });
    if (!_ready) return setState(() { _closeAfter = false; _error = words.clothErrorsNotReady; });
    setState(() { _busy = true; _error = ''; });
    // Drawn as busy first: the crop and the measure can hold the page still.
    await paintedFirst();
    if (mounted) _crop.crop();
  }

  void _cropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        _store(croppedImage);
      case CropFailure(:final cause, :final stackTrace):
        reportClothError(cause, stackTrace, 'while the photo was cropped');
        if (mounted) setState(() { _busy = false; _closeAfter = false; _error = words.clothErrorsNotReady; });
    }
  }

  Future<void> _store(Uint8List square) async {
    try {
      final out = await preparePhoto(square);
      final row = await widget.shelf.addCloth(box: _box!, photo: out.jpeg, measured: out.measured, fabric: '', pieces: _count);
      if (!mounted) return;
      setState(() {
        _added = words.clothAddedNext(row.pieces, row.name);
        _count = startCount;
        _picture = null;
        _letGo();
        _ready = false;
      });
      if (_closeAfter) widget.onClose();
    } catch (e, s) {
      reportClothError(e, s, 'while a piece was added');
      if (mounted) setState(() { _closeAfter = false; _error = clothError(words, e, fileName: _fileName); });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* The crop, once a photo is picked; the photo field before. */
  List<Widget> _photoOrCrop() => [
        if (_picture == null) ..._photoField() else _held(CropStep(
          key: ObjectKey(_picture), photo: _photo, controller: _crop, coverage: 0.7, hint: words.clothCropHint, start: _cropStart,
          onCropped: _cropped, onReady: () {
            if (!mounted) return;
            setState(() {
              _ready = true;
              _reading = false;
              // A close or an add pressed while the photo was read said to wait: it is ready now.
              if (_error == words.clothErrorsNotReady) _error = '';
            });
            // A close asked for while the finder looked: the piece goes in as framed.
            if (_many && _closeAfter && !_busy) _submit();
          },
        )),
        // Choose a different picture is a 48 px button of its own, under the crop.
        if (_picture != null) _quietButton(words.clothRetake, _busy ? null : _reset),
      ];

  Widget _held(Widget crop) {
    final held = widget.cropHeld;
    return held == null ? crop : CropHold(held: held, child: crop);
  }

  /* A quiet button: a 48 px text button, as tall as a finger needs. */
  Widget _quietButton(String text, VoidCallback? onPressed) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: PhoneButton(text: text, kind: PhoneButtonKind.text, onPressed: onPressed),
      );

  String get _submitText => _busy || _reading ? words.clothBusy : _count == 1 ? words.clothAddOne : words.clothAddMany('$_count');

  /* What was added last, the photo, How to, the count beside its question, then Done and Add. */
  @override
  Widget build(BuildContext context) {
    final last = _added;
    // The ×, the scrim, back and Escape ask the sheet to close; with a photo waiting they go through Done.
    return PopScope<Object?>(canPop: _picture == null, onPopInvokedWithResult: (didPop, _) { if (!didPop) _done(dismiss: true); },
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: 16,
            children: _many ? _manySteps(last) : [
      if (last != null) _addedNote(last),
      ..._photoOrCrop(),
      _howToBlock(),
      _countRow(),
      if (_error.isNotEmpty) cardError(_error),
      _buttons(PhoneButton(text: _submitText, busy: _busy || _reading, onPressed: _submit)),
    ]));
  }

  /* How many of this piece, and its counter. */
  Widget _countRow() => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(words.clothHowMany, style: pText(PType.cardLabel)),
          const SizedBox(height: 2),
          Text(words.clothRecommend, style: pText(PType.finePrint, color: PhonePalette.text2)),
        ])),
        const SizedBox(width: 12),
        PieceCounter(count: _count, shown: words.clothPiece(_count), fewer: words.clothFewer, more: words.clothMore,
            enabled: !_busy, onChanged: (n) => setState(() => _count = n)),
      ]);

  /* Done, and the step's own button beside it. */
  Widget _buttons(Widget main) => Row(children: [
        Expanded(child: PhoneButton(text: words.canvasHideControls, kind: PhoneButtonKind.dark, onPressed: _done)),
        const SizedBox(width: 8),
        Expanded(child: main),
      ]);

  /* Where there is a finder: the step she is on. */
  List<Widget> _manySteps(String? last) {
    final error = [if (_error.isNotEmpty) cardError(_error)];
    final find = PhoneButton(text: words.clothManyFind, onPressed: null);
    final retake = _quietButton(words.clothRetake, _busy ? null : _reset);
    // The finder was wrong about this photo (a check or a gingham is one cloth): the crop, as for one piece.
    final onePiece = _quietButton(words.clothManyOnePiece, _busy ? null : _onePiece);
    switch (_step) {
      case _Step.pick when _picture == null:
        return [if (last != null) _addedNote(last), ..._photoField(), _howToBlock(), ...error, _buttons(find)];
      case _Step.pick || _Step.finding:
        // Read, then looked at: the photo, and what is happening.
        return [_photoStage(finding: true), ...error,
          _buttons(PhoneButton(text: words.clothManyFindingShort, busy: true, onPressed: null))];
      case _Step.tooSmall:
        return [_photoStage(), cardError(words.clothManyTooSmall), onePiece, retake, _buttons(find)];
      case _Step.crop:
        return [if (last != null) _addedNote(last), ..._photoOrCrop(), _howToBlock(), _countRow(), ...error,
          _buttons(PhoneButton(text: _submitText, busy: _busy || _reading, onPressed: _submit))];
      case _Step.check:
        final any = _pieces.any((p) => !p.removed);
        return [
          CheckPieces(photo: _photo!, pieces: _pieces, words: words, edit: _edit, onUndo: _undoOne, canUndo: _undo.isNotEmpty,
              add: (at) => unawaited(_addAt(at)), held: widget.cropHeld, enabled: !_busy),
          onePiece, retake, ...error,
          _buttons(PhoneButton(text: words.clothManyNext, busy: _busy, onPressed: any ? _next : null)),
        ];
      case _Step.cloths:
        final pieces = _cloths.fold(0, (n, c) => n + c.count);
        return [
          YourCloths(cloths: _cloths, words: words, enabled: !_busy,
              onCount: (c, n) => setState(() { c.count = n; _counts[c.key] = (c.found, n); })),
          _quietButton(words.clothManyBack, _busy ? null : () => setState(() { _step = _Step.check; _error = ''; })),
          ...error,
          _buttons(PhoneButton(text: _busy ? words.clothBusy : words.clothManyAdd(pieces), busy: _busy, onPressed: _cloths.isEmpty ? null : _addMany)),
        ];
    }
  }

  /* The photo in the crop's 300 px stage; while the finder looks, a note over it. */
  Widget _photoStage({bool finding = false}) {
    final shown = _photo?.bytes ?? _picture;
    return Container(
      key: const ValueKey('photo-stage'),
      height: 300,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: PhonePalette.canvas, border: Border.all(color: PhonePalette.border)),
      child: Stack(fit: StackFit.expand, children: [
        if (shown != null) Image.memory(shown, fit: BoxFit.contain, gaplessPlayback: true),
        if (finding)
          ColoredBox(color: const Color(0x8CFCFBF8), child: Center(child: Semantics(liveRegion: true, child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: PhonePalette.white, border: Border.all(color: PhonePalette.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PhonePalette.blue)),
              const SizedBox(width: 10),
              Flexible(child: Text(words.clothManyFinding, style: pText(PType.cardLabel))),
            ]),
          )))),
      ]),
    );
  }

  /* At least 48 tall on the note ground, a 3 px ink edge at the left, a 16 px check in ink, and what went in, in the
     body-small role. */
  Widget _addedNote(String added) => Semantics(
        key: const ValueKey('cloth-added'),
        liveRegion: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(13, 8, 16, 8),
          decoration: const BoxDecoration(color: PhonePalette.note,
              border: Border(left: BorderSide(width: 3, color: PhonePalette.text))),
          child: Row(children: [
            tablerIcon(const tabler.Check(), size: 16),
            const SizedBox(width: 12),
            Expanded(child: Text(added, style: pText(PType.bodySmall))),
          ]),
        ),
      );

  /* The photo field (the <label> round the file input): a tap anywhere on it takes a photo.
     On a phone app the gallery is its own door under it; on the web the browser's file box offers both. */
  List<Widget> _photoField() => [
        Pressable(
          onPressed: _busy || _reading ? null : () => _pick(camera: !kIsWeb),
          builder: (context, st) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(_many ? words.clothManyPhoto : words.clothPhoto, style: pText(PType.cardLabel)),
            const SizedBox(height: 5),
            focusRing(st.focused, Container(
              key: const ValueKey('photo-field'),
              height: 140,
              decoration: BoxDecoration(color: st.hovered ? PhonePalette.hover : PhonePalette.canvas,
                  border: Border.all(color: PhonePalette.border)),
              child: Center(child: tablerIcon(const tabler.Camera(), size: 24, color: PhonePalette.text2)),
            )),
            const SizedBox(height: 5),
            cardHint(_many ? words.clothManyPhotoHint : words.clothPhotoHint),
          ]),
        ),
        if (!kIsWeb) _quietButton(words.clothChoosePicture, _busy || _reading ? null : () => _pick(camera: false)),
      ];

  /* A line of How to: the body-small role in text2. */
  TextStyle get _howToLine => pText(PType.bodySmall, color: PhonePalette.text2);

  /* <details>: How to get it right, and its three lines when open. */
  Widget _howToBlock() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Pressable(
            expanded: _howTo, onPressed: () => setState(() => _howTo = !_howTo),
            builder: (context, st) {
              final row = Row(mainAxisSize: MainAxisSize.min, children: [
                ExcludeSemantics(child: Icon(_howTo ? Icons.arrow_drop_down : Icons.arrow_right, size: 16,
                    color: PhonePalette.text)),
                Text(words.clothHowTo, style: pText(PType.cardLabel)),
              ]);
              // The toggle is a finger's 48 px tall.
              return focusRing(st.focused,
                  ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: row));
            },
          ),
        ),
        if (_howTo)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
              for (final (i, line) in [words.clothHowTo1, words.clothHowTo2, _many ? words.clothManyHowTo3 : words.clothHowTo3].indexed)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 20, child: Text('${i + 1}.', style: _howToLine)),
                  Expanded(child: Text(line, style: _howToLine)),
                ]),
            ]),
          ),
      ]);
}

enum _Step { pick, finding, tooSmall, crop, check, cloths }

/* The box round a square's corners. */
Rect _boundsOf(Float32List q) {
  var x0 = q[0], x1 = q[0], y0 = q[1], y1 = q[1];
  for (var k = 2; k < 8; k += 2) {
    x0 = math.min(x0, q[k]);
    x1 = math.max(x1, q[k]);
    y0 = math.min(y0, q[k + 1]);
    y1 = math.max(y1, q[k + 1]);
  }
  return Rect.fromLTRB(x0, y0, x1, y1);
}
