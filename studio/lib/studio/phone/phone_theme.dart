import 'package:flutter/widgets.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../theme.dart';

export '../../theme.dart' show PhonePalette, kPhoneFont, kSerifFont, kControlRadius, studioColumnWidth;

/* A type role from the constituition design system (Penpot "Constituition UI/UX", Final 1.1.0, FINAL · Semantics,
   constituition.type.<role>.390): size in px, weight, line height as a multiple of the size, letter spacing in px.
   The studio is one phone-wide column at every width, so it takes the 390 px values. */
class PType {
  const PType(this.size, this.weight, this.height, {this.tracking = 0, this.serif = false});
  final double size, height, tracking;
  final FontWeight weight;
  final bool serif;

  /* A sheet's title and the design's name: section-title, Newsreader 400. */
  static const sectionTitle = PType(25.13, FontWeight.w400, 1.146, serif: true);
  static const bodySmall = PType(15.81, FontWeight.w400, 1.417);
  static const cardLabel = PType(15.81, FontWeight.w500, 1.417);
  static const labelStrong = PType(15.81, FontWeight.w600, 1.417);
  static const metadata = PType(14.83, FontWeight.w400, 1.417);
  static const navigation = PType(14.83, FontWeight.w500, 1.417);
  static const finePrint = PType(13.83, FontWeight.w400, 1.417);
  /* Upper case, which the caller sets on its words. */
  static const eyebrow = PType(13.83, FontWeight.w500, 1.417, tracking: 1.38);
  /* A button's words: control-medium. */
  static const control = PType(15.81, FontWeight.w500, 1.012);
  /* A stepper's − and +: control-large. */
  static const controlLarge = PType(17.78, FontWeight.w500, 1.012);
  /* A pattern's name under its icon: the tag role's size and weight, on the control line height so two lines fit the
     tile. */
  static const tile = PType(13.83, FontWeight.w500, 1.012);
  static const field = PType(17.78, FontWeight.w400, 1.2);
  /* The 4 cm written on the board's dimension line: the board's own size, not a design-system role, as the board keeps
     its own colours. */
  static const dimension = PType(10, FontWeight.w500, 1.55);
}

/* `role` in `color`; `figures` is tabular. */
TextStyle pText(PType role, {Color color = PhonePalette.text, bool figures = false}) =>
    TextStyle(fontFamily: role.serif ? kSerifFont : kPhoneFont, fontFamilyFallback: kFallbackFonts, fontSize: role.size,
        fontWeight: role.weight, color: color, height: role.height, letterSpacing: role.tracking,
        fontFeatures: figures ? const [FontFeature.tabularFigures()] : null);

/* A Tabler outline icon in a box `size` px square, in `color`, its stroke in the icon's own 24-unit grid. It draws
   nothing a screen reader needs: beside a word the word names it, and an icon-only button carries its own label. */
Widget tablerIcon(tabler.Icon icon, {required double size, Color color = PhonePalette.text, double stroke = 2}) =>
    ExcludeSemantics(child: tabler.IconTheme(
        data: tabler.IconThemeData(width: size, height: size, color: color, strokeWidth: stroke), child: icon));

/* A Tabler icon beside a word in `role`, in the word's colour: 1.4 × the role's cap height (Geist's is 0.71 em,
   Newsreader's 0.67 em), its stroke 2 beside words at 500 and over and 1.75 beside 400, to match Geist's weight. */
Widget roleIcon(tabler.Icon icon, PType role, {Color color = PhonePalette.text}) =>
    tablerIcon(icon, size: roleIconSize(role), color: color, stroke: role.weight.value >= 500 ? 2 : 1.75);

double roleIconSize(PType role) => role.size * (role.serif ? 0.67 : 0.71) * 1.4;

/* The room between an icon and its word. */
const iconGap = 6.0;

/* `icon` (or `busy`, drawn in its place) before a block of lines whose first is in `role`: centred on that first line,
   so a note under the name lines up with the name, not the icon. */
Widget leadIcon(tabler.Icon icon, PType role, {Widget? busy}) => Padding(
    padding: EdgeInsets.only(top: (role.size * role.height - roleIconSize(role)) / 2, right: iconGap),
    child: SizedBox.square(dimension: roleIconSize(role), child: busy ?? roleIcon(icon, role)));
