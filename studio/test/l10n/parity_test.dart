import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/l10n/app_localizations.dart';
import 'package:kantha_studio/l10n/keyed.g.dart';
import 'package:kantha_studio/l10n/words.dart';
import 'package:kantha_studio/solver/compile.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';

void main() {
  final l = lookupL(const Locale('en'));

  test('the words read exactly as en.json writes them', () {
    expect(l.canvasSwatchLabel('KF-3 Teal', '2', '5'), 'KF-3 Teal — 2 of 5 pieces still free');
    expect(l.canvasDefaultName('Chess'), 'Chess');
    expect(l.canvasDeleteSure('Zinnia'), 'Delete “Zinnia”? This cannot be undone.');
  });

  test('the phone redesign\'s words, plurals and all', () {
    expect(l.canvasAddMore(1), 'Add 1 more piece to complete the grid.');
    expect(l.canvasAddMore(12), 'Add 12 more pieces to complete the grid.');
    expect(l.clothAddedNext(7, 'Teal'), '7 pieces of Teal added. Photograph the next one.');
    expect(l.boxesPieces(1), '1 piece');
    expect(l.canvasSwatchAllUsed('Teal', '5'), 'Teal — all 5 pieces are in the design. Tap to add more.');
  });

  test('every template, mount and reason is found by the key the web studio used', () {
    for (final k in LayoutKey.values) {
      expect(l.layoutTitle(k), isNotEmpty);
      expect(l.layoutName(k), isNotEmpty);
    }
    for (final m in Mount.values) { expect(l.mountName(m), isNotEmpty); }
    for (final u in Unfillable.values) { expect(l.notFillable(u), isNotEmpty); }
    expect(plainByKey(l, 'canvas.mounts.tote.name'), 'Tote');
  });
}
