import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/studio/phone/phone_studio.dart' show dockPanelHeight;
import '../../support/fonts.dart';
import '../../support/pump.dart';

/* Its own file: the faces, once loaded, stay loaded for every test after in the same file. */
void main() {
  // On the web Geist comes after the first frame: Rows and Columns are measured again, and the panel follows.
  testWidgets('a font that comes after the first frame sizes the panel again', (tester) async {
    await pumpStudio(tester, size: phone);
    expect(tester.getSize(key('dock-panel')).height, dockPanelHeight + 96, reason: 'the test font: Rows over Columns');
    await tester.runAsync(loadFonts);
    await tester.pumpAndSettle();
    expect(tester.getSize(key('dock-panel')).height, dockPanelHeight + 52, reason: 'Geist: one line');
  });
}
