/* The templates. A new one goes at the end: a saved design names its template. */
import 'dart:typed_data';
import 'compile.dart';
import 'geometry.dart';
import 'score.dart';
import 'spec.dart';
import 'tuned.dart';

enum LayoutKey { contrast, gradient, medallion, wave, framed, cross, spectrum, boro, blocks, medallionPrint, heart, stripes, zigzag, chain, diamond }
const layoutKeys = LayoutKey.values;
const double heartHue = 30;

final Uint8List _plain = Uint8List(cells);
final Uint8List _blockZones = zoneMap(['00011', '00011', '00011', '22222', '22222', '22222', '22222']);
final Uint8List _heartZones = zoneMap(['.....', '.1.1.', '11111', '11111', '.111.', '..1..', '.....']);

final Map<LayoutKey, LayoutSpec> layouts = {
  LayoutKey.contrast: LayoutSpec(zones: _plain, rules: {0: const ZoneRules()}, within: const SeamFull(), perimeter: true, balance: true),
  LayoutKey.gradient: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LAt(Ramps.gradient, wFit))}, within: const SeamNone(), perimeter: false, balance: false),
  LayoutKey.medallion: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.medallion, wFit))}, within: const SeamNone(), perimeter: false, balance: false),
  LayoutKey.wave: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.wave, wFit))}, within: const SeamNone(), perimeter: true, balance: false),
  LayoutKey.framed: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.framed, wFit))}, within: const SeamNone(), perimeter: true, balance: false),
  LayoutKey.cross: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.cross, wFit))}, within: const SeamNone(), perimeter: true, balance: false),
  LayoutKey.spectrum: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(hue: (angle: Ramps.spectrumHue, weight: wHue))}, within: const SeamLightness(), perimeter: true, balance: false),
  LayoutKey.boro: LayoutSpec(zones: _plain, rules: {0: const ZoneRules()}, within: const SeamLightness(), perimeter: true, balance: false),
  LayoutKey.blocks: LayoutSpec(
    zones: _blockZones,
    rules: {
      0: const ZoneRules(family: (weight: Tuned.blockWeight)),
      1: const ZoneRules(family: (weight: Tuned.blockWeight)),
      2: const ZoneRules(family: (weight: Tuned.blockWeight)),
    },
    within: const SeamLightness(), perimeter: true, balance: false,
  ),
  LayoutKey.medallionPrint: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(edge: (t: Ramps.printMedallion, weight: wFit))}, within: const SeamNone(), perimeter: false, balance: false),
  LayoutKey.heart: LayoutSpec(
    zones: _heartZones,
    rules: {0: ZoneRules(l: LFromT((_, _, _) => 1, wFit)), 1: const ZoneRules(colour: (hue: heartHue, weight: Tuned.colourWeight))},
    within: const SeamNone(), boundary: SeamCustom(lTarget: baseWeightsWith(Tuned.lightness).lTarget, weight: Tuned.boundaryWeight),
    perimeter: false, balance: false, ground: 0,
  ),
  LayoutKey.stripes: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.stripes, wFit))}, within: const SeamNone(), perimeter: true, balance: false),
  LayoutKey.zigzag: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.zigzag, wFit))}, within: const SeamNone(), perimeter: false, balance: false),
  LayoutKey.chain: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.chain, wFit))}, within: const SeamNone(), perimeter: false, balance: false),
  LayoutKey.diamond: LayoutSpec(zones: _plain, rules: {0: const ZoneRules(l: LFromT(Ramps.diamond, wFit))}, within: const SeamNone(), perimeter: false, balance: false),
};

Compiled modelFor(LayoutKey key, ObjectiveInput input) => compile(layouts[key]!, input);
