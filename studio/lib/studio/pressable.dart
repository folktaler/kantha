/* A button the caller draws: the caller paints every state
   (hovered, focused from the keyboard, on, disabled); this gives it a button's behaviour —
   Enter and Space press it, a click focuses it as a browser does, and a screen reader
   hears its name, whether it is on, and whether its panel is open. */
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/* Whether the last thing she did was a press of a pointer (a click or a tap) rather than a key.
   Focus that the studio moves itself — to Done as My designs opens, to a menu's first item —
   then shows no ring, as Chrome's :focus-visible does after a click; after a key it shows one. */
abstract final class _LastInput {
  static bool pointer = false;
  /* Listened for while any button is on the screen. */
  static int _buttons = 0;
  static void _down(PointerEvent e) { if (e is PointerDownEvent) pointer = true; }
  static bool _key(KeyEvent _) { pointer = false; return false; }
  static void add() {
    if (_buttons++ > 0) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_down);
    HardwareKeyboard.instance.addHandler(_key);
  }
  static void remove() {
    if (--_buttons > 0) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_down);
    HardwareKeyboard.instance.removeHandler(_key);
  }
}

class PressState {
  const PressState({required this.hovered, required this.focused, required this.enabled});
  final bool hovered, focused, enabled;
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onPressed, required this.builder, this.focusNode, this.label,
      this.tooltip, this.toggled, this.selected, this.expanded, this.excludeChildSemantics = false, this.value});

  final VoidCallback? onPressed;
  final Widget Function(BuildContext context, PressState state) builder;
  final FocusNode? focusNode;
  /* The accessible name, where the button's own text is not it (aria-label). */
  final String? label;
  /* The browser's title: shown on hover, and read as the button's description. */
  final String? tooltip;
  final bool? toggled, expanded;
  /* One choice among several, the one in use (aria-current): a button that says it is chosen, not a switch. */
  final bool? selected;
  final bool excludeChildSemantics;
  /* What it holds now, read after its name: the zoom's percent. */
  final String? value;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());
  bool _hover = false, _focus = false;
  /* Focused by a click or a tap: no ring then, as a browser shows none (:focus-visible). */
  bool _byPointer = false;

  bool get _enabled => widget.onPressed != null;

  /* The web folds a semantics tooltip into the button's name: one that repeats the name, or
     holds it, would have a screen reader say it twice. The aria-label was the name, once;
     the title is still drawn on hover. */
  String? get _spokenTooltip {
    final t = widget.tooltip, l = widget.label;
    if (t == null || l == null) return t;
    return t.contains(l) || l.contains(t) ? null : t;
  }

  @override
  void initState() {
    super.initState();
    _LastInput.add();
  }

  void _press() => widget.onPressed?.call();

  void _tap() {
    // A touch has no pointer to rest on it: the title shown for a press would only linger.
    Tooltip.dismissAllToolTips();
    _byPointer = true;
    _node.requestFocus();
    _press();
  }

  @override
  void dispose() {
    _LastInput.remove();
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget box = widget.builder(context, PressState(hovered: _hover && _enabled, focused: _focus && !_byPointer, enabled: _enabled));
    // The browser's title: after a pause, the theme's dark box, so it does not cover the next button at once.
    if (widget.tooltip != null) {
      box = Tooltip(message: widget.tooltip, excludeFromSemantics: true, waitDuration: const Duration(milliseconds: 500), child: box);
    }
    // A key pressed while it has focus: from then on it was reached from the keyboard, and
    // shows its ring, as :focus-visible does after a key (Escape closing a menu, say).
    return Focus(
      canRequestFocus: false, skipTraversal: true,
      onKeyEvent: (_, _) {
        if (_byPointer) setState(() => _byPointer = false);
        return KeyEventResult.ignored;
      },
      child: _detector(box),
    );
  }

  Widget _detector(Widget box) {
    return FocusableActionDetector(
      focusNode: _node,
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { _press(); return null; })},
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      onFocusChange: (v) => setState(() => _byPointer = v && (_byPointer || _LastInput.pointer)),
      child: Semantics(
        container: true, button: true, enabled: _enabled, toggled: widget.toggled, selected: widget.selected, expanded: widget.expanded,
        label: widget.label, value: widget.value, tooltip: _spokenTooltip, excludeSemantics: widget.excludeChildSemantics,
        onTap: _enabled ? _press : null,
        child: GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: _enabled ? _tap : null, child: box),
      ),
    );
  }
}

/* The focus ring round a button reached from the keyboard, inside its edge: 2 px of paper (constituition.color.paper.1),
   then 2 px of the darker action colour (constituition.border.2, in kantha's focus.ring). One colour cannot stand out
   from both the paper and the action-coloured and ink buttons, so the ring is two, and on any ground one of them does:
   the paper 7.82:1 on the action colour, 16.02:1 on the ink and on a chosen tile's action-coloured edge 7.82:1; the
   darker action colour 10.01:1 on paper 1, 9.03:1 on paper 3, 8.56:1 on the chosen tint and 8.22:1 on the hover ground. */
Widget focusRing(bool on, Widget child) => on
    ? DecoratedBox(position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: Border.all(color: PhonePalette.white, width: 2)),
        child: DecoratedBox(position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: Border.all(color: PhonePalette.blueDark, width: 4)), child: child))
    : child;
