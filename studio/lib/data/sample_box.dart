import 'package:flutter/foundation.dart';
// The measuring of the Sample box's photos, loaded apart (deferred). The image package it uses is not deferred with it:
// measure.dart, which shelf.dart imports, loads it with the studio.
import 'sample_swatches.dart' deferred as swatches;
import '../platform/assets.dart';
import '../platform/deferred.dart';
import 'shelf.dart';

/* The Sample box a fresh install opens on (spec 2026-10-07 sample box, decisions 1 and 3; owner, 22 Oct): ten real
   cloths, photographed at the factory, cropped to cloth only and stored as the studio stores a photo (JPEG q80, no
   EXIF), shipped as app files in assets/sample/. Each is measured by the same code as a photograph when the box is
   made, and stored like any cloth of hers. */
class SampleCloth {
  const SampleCloth(this.name, this.file, [this.pieces = samplePieces]);
  final String name;
  final String file; // in assets/sample/
  final int pieces;
}

const sampleCloth = [
  SampleCloth('Red', 'red.jpg'), // KF-47
  SampleCloth('Navy', 'navy.jpg'), // KF-35
  SampleCloth('Purple', 'purple.jpg', 34), // KF-9
  SampleCloth('Turmeric', 'turmeric.jpg', 31), // KF-46
  SampleCloth('Orange', 'orange.jpg'), // KF-5
  SampleCloth('Dark green', 'dark-green.jpg'), // KF-29
  SampleCloth('White', 'white.jpg', 40), // KF-28
  SampleCloth('Red bandhani', 'red-bandhani.jpg'), // KF-22
  SampleCloth('Red and blue block print', 'red-and-blue-block-print.jpg'), // KF-37
  SampleCloth('Teal flower print', 'teal-flower-print.jpg'), // KF-4
];

/* 12 pieces of each cloth but three, 189 in all (owner, 2 November 2026: "Bigger Sample box", "Only 2 raised", then
   "Add Turmeric"): the fewest that let all 15 patterns fill a board 12 wide × 10 tall, and Heart keep its rule there.
   Chain needs 34 of one dark cloth for its links: Purple, the darkest, which gives Chain the most light and dark
   between links and ground (at 7 × 5 its links were Purple already). Diamond needs 40 of White, the one cloth of its
   light family, for its light rings. Heart's ground must be 25 L* lighter than its heart, and at 12 wide × 10 tall that
   takes 31 of Turmeric, the next lightest after White. */
const samplePieces = 12;

/* A Sample box made with fewer pieces gets each cloth's count today of each cloth she has not changed, once (owner,
   1 and 2 November 2026; Shelf.topUpSample). Run at launch after the swap from the drawn swatches, so the cloth that
   swap puts in is topped up too. */
Future<void> topUpSample(Shelf shelf) =>
    shelf.topUpSample({for (final s in sampleCloth) s.name: s.pieces});

/* The eight swatches drawn in code that a Sample box held before 22 Oct, by name. They are replaced by the ten cloths
   once (replaceDrawnSample); a cloth she photographed into the Sample box has its own C-n name and is never among them. */
const drawnSwatches = {
  'Madder', 'Indigo', 'Turmeric', 'Cream', 'Leaf',
  'Indigo and cream stripe', 'Madder and cream check', 'Cream dots on madder',
};

/* The measuring of the Sample box's photos (sample_swatches.dart), loaded the first time a Sample box is made. */
Future<void> loadSwatches() => loadTwice(swatches.loadLibrary);

/* The ten photos read from the app's files, then measured off the screen's thread on a phone (compute; on the web it
   runs in place). The files are fetched only now, on the web too. `read` stands in for the app's files in a browser
   test, whose server does not serve them. */
Future<List<NewCloth>> measuredSampleCloth(
    {Future<ByteData> Function(String key)? read}) async {
  // All ten asked for at once, then awaited in order, not Future.wait: a bundle that answers at once (a
  // SynchronousFuture) leaves Future.wait's list empty.
  final reads = [for (final s in sampleCloth) (read ?? loadStudioAsset)('assets/sample/${s.file}')];
  final photos = <Uint8List>[];
  for (final r in reads) {
    final b = await r;
    photos.add(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes));
  }
  // Loaded again inside compute's isolate: on a phone a library loaded later is loaded for each isolate on its own.
  final measured = await compute((List<Uint8List> p) async {
    await loadSwatches();
    return swatches.measureAll(p);
  }, photos);
  return [
    for (var i = 0; i < sampleCloth.length; i++)
      (name: sampleCloth[i].name, photo: photos[i], measured: measured[i], pieces: sampleCloth[i].pieces),
  ];
}

/* The box and its cloth written in one transaction, with none nested inside it (Shelf.addBoxWithCloth): a first launch
   interrupted halfway leaves no box, so the `box` counter is still 1 and the next launch makes it whole. */
Future<int> makeSampleBox(Shelf shelf, {Future<ByteData> Function(String key)? read}) async =>
    shelf.addBoxWithCloth(sample: true, cloth: await measuredSampleCloth(read: read));

/* On launch, a database on which no box has ever been made gets the Sample box, once (spec 2026-10-07 sample box,
   decision 1). The `box` counter is the record: it is absent or 1 until the first box is made, and a deleted box
   leaves it where it was. So a Sample box she deleted, even as her only box, does not come back by itself, and an
   imported backup, which brings its own counters, gets one only if it never held a box. Top-level here, not a
   Shelf method, so the import runs one way: sample_box.dart → shelf.dart. */
Future<void> ensureSampleBox(Shelf shelf) async {
  if (await shelf.counterAt('box') > 1) return;
  await makeSampleBox(shelf);
}

/* A Sample box made before 22 Oct holds the drawn swatches: they go and the ten cloths go in, once (owner, 22 Oct;
   Shelf.replaceSample says what is kept). The designs made from the swatches become Picture only: `picturesFirst`
   makes their pictures before the shelf drops them (StudioController.replaceDrawnSample). Without it the swap is tried
   only where no design needs a picture made, as at launch before the studio can draw one; the shelf then refuses,
   'noPicture', and nothing changes. Nothing is read from the app's files when the box holds no swatch. */
Future<void> replaceDrawnSample(Shelf shelf,
    {Future<void> Function(Set<String> cloth, Future<void> Function() drop)? picturesFirst}) async {
  final old = await shelf.swatchesToReplace(drawnSwatches);
  if (old == null) return;
  final cloth = old.isEmpty ? const <NewCloth>[]
      : await measuredSampleCloth();
  Future<void> drop() => shelf.replaceSample(drawnSwatches, cloth);
  if (picturesFirst == null) return drop();
  await picturesFirst(old, drop);
}
