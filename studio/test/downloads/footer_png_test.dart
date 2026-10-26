import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/downloads/footer_png.dart';

void main() {
  testWidgets("a long name's footer is never wider than the grid", (tester) async {
    final png = await tester.runAsync(() => footerPng('${'A very long name for a design ' * 12}· made with kantha.app'));
    expect(img.decodePng(png!)!.width, lessThanOrEqualTo(footerMaxWidth.ceil()));
  });
}
