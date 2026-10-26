/* Your boxes on a phone (redesign handover, Bottom sheets), opened from the Cloth box tab's picker: the Sample box first,
   then hers, newest first, the one on the board checked; Add a box, and with no Sample box Add sample cloth. A row
   turns the studio to its box and closes the sheet. A box once made is opened whether
   or not the sheet is still up; the sheet then closes, and so it does when the box could not be made, so the toast
   saying why is read on the studio. */
import 'package:flutter/material.dart';
import '../../cloth/parts.dart' show clothError, paintedFirst;
import '../../data/sample_box.dart';
import '../../l10n/app_localizations.dart';
import '../controller.dart';
import 'phone_sheet.dart';
import 'phone_theme.dart';
import 'phone_toast.dart';
import '../../platform/report.dart';

/* Delete box: asked first, in the Sample box's own words when it is that one (decision 17), and saying its pieces
   go too when it holds any (owner, 20 Oct), as the shelf holds it now. Asked again, in the words for what it holds
   then, when it took cloth after she was asked (another tab). Nothing is asked while a delete runs, nor again while
   the question is being prepared or asked (a second press). True once the box has gone. */
Future<bool> askDeleteBox(BuildContext context, {required StudioController c, required int box}) async {
  if (_asking[c] ?? false) return false;
  _asking[c] = true;
  try {
    return await _askDeleteBox(context, c: c, box: box);
  } finally {
    _asking[c] = false;
  }
}

/* The studios asking Delete box now. */
final _asking = Expando<bool>();

Future<bool> _askDeleteBox(BuildContext context, {required StudioController c, required int box}) async {
  final words = c.words;
  final n = '${c.boxNumbers[box] ?? ''}';
  while (!c.deleting && context.mounted) {
    Set<String> held;
    try {
      held = await c.shelf.clothIn(box);
    } on Object {
      held = {for (final m in c.members(box)) c.cloth[m].id}; // the studio's copy: the shelf still refuses other cloth
    }
    if (!context.mounted) return false;
    final question = switch ((c.isSample(box), held.isNotEmpty)) {
      (true, true) => words.boxesDeleteSampleFullAsk,
      (true, false) => words.boxesDeleteSampleAsk,
      (false, true) => words.boxesDeleteFullAsk(n),
      (false, false) => words.boxesDeleteAsk(n),
    };
    if (!await askSure(context, question: question, yes: words.canvasDelete)) return false;
    final gone = await c.deleteBox(box, held);
    if (gone != null) return gone;
  }
  return false;
}

Future<void> showBoxesSheet(BuildContext context, {required StudioController c, required Toaster toaster}) =>
    showPhoneSheet<void>(context, title: L.of(context).canvasYourBoxes, builder: (_) => _Boxes(c: c, toaster: toaster));

class _Boxes extends StatefulWidget {
  const _Boxes({required this.c, required this.toaster});
  final StudioController c;
  final Toaster toaster;

  @override
  State<_Boxes> createState() => _BoxesState();
}

class _BoxesState extends State<_Boxes> {
  /* A box is being made: both Add rows wait, and a spinner says so. */
  bool _busy = false;

  StudioController get c => widget.c;

  /* The sheet goes, if it is still the one on top. */
  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
  }

  void _open(int box) {
    c.openBox(box);
    _close();
  }

  /* The Sample box reads and measures its photos on this thread on the web, so the spinner is painted first.
     `open` makes the box and opens it. */
  Future<void> _make(Future<void> Function() open, String doing) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await paintedFirst();
      await open();
    } catch (e, s) {
      // Making a box fails only when storage does: always worth the log.
      reportError(e, s, doing);
      widget.toaster.say(clothError(c.words, e));
    }
    if (mounted) setState(() => _busy = false);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final words = L.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final sample = c.sampleBox;
        final hers = [...c.ownBoxes.where((b) => !c.isSample(b))]
          ..sort((p, q) => (c.boxNumbers[q] ?? q).compareTo(c.boxNumbers[p] ?? p));
        Widget row(int b, String name, String note) => SheetRow(name: name, note: note, selected: b == c.box,
            end: b == c.box ? RowEnd.check : RowEnd.none, onPressed: () => _open(b));
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (sample != null)
            row(sample, words.boxesSample, '${words.boxesPieces(c.piecesIn(sample))} · ${words.boxesSampleColours}'),
          for (final b in hers) row(b, words.boxesName('${c.boxNumbers[b] ?? ''}'), words.boxesPieces(c.piecesIn(b))),
          SheetRow(name: words.boxesAddOne, note: words.boxesAddOneNote, end: RowEnd.action, action: words.canvasAdd,
              onPressed: _busy ? null : () => _make(() async {
                final b = await c.shelf.makeNumberedBox();
                c.openBox(b.id, made: b.number);
              }, 'while a box was made')),
          if (sample == null)
            SheetRow(name: words.boxesAddSample, end: RowEnd.action, action: words.canvasAdd,
                onPressed: _busy ? null : () => _make(() async => c.openBox(await makeSampleBox(c.shelf)), 'while the Sample box was made')),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Center(child: SizedBox.square(dimension: 18,
                  child: CircularProgressIndicator(key: ValueKey('boxes-busy'), strokeWidth: 2, color: PhonePalette.blue))),
            ),
        ]);
      },
    );
  }
}
