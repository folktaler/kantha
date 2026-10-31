import 'dart:async';
import 'package:flutter/widgets.dart';
import 'phone_theme.dart';

/* One toast at a time: `say` replaces what is showing and restarts the 2.8 s. Work that ends after the app has gone
   (a box being made, a backup) may still say something; once disposed, the toaster does nothing. */
class Toaster extends ChangeNotifier {
  static const showFor = Duration(milliseconds: 2800);
  String? _text;
  Timer? _timer;
  bool _disposed = false;
  /* sayWhole's toast, until it goes: true only if it ran its whole time in sight; false if it was cleared, replaced,
     or covered for any of that time. */
  Completer<bool>? _whole;
  bool _covered = false, _missed = false;
  final _idle = <Completer<void>>[];

  String? get text => _text;

  void say(String text) {
    if (_disposed) return;
    _ended(false);
    _timer?.cancel();
    _text = text;
    _missed = _covered;
    _timer = Timer(showFor, _expire);
    notifyListeners();
  }

  /* Whether the toast can be seen, as its host is drawn (ToastHost): not under the open menu or a sheet. */
  void seen(bool visible) {
    _covered = !visible;
    if (_covered && _text != null) _missed = true;
  }

  /* The toast's time is up: whole, unless it was covered at any point. */
  void _expire() {
    final whole = !_missed;
    _ended(whole);
    clear();
  }

  /* `say`, and whether she had the whole of it: false if it was cleared, replaced or covered first. */
  Future<bool> sayWhole(String text) {
    if (_disposed) return Future.value(false);
    say(text);
    return (_whole = Completer<bool>()).future;
  }

  /* When nothing is showing. */
  Future<void> idle() {
    if (_text == null || _disposed) return Future.value();
    final c = Completer<void>();
    _idle.add(c);
    return c.future;
  }

  void _ended(bool whole) {
    final w = _whole;
    _whole = null;
    if (w != null && !w.isCompleted) w.complete(whole);
  }

  void clear() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    if (_text == null) return;
    _text = null;
    _ended(false);
    for (final c in _idle) { c.complete(); }
    _idle.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _ended(false);
    for (final c in _idle) { c.complete(); }
    _idle.clear();
    super.dispose();
  }
}

/* Draws the toaster's text 16 px from each side and `bottom` px from the foot (14 px over the dock on the studio):
   dark ground, white 14/18, padding 12 16, the floating shadow. A screen reader hears it as it appears. */
class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.toaster, required this.bottom, required this.child, this.hidden = false});
  final Toaster toaster;
  final double bottom;
  final Widget child;

  /* True while something covers the toast's screen, here the open menu (PhoneStudio); a sheet over the screen is seen
     through its route. */
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final visible = !hidden && (ModalRoute.of(context)?.isCurrent ?? true);
    return ListenableBuilder(
      listenable: toaster,
      builder: (context, child) {
        toaster.seen(visible);
        final text = toaster.text;
        return Stack(children: [
          child!,
          if (text != null)
            Positioned(
              left: 16, right: 16, bottom: bottom,
              child: Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('phone-toast'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(color: PhonePalette.dark,
                      boxShadow: [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 2), blurRadius: 6)]),
                  child: Text(text, style: pText(PType.bodySmall, color: PhonePalette.white)),
                ),
              ),
            ),
        ]);
      },
      child: child,
    );
  }
}
