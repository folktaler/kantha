import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/downloads/caption.dart';
import 'package:kantha_studio/downloads/file_name.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/studio/shelf_feed.dart';

DesignView zinnia() => DesignView(id: 'P-1', name: 'Zinnia', layout: LayoutKey.contrast, mount: Mount.frame, box: 0, seed: 1,
    started: null, firstSolve: null, grid: List.filled(35, 'KF-1'), rot: List.filled(35, 0), saved: DateTime(2026, 10, 6));

void main() {
  test("the words: the sheet's footer, and the photo's four caption lines", () {
    final w = wordsFor(lookupL(const Locale('en')), zinnia());
    expect(w.footer, 'Zinnia · made with kantha.app');
    expect(w.caption, ['Zinnia', 'Chess — Every seam earns its keep, light against dark.',
      'Upcycled from 35 cloth pieces', 'made with kantha.app']);
  });

  test('a file is named after the design, in letters and dashes', () {
    expect(fileName('Zinnia border', 'pdf'), 'zinnia-border.pdf');
    expect(fileName('Café #2 *bold*', 'png'), 'cafe-2-bold.png');
    expect(fileName('"; rm -rf /', 'pdf'), 'rm-rf.pdf');
    expect(fileName('ഒരു', 'pdf'), 'design.pdf');
  });
}
