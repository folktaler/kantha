import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/phone/phone_theme.dart';

void main() {
  test('the phone sets its type in Geist, falling back to Noto Sans Malayalam; a title is Newsreader', () {
    expect(pText(PType.bodySmall).fontFamily, 'Geist');
    expect(pText(PType.bodySmall).fontFamilyFallback, ['Noto Sans Malayalam']);
    expect(pText(PType.sectionTitle).fontFamily, 'Newsreader');
  });

  test("a role is the design system's 390 px value: size, weight, line height as a multiple", () {
    final s = pText(PType.sectionTitle);
    expect((s.fontSize, s.fontWeight, s.height), (25.13, FontWeight.w400, 1.146));
    final b = pText(PType.bodySmall);
    expect((b.fontSize, b.fontWeight, b.height), (15.81, FontWeight.w400, 1.417));
  });

  test('an eyebrow is tracked 1.38 px, and a count takes tabular figures', () {
    expect(pText(PType.eyebrow).letterSpacing, 1.38);
    expect(pText(PType.finePrint, figures: true).fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test("the phone colours are the design system's, with kantha's accent for the action", () {
    expect(PhonePalette.blue, const Color(0xFF33507F));
    expect(PhonePalette.text, const Color(0xFF211E1C));
    expect(PhonePalette.canvas, const Color(0xFFF3EFE7));
    expect(PhonePalette.scrim, const Color(0x99211E1C));
  });
}
