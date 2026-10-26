/* The shortfall banner (redesign handover, Canvas, "Shortfall banner"): over the foot of the phone's canvas while a box of
   hers holds some cloth but not yet a panel's 35 pieces, it says how many more, and the whole of it opens Add a piece. */
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../solver/geometry.dart' show cells;
import '../controller.dart';
import '../pressable.dart';
import 'phone_theme.dart';

class ShortfallBanner extends StatelessWidget {
  const ShortfallBanner({super.key, required this.c, required this.onPressed});
  final StudioController c;
  final VoidCallback onPressed;

  /* Some cloth, fewer than 35 pieces, in a box she may change. With none the Cloth box tab's tooltip speaks instead. */
  static bool shows(StudioController c) {
    final box = c.box;
    if (box == null || !c.mayEdit) return false;
    final n = c.piecesIn(box);
    return n > 0 && n < cells;
  }

  /* Min 48 tall on the red tint, a 3 px red left edge, padding 8 12 8 14 and the shadow; the sentence at 13 on the left,
     Add pieces in blue 13 on the right, never wrapped. One button, named by its sentence. */
  @override
  Widget build(BuildContext context) {
    final words = L.of(context);
    final sentence = words.canvasAddMore(cells - c.piecesIn(c.box!));
    return Pressable(
      key: const ValueKey('shortfall-banner'),
      label: sentence,
      excludeChildSemantics: true,
      onPressed: onPressed,
      builder: (context, st) => focusRing(st.focused, Container(
        key: const ValueKey('shortfall-box'),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        decoration: const BoxDecoration(
          color: PhonePalette.redTint,
          border: Border(left: BorderSide(color: PhonePalette.red, width: 3)),
          boxShadow: [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 2), blurRadius: 6)],
        ),
        child: Row(children: [
          Expanded(child: Text(sentence, style: pText(PType.metadata))),
          const SizedBox(width: 12),
          Text(words.boxesAddPieces, softWrap: false, style: pText(PType.metadata, color: PhonePalette.blue)),
        ]),
      )),
    );
  }
}
