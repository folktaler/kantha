import 'package:flutter/material.dart';
import 'studio/phone/phone_theme.dart' show pText, PType;

/* The studio's type, from the constituition design system (Penpot "Constituition UI/UX", Final 1.1.0, token
   constituition.font.sans and .serif): Geist for everything, Newsreader for a sheet's title and the design's name. Both
   bundled. Malayalam falls back to Noto Sans Malayalam. */
const kPhoneFont = 'Geist', kSerifFont = 'Newsreader';
const kFallbackFonts = ['Noto Sans Malayalam'];

/* The studio's colours, from the same file's FINAL token sets, Light theme. The action colour is kantha's own
   (#33507F, darker #27406A), where the design system has its election ink. The names are the ones the studio has
   always used. The cloth, the board, the mounts and the files she shares keep their own, in their own files. */
abstract final class PhonePalette {
  // constituition.text.default (#211E1C), constituition.text.muted (#584F4B).
  static const text = Color(0xFF211E1C), text2 = Color(0xFF584F4B);
  // kantha's accent in the action.primary and action.hover roles; tint is kantha's own pale accent, in the
  // design system's selected-field role.
  static const blue = Color(0xFF33507F), blueDark = Color(0xFF27406A), tint = Color(0xFFE4EAF3);
  // canvas: constituition.surface.main (paper 3). white: constituition.surface.page (paper 1).
  // hover: constituition.color.alpha.ink-10 (the tertiary button's ground) laid over paper 1, made solid so it reads
  // the same on any ground.
  static const canvas = Color(0xFFF3EFE7), white = Color(0xFFFCFBF8), hover = Color(0xFFE6E5E2);
  // border: constituition.rule.hairline (paper 8). divider: constituition.divider.muted (ink at 15 %).
  // strong: constituition.border.muted, the edge of a field or an outline button. dark: constituition.surface.inverse.
  static const border = Color(0xFFD2CABC), divider = Color(0x26211E1C), strong = Color(0xFF6E635E), dark = Color(0xFF211E1C);
  // red: constituition.text.danger. The design system has no darker red and no pale red: redDark is the studio's own;
  // redTint is that red at 5 % over paper 1 (red words on it 4.63:1).
  static const red = Color(0xFFDA0810), redDark = Color(0xFFB81921), redTint = Color(0xFFFAEFEC);
  // note: constituition.surface.summary (paper 5), the ground of a note such as what was just added (ink on it 12.73:1).
  static const note = Color(0xFFE7E1D5);
  // disabled: a disabled filled button's ground, constituition.color.paper.6 (text2 on it 5.72:1). A disabled control's
  // words, icon or edge are strong (5.62:1 on paper 1).
  static const disabled = Color(0xFFE0DACC);
  // Under a sheet: the ink at 60 %.
  static const scrim = Color(0x99211E1C);
}

/* constituition.radius.control: buttons, cards, fields, dialogs and sheets. */
const kControlRadius = BorderRadius.all(Radius.circular(2));

/* The widest the studio is drawn; every sheet is capped to the same. */
const studioColumnWidth = 600.0;

/* One theme for all three platforms. The fonts are bundled, so the web build never asks Google's servers for one.
   A dialog is paper with 2 px corners (constituition.radius.control), its words the body-small role, its answers 48 px
   tall and in the action colour; a tooltip is paper words in the fine-print role on the ink, 8 12 round it, shown under
   a mouse only. */
ThemeData kanthaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    // The same sizes on every screen: no tighter fields and menus on a desktop.
    visualDensity: VisualDensity.standard,
    fontFamily: kPhoneFont,
    fontFamilyFallback: kFallbackFonts,
    scaffoldBackgroundColor: PhonePalette.canvas,
    colorScheme: ColorScheme.fromSeed(seedColor: PhonePalette.blue, primary: PhonePalette.blue,
        onPrimary: PhonePalette.white, surface: PhonePalette.white, onSurface: PhonePalette.text, error: PhonePalette.red),
    dialogTheme: DialogThemeData(backgroundColor: PhonePalette.white, shape: const RoundedRectangleBorder(borderRadius: kControlRadius),
        contentTextStyle: pText(PType.bodySmall)),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(64, 48),
        foregroundColor: PhonePalette.blue, textStyle: pText(PType.control), shape: const RoundedRectangleBorder(borderRadius: kControlRadius))),
    tooltipTheme: TooltipThemeData(decoration: const BoxDecoration(color: PhonePalette.dark, borderRadius: kControlRadius),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // Under a mouse only: a finger held on a button is a press, not a request for its name.
        triggerMode: TooltipTriggerMode.manual, enableFeedback: false,
        textStyle: pText(PType.finePrint, color: PhonePalette.white)),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: kPhoneFont, fontFamilyFallback: kFallbackFonts,
        bodyColor: PhonePalette.text, displayColor: PhonePalette.text),
  );
}
