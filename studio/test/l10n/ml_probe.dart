/* Not run as it is: generated_test.dart runs it, as test/l10n/ml_probe_test.dart, in a copy of the studio whose
   messages/ holds test/l10n/ml.json beside en.json. The studio in Malayalam, and English where ml.json has no words. */
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/app.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/studio/studio_screen.dart';
import '../support/pump.dart';

void main() {
  test('a device set to Malayalam gets the Malayalam words, and English where there are none', () {
    final l = wordsForLocales(const [Locale('ml', 'IN'), Locale('en')]);
    expect(l.localeName, 'ml');
    expect(l.canvasSave, 'സേവ് ചെയ്യുക');
    expect(l.canvasDuplicate, 'Duplicate');
  });

  testWidgets('when the device turns to Malayalam, the controller\'s words and Flutter\'s own follow it', (tester) async {
    final c = await pumpStudio(tester);
    tester.platformDispatcher.localesTestValue = const [Locale('ml')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpAndSettle();

    await tester.runAsync(c.save);
    expect(c.note, 'ഈ ഉപകരണത്തിൽ സേവ് ചെയ്തു.');
    final context = tester.element(find.byType(StudioScreen));
    expect(L.of(context).canvasSave, 'സേവ് ചെയ്യുക');
    expect(L.of(context).canvasDuplicate, 'Duplicate');
    final ml = await GlobalMaterialLocalizations.delegate.load(const Locale('ml'));
    expect(MaterialLocalizations.of(context).modalBarrierDismissLabel, ml.modalBarrierDismissLabel);
    expect(ml.modalBarrierDismissLabel, isNot(const DefaultMaterialLocalizations().modalBarrierDismissLabel));
    expect(MaterialLocalizations.of(context).pasteButtonLabel, ml.pasteButtonLabel);
  });
}
