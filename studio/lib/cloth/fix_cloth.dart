/* Fix this cloth: the body of a sheet titled with the cloth's name (redesign handover, "Fix this
   cloth"): its crop, how many, one Save, and Remove. The fabric is not asked (spec 2026-10-07 sample box, decision 9):
   what was stored is kept as it is. The crop can only go further in — the stored photo is all that was kept — and it
   is sent only once she has moved it: a re-crop measures the cloth again, so a change of count must not cause one.
   `allUsed` says every piece of it is on the board. `usedBy` counts the saved designs made from it, which Remove's
   question names, and `remove` takes it out (the studio's, which keeps those designs' pictures first; the shelf's
   removeCloth when not given). */
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../data/database.dart';
import '../data/shelf.dart';
import '../l10n/app_localizations.dart';
import '../studio/phone/phone_sheet.dart' show PhoneButton, PhoneButtonKind, askSure;
import '../studio/phone/phone_theme.dart';
import 'crop_step.dart';
import 'parts.dart';
import 'prepare.dart';

enum FixDone { saved, recropped, removed }

class FixCloth extends StatefulWidget {
  const FixCloth({super.key, required this.cloth, required this.shelf, required this.words, required this.onDone,
      this.allUsed = false, this.cropHeld, this.usedBy, this.remove});
  final ClothRow cloth;
  final Shelf shelf;
  final L words;
  final ValueChanged<FixDone> onDone;
  /* Every piece of it is in the design: an intro says so. */
  final bool allUsed;
  /* True while a finger is on the crop, so the sheet holds still. */
  final ValueNotifier<bool>? cropHeld;
  final int Function()? usedBy;
  final Future<void> Function()? remove;

  @override
  State<FixCloth> createState() => _FixClothState();
}

class _FixClothState extends State<FixCloth> {
  L get words => widget.words;
  ClothRow get cloth => widget.cloth;
  final _crop = CropController();
  bool _ready = false, _busy = false, _touched = false, _removing = false;
  late int _count = cloth.pieces;
  String _error = '';
  /* The stored photo, once read: until then the stage is shown empty. One that will not read stays so, as it did
     when the cropper read it itself. */
  PickedPhoto? _photo;

  @override
  void initState() {
    super.initState();
    readPhoto(cloth.photo).then((p) {
      // Read after the card closed: let go of at once.
      if (mounted) { setState(() => _photo = p); } else { p.close(); }
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _photo?.close(); // on the web its decoded bitmap is closed now, not left for the garbage collector
    super.dispose();
  }

  bool get _fieldsChanged => _count != cloth.pieces;

  void _fail(Object e, StackTrace? s, String doing) {
    reportClothError(e, s, doing);
    if (mounted) setState(() { _busy = false; _removing = false; _error = clothError(words, e); });
  }

  Future<void> _remove() async {
    final used = widget.usedBy?.call() ?? 0;
    final sure = await askSure(context, question: used == 0 ? words.clothRemoveSure : words.clothRemoveUsed(used),
        yes: words.clothRemoveThis);
    if (!sure || !mounted) return;
    setState(() { _busy = true; _removing = true; _error = ''; });
    try {
      await (widget.remove ?? () => widget.shelf.removeCloth(cloth.id))();
      widget.onDone(FixDone.removed);
    } catch (e, s) {
      _fail(e, s, 'while a cloth was removed');
    }
  }

  /* The count first, when it changed; then the crop, when she moved it. */
  Future<void> _save() async {
    if (_touched && !_ready) return setState(() => _error = words.clothErrorsNotReady);
    setState(() { _busy = true; _error = ''; });
    try {
      if (_fieldsChanged) await widget.shelf.editCloth(cloth.id, fabric: cloth.fabric, pieces: _count);
    } catch (e, s) {
      return _fail(e, s, 'while a cloth was changed');
    }
    if (!_touched) return widget.onDone(FixDone.saved);
    // Drawn as busy first: the crop and the measure can hold the page still.
    await paintedFirst();
    if (mounted) _crop.crop();
  }

  void _cropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        _recrop(croppedImage);
      case CropFailure(:final cause, :final stackTrace):
        reportClothError(cause, stackTrace, 'while the photo was cropped');
        if (mounted) setState(() { _busy = false; _error = words.clothErrorsNotReady; });
    }
  }

  Future<void> _recrop(Uint8List square) async {
    try {
      final out = await preparePhoto(square);
      await widget.shelf.recrop(cloth.id, out.jpeg, out.measured);
      widget.onDone(FixDone.recropped);
    } catch (e, s) {
      _fail(e, s, 'while a cloth was measured again');
    }
  }

  Widget _cropStep() => CropStep(
        photo: _photo, controller: _crop, coverage: 0.9, hint: words.clothFixWiden, onCropped: _cropped,
        onReady: () { if (mounted) setState(() => _ready = true); },
        onTouched: () { if (!_touched && !_busy) setState(() => _touched = true); },
      );

  VoidCallback? get _saveable => _busy || (!_touched && !_fieldsChanged) ? null : _save;

  /* The intro when all are used, the crop, Pieces in the box beside its counter, Save changes and Remove this piece,
     48 tall. */
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: 16, children: [
        if (widget.allUsed)
          Text(words.clothFixAllUsed('${cloth.pieces}'), style: pText(PType.bodySmall, color: PhonePalette.text2)),
        if (widget.cropHeld case final held?) CropHold(held: held, child: _cropStep()) else _cropStep(),
        Row(children: [
          Expanded(child: Text(words.clothPiecesInBox, style: pText(PType.cardLabel))),
          const SizedBox(width: 12),
          PieceCounter(count: _count, shown: '$_count', fewer: words.clothFewer, more: words.clothMore,
              enabled: !_busy, onChanged: (n) => setState(() => _count = n)),
        ]),
        if (_error.isNotEmpty) cardError(_error),
        PhoneButton(text: _busy ? words.clothFixBusy : words.clothSaveChanges, busy: _busy, onPressed: _saveable),
        PhoneButton(text: words.clothRemoveThis, kind: PhoneButtonKind.outlinedRed, busy: _removing,
            onPressed: _busy ? null : _remove),
      ]);
}
