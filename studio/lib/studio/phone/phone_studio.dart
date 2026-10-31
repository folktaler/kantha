/* The studio (redesign handover, Screen: Studio), at every width in its column (2026-10-11 one-screen spec): the top
   bar, the board across the whole width on its canvas, and at the foot the dock — its panel over its three tabs. In
   Safari on an iPhone a banner under the top bar says the 7-day rule until she dismisses it (owner, 11 Oct). What the
   controller says comes up as a toast over the dock (decision 10). */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../l10n/app_localizations.dart';
import '../../solver/geometry.dart' show Mount;
import '../board.dart';
import '../controller.dart';
import '../pressable.dart';
import '../studio_screen.dart';
import 'dock_cloth.dart';
import 'dock_finish.dart';
import 'dock_patterns.dart';
import 'menu_panel.dart';
import 'phone_sheet.dart';
import 'phone_theme.dart';
import 'phone_toast.dart';
import 'shortfall_banner.dart';
import '../../platform/report.dart';

/* The dock's tabs, left to right: Cloth box · Design · Preview (owner, 19 Oct). Design is the patterns, Preview the
   finish. */
enum DockTab { cloth, patterns, finish }

/* The dock's fixed heights; the toast stands 14 px over them and the home indicator. The panel is the Design tab's
   height at normal text size (8 + the 124 px tiles + 4 + the 44 px Show stitches row, owner 21 Oct), on every tab,
   so the board keeps its size from tab to tab. */
const dockPanelHeight = 180.0, dockTabsHeight = 48.0, toastGap = 14.0;
/* A Patchworker's panel is taller by her Rows and Columns, on every tab, so the board keeps its size from tab to tab and
   both are in sight without scrolling: one row of 52 px where the column is `boardSizeOneRow` wide or more, else Rows
   over Columns, 96 px. */
const boardSizeOneRow = 400.0;
double dockPanelFor(StudioController c, double width) =>
    dockPanelHeight + (!c.patchworker ? 0 : width >= boardSizeOneRow ? 52 : 96);

/* A 1 px line along one edge, drawn over the box rather than taking room in it. */
BoxDecoration _edge({bool top = false}) => BoxDecoration(
    border: top ? const Border(top: BorderSide(color: PhonePalette.border)) : const Border(bottom: BorderSide(color: PhonePalette.border)));

class PhoneStudio extends StatefulWidget {
  const PhoneStudio({super.key, required this.controller, required this.actions, required this.toaster,
      this.safariOnIphone = false});
  final StudioController controller;
  final StudioActions actions;
  final Toaster toaster;
  /* Safari on an iPhone, not opened from the Home Screen (lib/platform/browser.dart). */
  final bool safariOnIphone;

  /* The setting that says she dismissed the Safari banner in this browser: when, as an ISO time. */
  static const safariSeenKey = 'safariBannerSeen';

  @override
  State<PhoneStudio> createState() => _PhoneStudioState();
}

class _PhoneStudioState extends State<PhoneStudio> {
  StudioController get c => widget.controller;
  DockTab _tab = DockTab.patterns;
  /* Each part's Tab order, made once rather than on every build. The studio's: ≡, then the open menu's rows, then the
     rest top to bottom. */
  final _studioOrder = OrderedTraversalPolicy(), _topOrder = ReadingOrderTraversalPolicy(),
      _canvasOrder = ReadingOrderTraversalPolicy(), _panelOrder = ReadingOrderTraversalPolicy(),
      _tabsOrder = ReadingOrderTraversalPolicy();
  late int _notes;
  Size? _pane;
  Mount? _paneMount;
  bool _safari = false;
  /* The Menu, open over everything under the top bar (menu_panel.dart). */
  bool _menu = false;
  final _menuFocus = FocusNode(debugLabel: 'menu');

  @override
  void initState() {
    super.initState();
    // Counted now, so the first note after the studio is built is said.
    _notes = c.notes;
    c.addListener(_heard);
    if (widget.safariOnIphone) _askSafariSeen();
  }

  /* The Safari banner comes up once the shelf says she has not dismissed it here. A setting that cannot be read leaves it
     up: the rule said again is the safe way to be wrong. */
  Future<void> _askSafariSeen() async {
    String? seen;
    try {
      seen = await c.shelf.setting(PhoneStudio.safariSeenKey);
    } on Object {
      seen = null;
    }
    if (mounted && seen == null) setState(() => _safari = true);
  }

  /* ✕: gone now, and remembered for this browser. */
  Future<void> _dismissSafari() async {
    setState(() => _safari = false);
    try {
      await c.shelf.setSetting(PhoneStudio.safariSeenKey, DateTime.now().toUtc().toIso8601String());
    } on Object {
      // Not remembered: the next visit says it again.
    }
  }

  @override
  void didUpdateWidget(PhoneStudio old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      old.controller.removeListener(_heard);
      c.addListener(_heard);
      _notes = c.notes;
    }
  }

  @override
  void dispose() {
    c.removeListener(_heard);
    HardwareKeyboard.instance.removeHandler(_escape);
    _menuFocus.dispose();
    super.dispose();
  }

  void _openMenu() {
    setState(() => _menu = true);
    HardwareKeyboard.instance.addHandler(_escape);
  }

  /* While the menu is open Escape shuts it, wherever focus is; while it is shut Escape is not handled here, so it
     reaches whatever else listens for it. */
  bool _escape(KeyEvent e) {
    if (!_menu || e.logicalKey != LogicalKeyboardKey.escape) return false;
    if (e is KeyDownEvent) _closeMenu();
    return true;
  }

  /* Shut at once; focus goes back to ≡, as the menu that held it has gone — unless `refocus` is false, when what was
     pressed in the top bar keeps it. */
  void _closeMenu({bool refocus = true}) {
    if (!_menu) return;
    HardwareKeyboard.instance.removeHandler(_escape);
    setState(() => _menu = false);
    if (refocus) _menuFocus.requestFocus();
  }

  /* Anything else in the top bar shuts the menu first, and keeps focus where it was pressed. */
  VoidCallback _shutThen(VoidCallback go) => () { _closeMenu(refocus: false); go(); };

  /* Each note the controller says, said again as a toast; the same words twice are two notes. That a short box cannot
     be arranged is not: the shortfall banner already says what to do. */
  void _heard() {
    if (c.notes == _notes) return;
    _notes = c.notes;
    if (c.note.isEmpty || (c.note == c.cantSolveWords && ShortfallBanner.shows(c))) return;
    widget.toaster.say(c.note);
  }

  /* With nothing on the board: a box short of 35 pieces is told so; while the board is being arranged Save waits; a
     full box that could not be arranged has its note said again. */
  Future<void> _save() async {
    if (c.busy) return;
    if (c.grid != null) {
      await c.save();
      return;
    }
    final b = c.box;
    if (b == null || c.piecesIn(b) < c.squares) {
      final words = L.of(context);
      return widget.toaster.say(c.onA4 ? words.canvasNothingToSave : words.canvasNothingToSaveSize('${c.squares}'));
    }
    if (c.solving) return;
    if (c.note.isNotEmpty) widget.toaster.say(c.note);
  }

  /* Free up space, from the Menu (his decision, 21 Oct): "Freeing space…" stands over the whole studio until the
     database has been written again, so nothing here is pressed or written meanwhile; then a toast says how much was
     freed. If it fails, the file is as it was (KanthaDatabase.freeSpace): the toast says nothing was lost, and the
     studio carries on. */
  Future<void> _freeSpace() async {
    final words = L.of(context), navigator = Navigator.of(context);
    unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const FreeingSpace()));
    String said;
    try {
      final r = await c.shelf.db.freeSpace();
      said = words.deviceSpaceFreed(megabytes((r.before - r.after).clamp(0, r.before)), megabytes(r.after));
    } on Object catch (e, st) {
      reportError(e, st, 'while space was freed');
      said = words.deviceFreeSpaceFailed;
    }
    navigator.pop();
    widget.toaster.say(said);
  }

  /* Saved as it is first, then the Share sheet. */
  Future<void> _takeAway() async {
    final id = await c.takeAwayNow();
    if (id != null && mounted) widget.actions.openTakeAway(id);
  }

  /* The toasts belong to the studio under the menu: while the menu is open it covers them, and a screen reader does not
     hear them. */
  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: c,
      // Tab goes through each part before the next, top to bottom: a square scrolled up under the top bar is still
      // the canvas's, after Share.
      builder: (context, _) => _menuKeys(FocusTraversalGroup(
        policy: _studioOrder,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : menuTurn,
              curve: Curves.fastOutSlowIn,
              color: _menu ? PhonePalette.canvas : PhonePalette.white,
              child: SafeArea(bottom: false, child: _topBar(context))),
          Expanded(child: Stack(fit: StackFit.expand, children: [
            // While the menu is open nothing under it is reached by a tap, Tab or a screen reader: focus stays in the
            // top bar and the menu.
            IgnorePointer(ignoring: _menu, child: ExcludeFocus(excluding: _menu,
                child: ExcludeSemantics(excluding: _menu, child: ToastHost(
                  toaster: widget.toaster,
                  bottom: dockPanelFor(c, MediaQuery.sizeOf(context).width) + dockTabsHeight + inset + toastGap,
                  child: _studio(context),
                )))),
            if (_menu)
              FocusTraversalOrder(order: const NumericFocusOrder(2),
                  child: FocusTraversalGroup(child: MenuPanel(actions: widget.actions, onClose: _closeMenu,
                      space: c.shelf.db.freesSpace ? c.shelf.db : null, onFreeSpace: _freeSpace,
                      patchworker: c.patchworker, onLevel: c.setPatchworker))),
          ])),
        ]),
      )),
    );
  }

  /* While the menu is open Back shuts it (Escape: _escape). The same widgets either way, so nothing under them is built
     afresh. */
  Widget _menuKeys(Widget child) => PopScope(
        canPop: !_menu,
        onPopInvokedWithResult: (didPop, _) { if (!didPop) _closeMenu(); },
        child: child,
      );

  /* Under the top bar: the Safari banner, the canvas, and the dock — its panel over its tabs. */
  Widget _studio(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_safari) _safariBanner(context),
          Expanded(child: FocusTraversalGroup(policy: _canvasOrder, child: _canvas())),
          FocusTraversalGroup(
            policy: _panelOrder,
            child: Container(
              key: const ValueKey('dock-panel'),
              height: dockPanelFor(c, MediaQuery.sizeOf(context).width),
              color: PhonePalette.white,
              foregroundDecoration: _edge(top: true),
              child: switch (_tab) {
                DockTab.patterns => DockPatterns(c: c, toaster: widget.toaster),
                DockTab.cloth => DockCloth(c: c, actions: widget.actions),
                DockTab.finish => DockFinish(c: c),
              },
            ),
          ),
          FocusTraversalGroup(
            policy: _tabsOrder,
            child: Container(
              key: const ValueKey('dock-tabs'),
              height: dockTabsHeight + inset,
              padding: EdgeInsets.only(bottom: inset),
              color: PhonePalette.white,
              foregroundDecoration: _edge(top: true),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final t in DockTab.values) Expanded(child: _tabButton(context, t)),
              ]),
            ),
          ),
        ]);
  }

  /* ≡, the design's name over the whole middle (it opens My designs), Save, Share. */
  Widget _topBar(BuildContext context) {
    final words = L.of(context);
    final ready = c.grid != null && !c.busy;
    return Container(
      key: const ValueKey('phone-topbar'),
      height: 48,
      foregroundDecoration: _edge(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ≡ first in Tab order, and the open menu's rows straight after it; then the title, Save and Share.
        FocusTraversalOrder(order: const NumericFocusOrder(1), child: Pressable(
          key: const ValueKey('phone-menu'),
          focusNode: _menuFocus,
          // Menu while ≡ shows, Close while × does.
          label: _menu ? words.canvasClose : words.canvasMenu,
          // Its name, under a mouse: the icon alone says nothing.
          tooltip: _menu ? words.canvasClose : words.canvasMenu,
          expanded: _menu,
          excludeChildSemantics: true,
          onPressed: _menu ? _closeMenu : _openMenu,
          builder: (context, st) => focusRing(st.focused, SizedBox.square(dimension: 48,
              child: ColoredBox(color: st.hovered ? PhonePalette.hover : const Color(0x00000000),
                  child: Center(child: MenuIcon(open: _menu))))),
        )),
        Expanded(child: FocusTraversalGroup(policy: _topOrder, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Expanded(
              child: Pressable(
                key: const ValueKey('phone-title'),
                label: c.name,
                excludeChildSemantics: true,
                onPressed: _shutThen(widget.actions.openDesigns),
                builder: (context, st) => focusRing(st.focused, ColoredBox(
                  color: st.hovered ? PhonePalette.hover : const Color(0x00000000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    // On a very narrow phone the name keeps the room and the folder icon goes: below 96 px it would
                    // leave the name no more than its ellipsis.
                    child: LayoutBuilder(builder: (context, room) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (room.maxWidth >= 96) ...[
                        roleIcon(const tabler.FolderOpen(), PType.sectionTitle),
                        const SizedBox(width: iconGap),
                      ],
                      Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: pText(PType.sectionTitle))),
                      const SizedBox(width: 4),
                      tablerIcon(const tabler.ChevronDown(), size: 16),
                    ])),
                  ),
                )),
              ),
            ),
            KeyedSubtree(key: const ValueKey('phone-save'),
                child: PhoneButton(text: words.canvasSave, icon: const tabler.DeviceFloppy(), kind: PhoneButtonKind.text,
                    onPressed: _shutThen(_save))),
            KeyedSubtree(key: const ValueKey('phone-export'),
                child: PhoneButton(text: words.canvasShare, icon: const tabler.Share(),
                    onPressed: ready ? _shutThen(_takeAway) : null)),
          ]))),
      ]),
    );
  }

  /* Safari's 7-day rule across the whole width, on the blue tint with a 1 px line under it: the sentence at 13 on the
     left, wrapping, and ✕ on the right. Read as one region named by its sentence, with Close inside it. The canvas below
     loses its height, and the board is fitted again to what is left. */
  Widget _safariBanner(BuildContext context) {
    final words = L.of(context);
    return Semantics(
      container: true,
      liveRegion: false,
      label: words.deviceSafariBanner,
      child: Container(
        key: const ValueKey('safari-banner'),
        color: PhonePalette.tint,
        foregroundDecoration: _edge(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: ExcludeSemantics(child: Text(words.deviceSafariBanner, style: pText(PType.metadata)))),
          Pressable(
            key: const ValueKey('safari-banner-close'),
            label: words.canvasClose,
            excludeChildSemantics: true,
            onPressed: _dismissSafari,
            builder: (context, st) => focusRing(st.focused, SizedBox.square(dimension: 48,
                child: ColoredBox(color: st.hovered ? PhonePalette.hover : const Color(0x00000000),
                    child: Center(child: tablerIcon(const tabler.X(), size: 20))))),
          ),
        ]),
      ),
    );
  }

  /* Add a piece, for the box on the board when it is hers, else for a box her first photo makes. */
  void _addCloth() {
    final box = c.box;
    widget.actions.openCloth(box != null && c.mayEdit ? ClothOpen.add(box) : const ClothOpen.addToNew());
  }

  /* The board, centred while it fits and scrolled both ways when it does not. The fitted scale is worked out after the frame, for the room there is (applyFit). An unfilled box is 35
     dashed squares (decision 14), and the shortfall banner sits at the foot of the canvas, outside the scroll, 16 px in
     from each side; the board is fitted to the room above it, so no row of squares is under it. There is no start
     card (decision 15). */
  Widget _canvas() => ColoredBox(
        key: const ValueKey('phone-canvas'),
        color: PhonePalette.canvas,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final size = box.biggest;
              // A design opened on another mount (openSaved) changes the mount without fitting to it.
              if (size != _pane || c.mount != _paneMount) {
                _pane = size;
                _paneMount = c.mount;
                WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) c.applyFit(size); });
              }
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: size.width, minHeight: size.height),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          // 32 px for the 4 cm line over the sheet.
                          const SizedBox(height: 32),
                          Board(key: const ValueKey('phone-board'), c: c, onEmptyCell: _addCloth),
                        ]),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (ShortfallBanner.shows(c))
            Padding(padding: const EdgeInsets.all(16), child: ShortfallBanner(c: c, onPressed: _addCloth)),
        ]),
      );

  /* A third of the width: 14 px, 600 and a 2 px blue top edge when selected, else 500 in text2. */
  Widget _tabButton(BuildContext context, DockTab t) {
    final words = L.of(context), on = _tab == t;
    final (name, icon) = switch (t) {
      DockTab.cloth => (words.canvasTabCloth, const tabler.Box() as tabler.Icon),
      DockTab.patterns => (words.canvasTabDesign, const tabler.LayoutGrid()),
      DockTab.finish => (words.canvasTabPreview, const tabler.Eye()),
    };
    final colour = on ? PhonePalette.text : PhonePalette.text2;
    return Pressable(
      key: ValueKey('tab-${t.name}'),
      selected: on,
      onPressed: () => setState(() => _tab = t),
      builder: (context, st) => focusRing(st.focused, Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: st.hovered ? PhonePalette.hover : PhonePalette.white,
          border: Border(top: BorderSide(width: 2, color: on ? PhonePalette.blue : const Color(0x00000000))),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          roleIcon(icon, PType.navigation, color: colour),
          const SizedBox(width: iconGap),
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: pText(PType.navigation, color: colour))),
        ]),
      )),
    );
  }
}

/* "Freeing space…" over the whole studio: no tap reaches past it, and Back and Escape do not close it. */
class FreeingSpace extends StatelessWidget {
  const FreeingSpace({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const ValueKey('freeing-space'),
          content: Semantics(liveRegion: true, child: Row(children: [
            const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: PhonePalette.blue)),
            const SizedBox(width: 16),
            Flexible(child: Text(L.of(context).deviceFreeingSpace, style: pText(PType.bodySmall))),
          ])),
        ),
      );
}
