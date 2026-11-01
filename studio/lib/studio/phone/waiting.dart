/* Waiting, by Nielsen's response-time limits (1993), which Material Design also uses (owner, 1 November 2026):
   - under 1 s, nothing;
   - 1 to 10 s, a turning ring and words saying what is happening;
   - over 10 s, or a wait whose steps say it will be, a bar that fills, the step, and Stop where it can stop.
   Flutter's own indicators in PhonePalette, on the studio's own note card; no new style. Nothing shows until the wait
   has passed waitShows, so a quick one shows nothing. With reduced motion the ring stands still, as the share sheet's
   busy icon does, and the bar only moves as the steps do. */
import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'phone_sheet.dart' show PhoneButton, PhoneButtonKind;
import 'phone_theme.dart';

const waitShows = Duration(seconds: 1), waitIsLong = Duration(seconds: 10);

/* `child` once `delay` has passed since this was first built in its place; nothing before. */
class ShowAfter extends StatefulWidget {
  const ShowAfter({super.key, this.delay = waitShows, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<ShowAfter> createState() => _ShowAfterState();
}

class _ShowAfterState extends State<ShowAfter> {
  late bool _shown = widget.delay == Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!_shown) _timer = Timer(widget.delay, () { if (mounted) setState(() => _shown = true); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _shown ? widget.child : const SizedBox.shrink();
}

/* Flutter's CircularProgressIndicator, `size` px, stroke 2, once the wait has passed `delay`: three quarters drawn,
   turning an eighth each `turnEvery`. With reduced motion it stands still. */
class WaitRing extends StatelessWidget {
  const WaitRing({super.key, this.size = 16, this.color = PhonePalette.blue, this.delay = waitShows});
  final double size;
  final Color color;
  final Duration delay;

  /* 8 frames a second, not the screen's 60. On the web every frame is the page's own work, so Material's ring, drawn
     each frame, took the main thread from a wait whose work is there too: opening a backup at 20x CPU took 19 s with
     it, 5 s at 8 frames a second, 3.4 s with no ring (1 November 2026). */
  static const turnEvery = Duration(milliseconds: 125);

  @override
  Widget build(BuildContext context) {
    final ring = CircularProgressIndicator(strokeWidth: 2, color: color, value: 0.75);
    return SizedBox.square(
      dimension: size,
      // Its own layer: each turn repaints the ring alone, not the studio under it.
      child: RepaintBoundary(child: ShowAfter(delay: delay,
          child: MediaQuery.disableAnimationsOf(context) ? ring : _Turning(child: ring))),
    );
  }
}

class _Turning extends StatefulWidget {
  const _Turning({required this.child});
  final Widget child;

  @override
  State<_Turning> createState() => _TurningState();
}

class _TurningState extends State<_Turning> {
  late final Timer _timer;
  var _eighths = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(WaitRing.turnEvery, (_) {
      if (mounted) setState(() => _eighths = (_eighths + 1) % 8);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Transform.rotate(angle: _eighths * pi / 4, child: widget.child);
}

/* The note a wait shows, on the studio's note card (white, a 1 px border, 16 12; Add pieces' "Finding the pieces…"):
   after waitShows, the ring and `words`; once the wait is long (waitIsLong gone by, or its steps so far say it will
   take that long), `words` over a bar that fills by `step`, the step in `stepWords`, and `stopWords` to stop it, when
   it can stop. Built afresh for each wait (give each its own key): its clock starts when it is first built. A screen
   reader hears it as it changes. */
class WaitNote extends StatefulWidget {
  const WaitNote({super.key, required this.words, this.step, this.stepWords, this.onStop, this.stopWords});
  final String words;
  final ({int done, int of})? step;
  final String Function(int done, int of)? stepWords;
  final VoidCallback? onStop;
  final String? stopWords;

  @override
  State<WaitNote> createState() => _WaitNoteState();
}

class _WaitNoteState extends State<WaitNote> {
  static const _tick = Duration(milliseconds: 250);
  late final Timer _timer;
  var _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // A tick, not a clock: a test's fake time moves it as the studio's timers move.
    _timer = Timer.periodic(_tick, (_) {
      final was = (_shows, _long);
      _elapsed += _tick;
      if (was != (_shows, _long) && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  bool get _shows => _elapsed >= waitShows;

  /* Long: 10 s gone by, or the steps done so far say the whole will pass 10 s. */
  bool get _long {
    if (_elapsed >= waitIsLong) return true;
    final s = widget.step;
    return s != null && s.done > 0 && _elapsed * s.of ~/ s.done >= waitIsLong;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shows) return const SizedBox.shrink();
    final step = widget.step, long = _long;
    final card = long
        ? Column(key: const ValueKey('wait-long'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.words, style: pText(PType.cardLabel)),
            const SizedBox(height: 10),
            if (step != null || !MediaQuery.disableAnimationsOf(context)) RepaintBoundary(child: LinearProgressIndicator(
              value: step == null ? null : step.done / step.of,
              minHeight: 4,
              color: PhonePalette.blue,
              backgroundColor: PhonePalette.border,
            )),
            if (step != null && widget.stepWords != null) ...[
              const SizedBox(height: 6),
              Text(widget.stepWords!(step.done, step.of), style: pText(PType.finePrint, color: PhonePalette.text2)),
            ],
            if (widget.onStop != null && widget.stopWords != null) ...[
              const SizedBox(height: 4),
              Align(alignment: AlignmentDirectional.centerEnd,
                  child: PhoneButton(key: const ValueKey('wait-stop'), text: widget.stopWords!, kind: PhoneButtonKind.text,
                      onPressed: widget.onStop)),
            ],
          ])
        : Row(key: const ValueKey('wait-short'), mainAxisSize: MainAxisSize.min, children: [
            const WaitRing(delay: Duration.zero),
            const SizedBox(width: 10),
            Flexible(child: Text(widget.words, style: pText(PType.cardLabel))),
          ]);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('wait-note'),
        constraints: BoxConstraints(maxWidth: long ? 320 : double.infinity),
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.fromLTRB(16, 12, 16, long && widget.onStop != null ? 4 : 12),
        decoration: BoxDecoration(color: PhonePalette.white, border: Border.all(color: PhonePalette.border)),
        child: card,
      ),
    );
  }
}
