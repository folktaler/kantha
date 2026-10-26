/* Add a piece, the Add a piece sheet's body (redesign handover, decision 3): a photo of the piece,
   cropped square, and how many; Add measures it on the device and puts it in the box. The fabric is not asked:
   one line says what works best (spec 2026-10-07 sample box, decision 9). The sheet stays open for the next one;
   after an add a banner says what went in, until the sheet closes. Every close (Done, the ×, the scrim, back, Escape)
   with a photo waiting adds it as Add does, then closes; if the add fails the sheet stays open with the error and the
   photo (owner, 22 October 2026). */
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../data/database.dart';
import '../data/numbers.dart' show startCount;
import '../data/shelf.dart';
import '../l10n/app_localizations.dart';
import '../measure/measure.dart';
import '../studio/phone/phone_sheet.dart' show PhoneButton, PhoneButtonKind;
import '../studio/phone/phone_theme.dart';
import '../studio/pressable.dart';
import 'crop_step.dart';
import 'parts.dart';
import 'photo_source.dart';
import 'prepare.dart';

class AddCloth extends StatefulWidget {
  const AddCloth({super.key, required this.box, required this.shelf, required this.photos, required this.words,
      required this.onClose, this.cropHeld, this.read = readPhoto});
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

  @override
  State<AddCloth> createState() => _AddClothState();
}

class _AddClothState extends State<AddCloth> {
  L get words => widget.words;
  final _crop = CropController();
  final _session = <ClothRow>[];
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

  /* The picture let go of (replaced, reset, saved, or the card closed): on the web its decoded bitmap is closed now,
     not left for the garbage collector. Called inside setState, or from dispose. */
  void _letGo() {
    _photo?.close();
    _photo = null;
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
    } else {
      photo.close(); // another picture was picked, or the card closed, while this one was read
    }
  }

  void _reset() => setState(() { _picture = null; _letGo(); _ready = false; _reading = false; });

  /* Done, and every other close: with no photo waiting the sheet closes; with one, it is added first, by the same
     path as Add. */
  void _done() {
    if (_picture == null) return widget.onClose();
    _closeAfter = true;
    if (!_busy) _submit();
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
        _session.add(row);
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
          key: ObjectKey(_picture), photo: _photo, controller: _crop, coverage: 0.7, hint: words.clothCropHint,
          onCropped: _cropped, onReady: () {
            if (!mounted) return;
            setState(() {
              _ready = true;
              _reading = false;
              // A close or an add pressed while the photo was read said to wait: it is ready now.
              if (_error == words.clothErrorsNotReady) _error = '';
            });
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
    final last = _session.isEmpty ? null : _session.last;
    // The ×, the scrim, back and Escape ask the sheet to close; with a photo waiting they go through Done.
    return PopScope<Object?>(canPop: _picture == null, onPopInvokedWithResult: (didPop, _) { if (!didPop) _done(); },
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: 16, children: [
      if (last != null) _added(last),
      ..._photoOrCrop(),
      _howToBlock(),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(words.clothHowMany, style: pText(PType.cardLabel)),
          const SizedBox(height: 2),
          Text(words.clothRecommend, style: pText(PType.finePrint, color: PhonePalette.text2)),
        ])),
        const SizedBox(width: 12),
        PieceCounter(count: _count, shown: words.clothPiece(_count), fewer: words.clothFewer, more: words.clothMore,
            enabled: !_busy, onChanged: (n) => setState(() => _count = n)),
      ]),
      if (_error.isNotEmpty) cardError(_error),
      Row(children: [
        Expanded(child: PhoneButton(text: words.canvasHideControls, kind: PhoneButtonKind.dark, onPressed: _done)),
        const SizedBox(width: 8),
        Expanded(child: PhoneButton(text: _submitText, busy: _busy || _reading, onPressed: _submit)),
      ]),
    ]));
  }

  /* At least 48 tall on the note ground, a 3 px ink edge at the left, a 16 px check in ink, and what went in, in the
     body-small role. */
  Widget _added(ClothRow row) => Semantics(
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
            Expanded(child: Text(words.clothAddedNext(row.pieces, row.name), style: pText(PType.bodySmall))),
          ]),
        ),
      );

  /* The photo field (the <label> round the file input): a tap anywhere on it takes a photo.
     On a phone app the gallery is its own door under it; on the web the browser's file box offers both. */
  List<Widget> _photoField() => [
        Pressable(
          onPressed: _busy || _reading ? null : () => _pick(camera: !kIsWeb),
          builder: (context, st) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(words.clothPhoto, style: pText(PType.cardLabel)),
            const SizedBox(height: 5),
            focusRing(st.focused, Container(
              key: const ValueKey('photo-field'),
              height: 140,
              decoration: BoxDecoration(color: st.hovered ? PhonePalette.hover : PhonePalette.canvas,
                  border: Border.all(color: PhonePalette.border)),
              child: Center(child: tablerIcon(const tabler.Camera(), size: 24, color: PhonePalette.text2)),
            )),
            const SizedBox(height: 5),
            cardHint(words.clothPhotoHint),
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
              for (final (i, line) in [words.clothHowTo1, words.clothHowTo2, words.clothHowTo3].indexed)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 20, child: Text('${i + 1}.', style: _howToLine)),
                  Expanded(child: Text(line, style: _howToLine)),
                ]),
            ]),
          ),
      ]);
}
