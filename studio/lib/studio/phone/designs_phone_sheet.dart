/* My designs on a phone (redesign handover, Bottom sheets; decision 5): a row for each saved design, its picture small
   at its start and its box under its name, opened by Open; a ⋯ beside each for rename, duplicate and delete. A picture
   whose design has gone with its cloth is a row of its own, Picture only, opened by View; its ⋯ deletes it. Last saved
   first; New design last. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../l10n/app_localizations.dart';
import '../../l10n/words.dart';
import '../controller.dart';
import '../pressable.dart';
import '../shelf_feed.dart';
import '../studio_screen.dart';
import 'phone_sheet.dart';
import 'phone_theme.dart';

/* My designs' rows, last saved first: each saved design with its picture (null for one saved before pictures were
   made, until it is saved again), and each picture whose design has gone. */
typedef DesignsEntry = ({DesignView? design, PictureView? picture});

List<DesignsEntry> designsEntries(StudioController c) {
  final ids = {for (final d in c.saved) d.id};
  final rows = [
    for (final d in c.saved) (design: d, picture: c.pictureOf(d.id), at: d.saved),
    for (final p in c.pictures)
      if (p.design == null || !ids.contains(p.design)) (design: null, picture: p, at: p.made),
  ]..sort((a, b) => b.at.compareTo(a.at));
  return [for (final r in rows) (design: r.design, picture: r.picture)];
}

/* A picture's small copy, 38 × 48 (its 4:5) on the canvas ground in a 1 px edge, decoded at that size; the ground and
   edge alone for a design with no picture yet. */
Widget pictureThumb(BuildContext context, PictureView? p) {
  const w = 38.0, h = 48.0;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Container(
    key: p == null ? null : ValueKey('thumb-${p.id}'),
    width: w, height: h, color: PhonePalette.canvas,
    foregroundDecoration: BoxDecoration(border: Border.all(color: const Color(0x1F000000))),
    child: p == null ? null : Image(
        image: ResizeImage(p.thumb, width: (w * dpr).round(), height: (h * dpr).round(), policy: ResizeImagePolicy.fit),
        fit: BoxFit.cover, excludeFromSemantics: true, gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink()),
  );
}

Future<void> showDesignsPhone(BuildContext context, {required StudioController c, required StudioActions actions}) {
  final words = L.of(context);
  return showPhoneSheet<void>(
    context,
    title: words.canvasPanelsEyebrow,
    builder: (sheet) => ListenableBuilder(
      listenable: c,
      builder: (_, _) {
        final entries = designsEntries(c);
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // The sheet's intro, drawn here so it comes and goes with the last row.
        if (entries.isEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(words.canvasNoSaved, style: pText(PType.bodySmall, color: PhonePalette.text2))),
        for (final e in entries)
          if (e.design case final p?)
            _DesignRow(key: ValueKey(p.id), sheet: sheet, c: c, p: p, picture: e.picture, words: words)
          else
            _PictureRow(key: ValueKey('picture-${e.picture!.id}'), sheet: sheet, c: c, p: e.picture!, actions: actions,
                words: words),
        SheetRow(name: words.canvasNewDesign, icon: const tabler.SquarePlus(), end: RowEnd.action, action: words.canvasAdd, onPressed: () {
          c.newDesign();
          Navigator.of(sheet).pop();
        }),
      ]);
      },
    ),
  );
}

/* Where a design was made: its box, by number or as the Sample; a box no longer hers, its pattern. */
String _from(StudioController c, DesignView p, L words) {
  final b = p.box;
  if (b == null || !c.ownBoxes.contains(b)) return words.layoutTitle(p.layout);
  if (c.isSample(b)) return words.boxesSample;
  final n = c.boxNumbers[b];
  return n == null ? words.layoutTitle(p.layout) : words.boxesName('$n');
}

/* A design's row, ending in Open, and its ⋯ beside it: a button of its own, so a tap on it opens nothing. */
class _DesignRow extends StatelessWidget {
  const _DesignRow({super.key, required this.sheet, required this.c, required this.p, required this.picture,
      required this.words});
  /* My designs itself: the ⋯ sheet and its dialogs are shown from it, since the row goes if the design is deleted
     elsewhere while they are up. */
  final BuildContext sheet;
  final StudioController c;
  final DesignView p;
  final PictureView? picture;
  final L words;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.only(right: 48),
        child: SheetRow(name: p.name, note: _from(c, p, words), end: RowEnd.action, action: words.canvasOpen,
            leading: pictureThumb(context, picture),
            // A design whose cloth has gone is not opened, and My designs closes all the same, so the studio's toast
            // saying why is read (decision 29).
            onPressed: () {
              c.openSaved(p);
              Navigator.of(context).pop();
            }),
      ),
      _more(words, () => _showMore(sheet, c, p)),
      // The row's divider, on under the ⋯.
      const Positioned(right: 0, bottom: 0, width: 48, height: 1, child: ColoredBox(color: PhonePalette.border)),
    ]);
  }
}

/* A row's ⋯, 48 wide at its end. */
Widget _more(L words, VoidCallback onPressed) => Positioned(
      right: 0, top: 0, bottom: 0, width: 48,
      child: Pressable(
        label: words.canvasMore,
        excludeChildSemantics: true,
        onPressed: onPressed,
        builder: (context, st) => focusRing(st.focused, ColoredBox(
          color: st.hovered ? PhonePalette.hover : PhonePalette.white,
          child: Center(child: tablerIcon(const tabler.Dots(), size: 20)),
        )),
      ),
    );

/* A picture whose design has gone: Picture only, ending in View, which opens it over My designs; its ⋯ deletes it. */
class _PictureRow extends StatelessWidget {
  const _PictureRow({super.key, required this.sheet, required this.c, required this.p, required this.actions,
      required this.words});
  final BuildContext sheet;
  final StudioController c;
  final PictureView p;
  final StudioActions actions;
  final L words;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Padding(
          padding: const EdgeInsets.only(right: 48),
          child: SheetRow(name: p.name, note: words.canvasPictureOnly, end: RowEnd.action, action: words.canvasView,
              leading: pictureThumb(context, p), onPressed: () => actions.openPicture(sheet, p)),
        ),
        _more(words, () => _showPictureMore(sheet, c, p)),
        const Positioned(right: 0, bottom: 0, width: 48, height: 1, child: ColoredBox(color: PhonePalette.border)),
      ]);
}

/* A picture's ⋯ sheet: Delete, asked first, as a design's is. */
Future<void> _showPictureMore(BuildContext context, StudioController c, PictureView p) {
  final words = L.of(context);
  return showPhoneSheet<void>(
    context,
    title: p.name,
    builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetRow(name: words.canvasDelete, icon: const tabler.Trash(), onPressed: () async {
        Navigator.of(sheet).pop();
        if (!context.mounted || !c.pictures.any((x) => x.id == p.id)) return;
        if (!await askSure(context, question: words.canvasDeleteSure(p.name), yes: words.canvasDelete)) return;
        final done = await c.deletePicture(p.id);
        if (context.mounted) _closeOnFailure(context, done);
      }),
    ]),
  );
}

/* My designs goes, if it is still the one on top: storage failed, and the studio's toast saying so is read there
   (decision 29). */
void _closeOnFailure(BuildContext sheet, bool done) {
  if (!done && (ModalRoute.of(sheet)?.isCurrent ?? false)) Navigator.of(sheet).pop();
}

/* The ⋯ sheet, over My designs: Rename, Duplicate, Delete. A row closes it first; My designs stays, unless storage
   fails. A design deleted elsewhere while it is up is neither renamed nor asked about. */
Future<void> _showMore(BuildContext context, StudioController c, DesignView p) {
  final words = L.of(context);
  return showPhoneSheet<void>(
    context,
    title: p.name,
    builder: (sheet) {
      void go(VoidCallback then) {
        Navigator.of(sheet).pop();
        then();
      }
      bool kept() => context.mounted && c.saved.any((d) => d.id == p.id);
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetRow(name: words.editBoxRename, onPressed: () => go(() { if (kept()) _rename(context, c, p); })),
        SheetRow(name: words.canvasDuplicate, icon: const tabler.Copy(), onPressed: () => go(() => _duplicate(context, c, p))),
        SheetRow(name: words.canvasDelete, icon: const tabler.Trash(), onPressed: () => go(() { if (kept()) _delete(context, c, p); })),
      ]);
    },
  );
}

/* Rename: the name in a field, all of it chosen; Rename (or Enter) keeps it, Cancel leaves it. */
Future<void> _rename(BuildContext context, StudioController c, DesignView p) async {
  final name = await showDialog<String>(context: context, builder: (_) => _RenameDialog(name: p.name));
  final done = await c.rename(p, name);
  if (context.mounted) _closeOnFailure(context, done);
}

Future<void> _duplicate(BuildContext context, StudioController c, DesignView p) async {
  final done = await c.duplicate(p);
  if (context.mounted) _closeOnFailure(context, done);
}

/* Its own state, so the field's text outlives the dialog's closing frames. */
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name});
  final String name;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _text = TextEditingController(text: widget.name)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.name.length);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = L.of(context);
    return AlertDialog(
      content: TextField(
        controller: _text, autofocus: true, maxLength: 80, maxLengthEnforcement: MaxLengthEnforcement.enforced,
        style: pText(PType.field), cursorColor: PhonePalette.text,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        decoration: InputDecoration(
          labelText: words.canvasPanelName, counterText: '',
          labelStyle: pText(PType.bodySmall, color: PhonePalette.text2),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: PhonePalette.strong)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: PhonePalette.blue, width: 2)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(words.deviceDeleteCancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(_text.text), child: Text(words.editBoxRename)),
      ],
    );
  }
}

/* Delete asks first. */
Future<void> _delete(BuildContext context, StudioController c, DesignView p) async {
  final words = L.of(context);
  if (!await askSure(context, question: words.canvasDeleteSure(p.name), yes: words.canvasDelete)) return;
  final done = await c.deleteSaved(p.id);
  if (context.mounted) _closeOnFailure(context, done);
}
