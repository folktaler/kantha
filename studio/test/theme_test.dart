import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the type is Geist, falling back to Noto Sans Malayalam, and nothing else', () {
    final t = kanthaTheme();
    expect(t.textTheme.bodyMedium!.fontFamily, 'Geist');
    expect(t.textTheme.bodyMedium!.fontFamilyFallback, ['Noto Sans Malayalam']);
    expect(t.textTheme.labelLarge!.fontFamily, 'Geist', reason: "a button's words");
  });

  test('every font the app names ships inside it', () async {
    for (final f in [
      'PublicSans-Regular', 'PublicSans-Medium', 'PublicSans-SemiBold', 'PublicSans-Bold',
      'NotoSansMalayalam-Regular', 'NotoSansMalayalam-SemiBold', 'NotoSansMalayalam-Bold',
      'Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Newsreader-Regular',
    ]) {
      final data = await rootBundle.load('assets/fonts/$f.ttf');
      expect(data.lengthInBytes, greaterThan(10000), reason: f);
    }
  });

  test('one density on every platform, so a field is the same size on a desktop as on a phone', () {
    expect(kanthaTheme().visualDensity, VisualDensity.standard);
  });

  test("the colours are the constituition design system's, with kantha's accent: the canvas ground, accent buttons, "
      'paper dialogs with 2 px corners', () {
    final t = kanthaTheme();
    expect(t.scaffoldBackgroundColor, PhonePalette.canvas);
    expect((t.colorScheme.primary, t.colorScheme.surface, t.colorScheme.onSurface, t.colorScheme.error),
        (PhonePalette.blue, PhonePalette.white, PhonePalette.text, PhonePalette.red));
    expect(t.dialogTheme.backgroundColor, PhonePalette.white);
    expect(t.dialogTheme.shape, isA<RoundedRectangleBorder>().having((s) => s.borderRadius, 'corners', kControlRadius));
    final answer = t.textButtonTheme.style!;
    expect(answer.minimumSize!.resolve({}), const Size(64, 48));
    expect(answer.foregroundColor!.resolve({}), PhonePalette.blue);
    expect((t.tooltipTheme.decoration as BoxDecoration).color, PhonePalette.dark);
    expect((t.tooltipTheme.textStyle!.fontFamily, t.tooltipTheme.textStyle!.fontSize, t.tooltipTheme.textStyle!.color),
        ('Geist', 13.83, PhonePalette.white));
    expect((t.tooltipTheme.triggerMode, t.tooltipTheme.enableFeedback), (TooltipTriggerMode.manual, false), reason: 'a mouse only');
  });
}
