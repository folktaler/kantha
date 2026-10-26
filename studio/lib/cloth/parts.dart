/* The pieces the add and fix cards share: the
   title, a field with its legend, the counter, the buttons, and the error line. */
import 'package:flutter/material.dart';
import '../data/shelf.dart';
import '../l10n/app_localizations.dart';
import '../measure/measure.dart';
import '../studio/phone/phone_theme.dart';
import '../platform/report.dart';

/* The words for what went wrong (cloth.errors.*). `fileName` is the picked file's, when known. */
String clothError(L words, Object e, {String? fileName}) => switch (e) {
      ShelfError(key: 'badCount') => words.clothErrorsBadCount,
      ShelfError(key: 'boxFull', :final values) => words.clothErrorsBoxFull('${values['limit']}'),
      ShelfError(key: 'badBox') => words.clothErrorsBadBox,
      ShelfError(key: 'noSuchCloth') => words.clothErrorsNoSuchCloth,
      MeasureError() => fileName != null ? words.clothErrorsBadPhoto(fileName) : words.clothErrorsUnreadable,
      _ => words.clothErrorsPieceFailed,
    };

/* What she is told is hers to fix (a bad count, a full box); anything else is logged as well. */
bool _expected(Object e) => e is MeasureError || (e is ShelfError && e.key != 'storage');

void reportClothError(Object e, StackTrace? s, String doing) {
  if (_expected(e)) return;
  reportError(e, s, doing, library: 'kantha cloth');
}

/* .hint: a note, the fine-print role in text2. */
Widget cardHint(String text) => Text(text, style: pText(PType.finePrint, color: PhonePalette.text2));

/* .error, role="alert": the body-small role in the phone's red. */
Widget cardError(String text) => Semantics(
      liveRegion: true,
      child: Text(text, style: pText(PType.bodySmall, color: PhonePalette.red)),
    );

/* .counter: − the count +, from 1 to 500, as the redesign handover's stepper: 48 px square buttons with 2 px corners
   (constituition.radius.control), the count in the label-strong role in tabular figures. */
class PieceCounter extends StatelessWidget {
  const PieceCounter({super.key, required this.count, required this.shown, required this.fewer, required this.more,
      required this.onChanged, this.enabled = true});
  final int count;
  final String shown, fewer, more;
  final ValueChanged<int> onChanged;
  final bool enabled;

  Widget _step(String glyph, String label, int? to) {
    final on = enabled && to != null;
    const side = 48.0;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: IconButton(
        onPressed: on ? () => onChanged(to) : null,
        style: IconButton.styleFrom(
          fixedSize: const Size(side, side), minimumSize: const Size(side, side), padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: PhonePalette.white,
          disabledBackgroundColor: PhonePalette.white,
          foregroundColor: PhonePalette.text,
          disabledForegroundColor: PhonePalette.text,
          shape: const RoundedRectangleBorder(borderRadius: kControlRadius, side: BorderSide(color: PhonePalette.strong)),
        ),
        icon: Semantics(label: label, child: ExcludeSemantics(child: Text(glyph, style: pText(PType.controlLarge)))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _step('−', fewer, count > 1 ? count - 1 : null),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72),
          child: Semantics(liveRegion: true,
              child: Text(shown, textAlign: TextAlign.center, style: pText(PType.labelStrong, figures: true))),
        ),
        const SizedBox(width: 10),
        _step('+', more, count < 500 ? count + 1 : null),
      ]);
}

/* Before work that holds the page still (on the web, compute runs in place): the frame that
   says so is drawn, then the browser is let paint it: the work waits for the frame after. Work
   that ran straight after the first frame, in the same browser task, would start before the
   paint (measured: Add held the page 6 s with Measuring… not yet on it). */
Future<void> paintedFirst() async {
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
}

/* On a sheet: while a finger is on `child` (the crop), `held` is true, so the sheet holds still and the stroke
   moves the square. Each finger counts; the last one lifted lets the sheet scroll again, as does the crop going. */
class CropHold extends StatefulWidget {
  const CropHold({super.key, required this.held, required this.child});
  final ValueNotifier<bool> held;
  final Widget child;

  @override
  State<CropHold> createState() => _CropHoldState();
}

class _CropHoldState extends State<CropHold> {
  final _down = <int>{};

  void _set(PointerEvent e, bool down) {
    down ? _down.add(e.pointer) : _down.remove(e.pointer);
    widget.held.value = _down.isNotEmpty;
  }

  @override
  void dispose() {
    // Gone under a finger (a photo added, say): the sheet scrolls again, once this frame is done.
    if (_down.isNotEmpty) {
      final held = widget.held;
      WidgetsBinding.instance.addPostFrameCallback((_) => held.value = false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (e) => _set(e, true),
        onPointerUp: (e) => _set(e, false),
        onPointerCancel: (e) => _set(e, false),
        child: widget.child,
      );
}
