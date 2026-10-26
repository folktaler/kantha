/* The phone's bottom sheet and what goes in it, as the redesign handover draws them: rows and 48 px
   buttons. Corners and the focus ring are the constituition design system's (2 px; the ring in the action colour). */
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../l10n/app_localizations.dart';
import '../pressable.dart';
import 'phone_theme.dart';

/* A bottom sheet: the scrim (a tap closes it), paper, its top corners 2 px, at most 76 % of the screen and as wide as the studio's
   column, centred, scrolling, 24 px under its last row; a header that stays as the rest scrolls, with `title` and a 48 × 48 Close; `intro` under it. `builder`
   makes the body each frame (sheets that watch the controller wrap it in a ListenableBuilder). `drag: false` keeps a
   downward stroke inside it (a crop square moved) from pulling the sheet down; while `locked` holds true the body does
   not scroll, so a stroke there goes to what is under the finger. */
Future<T?> showPhoneSheet<T>(BuildContext context, {required String title, String? intro, required WidgetBuilder builder,
    bool drag = true, ValueListenable<bool>? locked}) {
  final height = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<T>(
    context: context,
    barrierColor: PhonePalette.scrim,
    backgroundColor: PhonePalette.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(2))),
    isScrollControlled: true,
    enableDrag: drag,
    useSafeArea: true,
    constraints: BoxConstraints(maxWidth: studioColumnWidth, maxHeight: 0.76 * height),
    builder: (context) => _Sheet(title: title, intro: intro, builder: builder, locked: locked),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.intro, required this.builder, required this.locked});
  final String title;
  final String? intro;
  final WidgetBuilder builder;
  final ValueListenable<bool>? locked;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 0, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(header: true, child: Text(title, style: pText(PType.sectionTitle))),
          )),
          const SizedBox(width: 8),
          Pressable(
            label: L.of(context).canvasClose,
            // As the scrim and Escape do: a sheet may first finish what is waiting (Add a piece).
            onPressed: () => Navigator.of(context).maybePop(),
            builder: (context, st) => focusRing(st.focused, SizedBox(width: 48, height: 48,
                child: ColoredBox(color: st.hovered ? PhonePalette.hover : const Color(0x00000000),
                    child: Center(child: tablerIcon(const tabler.X(), size: 20))))),
          ),
        ]),
      ),
      Flexible(child: _scrolling(context, Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (intro != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(intro!, style: pText(PType.bodySmall, color: PhonePalette.text2))),
        builder(context),
      ]))),
    ]);
  }

  Widget _scrolling(BuildContext context, Widget body) {
    Widget scroll(bool still) => SingleChildScrollView(
          physics: still ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
          child: body,
        );
    final locked = this.locked;
    return locked == null ? scroll(false) : ValueListenableBuilder<bool>(valueListenable: locked, builder: (_, still, _) => scroll(still));
  }
}

/* A yes-or-no question in the theme's dialog: Cancel answers false, `yes` true. */
Future<bool> askSure(BuildContext context, {required String question, required String yes}) async {
  final cancel = L.of(context).deviceDeleteCancel;
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(cancel)),
        TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(yes)),
      ],
    ),
  );
  return sure == true;
}

/* What a row ends in: nothing, a check (the one in use), a chevron (it opens something), or `action` in blue. */
enum RowEnd { none, check, chevron, action }

/* A list row: at least 56 tall, padding 8 16 8 13 inside a 3 px left edge (the action colour, on the tint, when
   selected), a 1 px divider 16 px in from the left; `name` in the card-label role over `note` in fine print, text2; `leading` an optional 48 px widget;
   `icon` an optional Tabler icon before the name, sized to it (`iconBusy`, a spinner, takes its place). One button,
   named by its name and note. */
class SheetRow extends StatelessWidget {
  const SheetRow({super.key, required this.name, this.note, this.end = RowEnd.chevron, this.action, this.selected = false,
      this.leading, this.icon, this.iconBusy, required this.onPressed});
  final String name;
  final String? note, action;
  final RowEnd end;
  final bool selected;
  final Widget? leading;
  final tabler.Icon? icon;
  final Widget? iconBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final trailing = switch (end) {
      RowEnd.none => null,
      RowEnd.check => tablerIcon(const tabler.Check(), size: 16, color: PhonePalette.blue),
      RowEnd.chevron => tablerIcon(const tabler.ChevronRight(), size: 16, color: PhonePalette.text2),
      RowEnd.action => Text(action ?? '', style: pText(PType.control, color: PhonePalette.blue)),
    };
    return Pressable(
      label: note == null ? name : '$name\n$note',
      selected: selected,
      excludeChildSemantics: true,
      onPressed: onPressed,
      builder: (context, st) => focusRing(st.focused, Stack(children: [
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          // The 3 px edge adds to the 13: the words start 16 in, as the divider does.
          padding: const EdgeInsets.fromLTRB(13, 8, 16, 8),
          decoration: BoxDecoration(
            color: selected ? PhonePalette.tint : PhonePalette.white,
            border: Border(left: BorderSide(width: 3, color: selected ? PhonePalette.blue : const Color(0x00000000))),
          ),
          child: Row(children: [
            if (leading != null) ...[SizedBox.square(dimension: 48, child: Center(child: leading)), const SizedBox(width: 12)],
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (icon != null) leadIcon(icon!, PType.cardLabel, busy: iconBusy),
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: pText(PType.cardLabel)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: pText(PType.finePrint, color: PhonePalette.text2)),
                ],
              ])),
            ])),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ]),
        ),
        const Positioned(left: 16, right: 0, bottom: 0, height: 1, child: ColoredBox(color: PhonePalette.border)),
      ])),
    );
  }
}

/* blue, dark, red: filled, white words. outlinedRed: white, a 1 px red edge, red words. text: no ground, blue words
   (the top bar's Save). redText: no ground, red words, the red tint under a pointer (Delete box). */
enum PhoneButtonKind { blue, dark, red, outlinedRed, text, redText }

/* A dark button's hover: constituition.component.button.neutral.hover. */
const _darkHover = Color(0xFF37322F);

/* A 48 px button with 2 px corners, its words in the control role at the left (0 16; a text button 0 12), `icon` (Tabler)
   before them in their colour. `busy` shows a spinner after them and takes no press; with no `onPressed` it is drawn disabled. */
class PhoneButton extends StatelessWidget {
  const PhoneButton({super.key, required this.text, required this.onPressed, this.kind = PhoneButtonKind.blue, this.icon,
      this.busy = false});
  final String text;
  final VoidCallback? onPressed;
  final PhoneButtonKind kind;
  final tabler.Icon? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: busy ? null : onPressed,
      builder: (context, st) {
        final off = !st.enabled && !busy;
        final h = st.hovered, bare = kind == PhoneButtonKind.text || kind == PhoneButtonKind.redText;
        final (Color ground, Color words, Color? edge) = switch (kind) {
          _ when off && bare => (const Color(0x00000000), PhonePalette.strong, null),
          _ when off && kind == PhoneButtonKind.outlinedRed => (PhonePalette.white, PhonePalette.strong, PhonePalette.strong),
          _ when off => (PhonePalette.disabled, PhonePalette.text2, null),
          PhoneButtonKind.blue => (h ? PhonePalette.blueDark : PhonePalette.blue, PhonePalette.white, null),
          PhoneButtonKind.dark => (h ? _darkHover : PhonePalette.dark, PhonePalette.white, null),
          PhoneButtonKind.red => (h ? PhonePalette.redDark : PhonePalette.red, PhonePalette.white, null),
          PhoneButtonKind.outlinedRed => (h ? PhonePalette.redTint : PhonePalette.white, PhonePalette.red, PhonePalette.red),
          PhoneButtonKind.text => (h ? PhonePalette.hover : const Color(0x00000000), PhonePalette.blue, null),
          PhoneButtonKind.redText => (h ? PhonePalette.redTint : const Color(0x00000000), PhonePalette.red, null),
        };
        final after = busy ? SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: words)) : null;
        return focusRing(st.focused, Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: bare ? 12 : 16),
          decoration: BoxDecoration(color: ground, borderRadius: kControlRadius, border: edge == null ? null : Border.all(color: edge)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[roleIcon(icon!, PType.control, color: words), const SizedBox(width: iconGap)],
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: pText(PType.control, color: words))),
            if (after != null) ...[const SizedBox(width: 8), after],
          ]),
        ));
      },
    );
  }
}
