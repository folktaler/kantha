/* The dock's sideways strips with a mouse (2026-10-11 one-screen spec, decision 5): the pattern strip and the swatch
   row. A mouse drags one along as a finger does, and the wheel turned over one moves it along rather
   than what is behind it. No bar is drawn under them. */
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/* `child` in the strip's own horizontal scroll view (`scrollKey` on it, `padding` inside it), which every pointer
   drags, a mouse among them, with no scroll bar. A turn of the wheel down moves it along to the right, up to the left.
   At its end the turn is not the strip's, and goes to what is behind it, as a browser passes a scroll on. */
class Strip extends StatefulWidget {
  const Strip({super.key, this.scrollKey, this.padding = EdgeInsets.zero, required this.child});
  final Key? scrollKey;
  final EdgeInsets padding;
  final Widget child;

  @override
  State<Strip> createState() => _StripState();
}

class _StripState extends State<Strip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /* Whether a vertical turn of `dy` would move the strip. */
  bool _moves(double dy) {
    if (dy == 0 || !_controller.hasClients) return false;
    final p = _controller.position;
    return (p.pixels + dy).clamp(p.minScrollExtent, p.maxScrollExtent) != p.pixels;
  }

  /* The strip claims the turn before anything behind it can: the first to register with the resolver has it. */
  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_moves(event.scrollDelta.dy)) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      if (!_moves(dy)) return;
      // It stops at the strip's ends.
      _controller.position.pointerScroll(dy);
      // In a browser, the page under the studio does not scroll too.
      e.respond(allowPlatformDefault: false);
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerSignal: _wheel,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false, dragDevices: PointerDeviceKind.values.toSet()),
          child: SingleChildScrollView(
            key: widget.scrollKey,
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      );
}
