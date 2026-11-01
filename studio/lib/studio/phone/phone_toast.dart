import 'dart:async';
import 'package:flutter/widgets.dart';
import 'phone_theme.dart';
import 'waiting.dart';

/* One toast at a time: `say` replaces what is showing and restarts the 2.8 s. Work that ends after the app has gone
   (a box being made, a backup) may still say something; once disposed, the toaster does nothing. `wait` says work is
   under way: past waitShows, its words with a ring, until `say` or `clear` (owner, 1 November 2026). */
class Toaster extends ChangeNotifier {
  static const showFor = Duration(milliseconds: 2800);
  String? _text;
  Timer? _timer;
  bool _disposed = false, _waiting = false;

  String? get text => _text;
  /* The toast is a wait's: it stays up, with a ring, until what it waits for says how it went. */
  bool get waiting => _waiting;

  void say(String text) {
    if (_disposed) return;
    _timer?.cancel();
    _text = text;
    _waiting = false;
    _timer = Timer(showFor, clear);
    notifyListeners();
  }

  /* What is under way: nothing for waitShows, so a quick one shows nothing; then `text` and a ring until `say` or
     `clear`. A toast showing goes at once. */
  void wait(String text) {
    if (_disposed) return;
    clear();
    _timer = Timer(waitShows, () {
      _timer = null;
      _text = text;
      _waiting = true;
      notifyListeners();
    });
  }

  void clear() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _waiting = false;
    if (_text == null) return;
    _text = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/* Draws the toaster's text 16 px from each side and `bottom` px from the foot (14 px over the dock on the studio):
   dark ground, white 14/18, padding 12 16, the floating shadow. A screen reader hears it as it appears. */
class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.toaster, required this.bottom, required this.child});
  final Toaster toaster;
  final double bottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: toaster,
      builder: (context, child) {
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
                  child: toaster.waiting
                      ? Row(children: [
                          const WaitRing(color: PhonePalette.white, delay: Duration.zero),
                          const SizedBox(width: 10),
                          Expanded(child: Text(text, style: pText(PType.bodySmall, color: PhonePalette.white))),
                        ])
                      : Text(text, style: pText(PType.bodySmall, color: PhonePalette.white)),
                ),
              ),
            ),
        ]);
      },
      child: child,
    );
  }
}
