/* The studio's Menu, opened from ≡ in the top bar, as remarkable.com's menu behaves below 1024 px (measured 19 Oct
   2026): the panel takes the whole studio under the top bar, and its ground and the top bar's turn paper 3 together over
   0.3 s (cubic-bezier(0.4, 0, 0.2, 1)) while ≡ turns into × over the same 0.3 s; its rows fade in over 0.5 s (CSS
   `ease`). It closes at once on ×, Escape, Back, or a row chosen, and the top bar turns paper 1 again over 0.3 s.
   Help, Privacy policy, Shop and Back up or move to another device are its rows: words left-aligned 16 px in, no
   chevrons, no rules between them; Shop, which leaves for another site, carries ↗. Each row closes the menu, then goes
   where it leads. Under them, on OPFS or a phone's file only, the room her work takes here, with Free up space beside
   it when a good share of that room is empty (his decisions, 21 and 22 Oct). */
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/links.dart';
import '../pressable.dart';
import '../studio_screen.dart';
import 'phone_sheet.dart' show PhoneButton, PhoneButtonKind;
import 'phone_theme.dart';

/* Shop: the catsofkochi shop, in a new tab in a browser. Help and the privacy policy: the site's own pages, in the
   same tab in a browser and kantha.app's on a phone. openLink picks the tab (platform/links.dart). */
final shopLink = shopUri(), helpLink = helpUri(), privacyLink = privacyUri();

/* ≡ and × turn into each other: Curves.fastOutSlowIn is cubic-bezier(0.4, 0, 0.2, 1). */
const menuTurn = Duration(milliseconds: 300), menuFadeIn = Duration(milliseconds: 500);

/* Tabler's menu-2 while the menu is shut, its x while it is open. The two cannot morph into each other as Material's
   menu_close did, so over the same 0.3 s one fades and turns out of the way as the other fades and turns in; still
   where she asked for less motion. */
class MenuIcon extends StatefulWidget {
  const MenuIcon({super.key, required this.open});
  final bool open;
  @override
  State<MenuIcon> createState() => _MenuIconState();
}

class _MenuIconState extends State<MenuIcon> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, duration: menuTurn, value: widget.open ? 1 : 0);
  late final _curve = CurvedAnimation(parent: _turn, curve: Curves.fastOutSlowIn);
  late final _shut = ReverseAnimation(_curve);
  /* An eighth of a turn each: ≡ turns away as it goes, × turns into place as it comes. */
  late final _away = Tween<double>(begin: 0, end: 0.125).animate(_curve),
      _into = Tween<double>(begin: -0.125, end: 0).animate(_curve);

  @override
  void didUpdateWidget(MenuIcon old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.value = widget.open ? 1 : 0;
    } else {
      widget.open ? _turn.forward() : _turn.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: 20, child: Stack(children: [
        FadeTransition(opacity: _shut, child: RotationTransition(turns: _away, child: tablerIcon(const tabler.Menu2(), size: 20))),
        FadeTransition(opacity: _curve, child: RotationTransition(turns: _into, child: tablerIcon(const tabler.X(), size: 20))),
      ]));
}

/* The open menu, filling the room it is given. */
class MenuPanel extends StatefulWidget {
  const MenuPanel({super.key, required this.actions, required this.onClose, this.space, this.onFreeSpace,
      this.patchworker = false, this.onLevel});
  final StudioActions actions;
  /* Shuts the menu; a row calls it before it goes. */
  final VoidCallback onClose;
  /* Her database, whose size the menu says: null unless it is on OPFS or a phone's file (KanthaDatabase.freesSpace). */
  final KanthaDatabase? space;
  /* Free up space, pressed: the menu is shut first. */
  final VoidCallback? onFreeSpace;
  /* "I am a…" (owner, 30 Oct 2026): Beginner, the 5 × 7 board, or Patchworker, any size. A choice shuts the menu, as
     every row does, then tells the studio: true for Patchworker. No choice is shown without it. */
  final bool patchworker;
  final void Function(bool patchworker)? onLevel;
  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: menuFadeIn);
  late final _ease = CurvedAnimation(parent: _fade, curve: Curves.ease);
  /* The ground: paper 3 in the first 0.3 s of the 0.5. */
  late final _ground = CurvedAnimation(parent: _fade,
      curve: Interval(0, menuTurn.inMilliseconds / menuFadeIn.inMilliseconds, curve: Curves.fastOutSlowIn));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fade.value > 0 || _fade.isAnimating) return;
    MediaQuery.disableAnimationsOf(context) ? _fade.value = 1 : _fade.forward();
  }

  @override
  void dispose() {
    _ground.dispose();
    _ease.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _go(VoidCallback then) {
    widget.onClose();
    then();
  }

  @override
  Widget build(BuildContext context) {
    final words = L.of(context), a = widget.actions;
    return Semantics(
      key: const ValueKey('menu-panel'),
      container: true,
      explicitChildNodes: true,
      label: words.canvasMenu,
      // The studio under it ignores taps while the menu is open (phone_studio.dart), so a tap on the panel, even while
      // its ground comes up, reaches nothing under it.
      child: AnimatedBuilder(
        animation: _ground,
        builder: (context, child) =>
            ColoredBox(color: PhonePalette.canvas.withValues(alpha: _ground.value), child: child),
        child: FadeTransition(
          opacity: _ease,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.paddingOf(context).bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _MenuRow(name: words.canvasHelp, icon: const tabler.HelpCircle(), onPressed: () => _go(() => a.openLink(helpLink))),
              _MenuRow(name: words.canvasPrivacy, icon: const tabler.ShieldLock(), onPressed: () => _go(() => a.openLink(privacyLink))),
              _MenuRow(name: words.canvasShop, icon: const tabler.BuildingStore(), note: words.canvasShopNote, leaves: true,
                  onPressed: () => _go(() => a.openLink(shopLink))),
              _MenuRow(name: words.deviceBackupTitle, icon: const tabler.DatabaseExport(), note: words.canvasBackupNote,
                  onPressed: () => _go(a.openBackup)),
              if (widget.onLevel case final level?) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(words.canvasLevelEyebrow.toUpperCase(), semanticsLabel: words.canvasLevelEyebrow,
                      style: pText(PType.eyebrow, color: PhonePalette.text2)),
                ),
                for (final on in [false, true])
                  _ChoiceRow(key: ValueKey(on ? 'level-patchworker' : 'level-beginner'),
                      name: on ? words.canvasLevelPatchworker : words.canvasLevelBeginner,
                      chosen: widget.patchworker == on, onPressed: () => _go(() => level(on))),
              ],
              if (widget.space case final db?) _SpaceRow(db: db, onFree: () => _go(widget.onFreeSpace ?? () {})),
            ]),
          ),
        ),
      ),
    );
  }
}

/* One row: its icon and name in the card-label role, its note under it in fine print and text2, 16 px in, at least 48
   tall. `leaves`: it goes to another site, and says so with ↗ after its name. */
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.name, required this.icon, this.note, this.leaves = false, required this.onPressed});
  final String name;
  final tabler.Icon icon;
  final String? note;
  final bool leaves;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
        label: note == null ? name : '$name\n$note',
        excludeChildSemantics: true,
        onPressed: onPressed,
        builder: (context, st) => focusRing(st.focused, Container(
          constraints: const BoxConstraints(minHeight: 48),
          color: st.hovered ? PhonePalette.hover : const Color(0x00000000),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            leadIcon(icon, PType.cardLabel),
            Flexible(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(name, style: pText(PType.cardLabel))),
                if (leaves) ...[
                  const SizedBox(width: 8),
                  tablerIcon(const tabler.ArrowUpRight(), size: 16),
                ],
              ]),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(note!, style: pText(PType.finePrint, color: PhonePalette.text2)),
              ],
            ])),
          ]),
        )),
      );
}

/* One of the choices under "I am a…": a check before the one chosen (room kept for it before the other), its name in
   the card-label role, 16 px in, at least 48 tall. */
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({super.key, required this.name, required this.chosen, required this.onPressed});
  final String name;
  final bool chosen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
        label: name,
        selected: chosen,
        excludeChildSemantics: true,
        onPressed: onPressed,
        builder: (context, st) => focusRing(st.focused, Container(
          constraints: const BoxConstraints(minHeight: 48),
          color: st.hovered ? PhonePalette.hover : const Color(0x00000000),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            SizedBox.square(dimension: roleIconSize(PType.cardLabel),
                child: chosen ? roleIcon(const tabler.Check(), PType.cardLabel, color: PhonePalette.blue) : null),
            const SizedBox(width: iconGap),
            Flexible(child: Text(name, style: pText(PType.cardLabel))),
          ]),
        )),
      );
}

/* Megabytes as she reads them on a phone's storage screen (1 MB is 1,000,000 bytes): one decimal under 10, whole
   above. */
String megabytes(int bytes) {
  final mb = bytes / 1000000;
  return mb < 10 ? mb.toStringAsFixed(1) : mb.round().toString();
}

/* "Kantha is using 18 MB on this device", read when the menu opens (KanthaDatabase.space), and Free up space beside it
   when the database offers it. Nothing until the size is read, or if it cannot be. */
class _SpaceRow extends StatefulWidget {
  const _SpaceRow({required this.db, required this.onFree});
  final KanthaDatabase db;
  final VoidCallback onFree;
  @override
  State<_SpaceRow> createState() => _SpaceRowState();
}

class _SpaceRowState extends State<_SpaceRow> {
  late final _space = widget.db.space();

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _space,
        builder: (context, got) {
          final space = got.data;
          if (space == null) return const SizedBox.shrink();
          final words = L.of(context);
          return Container(
            key: const ValueKey('menu-space'),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(children: [
              Padding(padding: const EdgeInsets.only(right: iconGap), child: roleIcon(const tabler.Database(), PType.cardLabel)),
              Expanded(child: Text(words.deviceSpaceUsed(megabytes(space.bytes)),
                  style: pText(PType.metadata, color: PhonePalette.text2))),
              if (space.mayFree)
                KeyedSubtree(key: const ValueKey('free-space'),
                    child: PhoneButton(text: words.deviceFreeSpace, kind: PhoneButtonKind.text, onPressed: widget.onFree)),
            ]),
          );
        },
      );
}
