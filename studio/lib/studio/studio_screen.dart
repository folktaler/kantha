/* The studio: one screen at every width (2026-10-11 one-screen spec, decisions 1 and 2). The phone studio sits in a
   column at most 600 wide, centred; outside it, the canvas colour, and a 1 px line down each side of the column (owner,
   21 Oct). Below 600 the column is the window, with no lines. */
import 'package:flutter/material.dart';
import 'controller.dart';
import 'shelf_feed.dart' show PictureView;
import 'phone/phone_studio.dart';
import 'phone/phone_theme.dart';
import 'phone/phone_toast.dart';

/* Where the studio's buttons lead. */
class StudioActions {
  const StudioActions({required this.openTakeAway, required this.openCloth, required this.openBoxes,
      required this.deleteBox, required this.openBackup, required this.openLink, required this.openDesigns,
      required this.openPicture});
  /* The Share sheet for a saved design. */
  final void Function(String designId) openTakeAway;
  /* Add a piece or Fix this cloth, as a sheet. */
  final void Function(ClothOpen open) openCloth;
  /* Your boxes, as a sheet. */
  final void Function() openBoxes;
  /* A box, asked about first and then gone with its pieces: true once it has gone. */
  final Future<bool> Function(int box) deleteBox;
  /* The Back up sheet. */
  final void Function() openBackup;
  final void Function(Uri) openLink;
  /* My designs, as a sheet. */
  final void Function() openDesigns;
  /* View: a saved picture, with Save photo and Share…, as a sheet over the one asking. */
  final void Function(BuildContext over, PictureView picture) openPicture;
}

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key, required this.controller, required this.actions, required this.toaster,
      this.safariOnIphone = false});
  final StudioController controller;
  final StudioActions actions;
  /* The studio's toasts (the app's own, so they outlive a rebuild of the screen). */
  final Toaster toaster;
  /* Safari on an iPhone: the 7-day rule is said under the top bar until she dismisses it. */
  final bool safariOnIphone;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: PhonePalette.canvas,
        child: LayoutBuilder(
          builder: (context, box) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: studioColumnWidth),
              // On a window wider than the column, a 1 px line down each side of it, over its edge. The box stays at
              // every width, so crossing 600 keeps the studio's state.
              child: DecoratedBox(
                key: const ValueKey('studio-column'),
                position: DecorationPosition.foreground,
                decoration: box.maxWidth > studioColumnWidth
                    ? const BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: PhonePalette.border)))
                    : const BoxDecoration(),
                child: Material(child: PhoneStudio(controller: controller, actions: actions, toaster: toaster,
                    safariOnIphone: safariOnIphone)),
              ),
            ),
          ),
        ),
      );
}
