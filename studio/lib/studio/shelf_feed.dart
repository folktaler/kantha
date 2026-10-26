import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show SynchronousFuture, listEquals;
import 'package:flutter/widgets.dart';
import '../data/box_view.dart';
import '../data/database.dart';
import '../data/numbers.dart' show busyOf, edgeOf;
import '../data/shelf.dart';
import '../solver/geometry.dart';
import '../solver/hue.dart';
import '../solver/layouts.dart';

export '../data/box_view.dart';

/* One cloth of hers as the studio shows it. */
class ClothView {
  const ClothView({required this.id, required this.name, required this.lab, required this.busy, required this.edge,
      required this.grain, required this.stock, required this.box, required this.fabric, required this.image, required this.version});
  final String id, name, fabric;
  final Lab lab;
  final bool? busy;
  final double? edge;
  final ({double angle, double coherence})? grain;
  final int stock, version;
  final int? box;
  final ImageProvider? image;
  ClothView gone() => ClothView(id: id, name: name, lab: lab, busy: busy, edge: edge, grain: grain, stock: 0, box: null,
      fabric: fabric, image: image, version: version);
  ClothView _showing(ImageProvider? picture) => ClothView(id: id, name: name, lab: lab, busy: busy, edge: edge,
      grain: grain, stock: stock, box: box, fabric: fabric, image: picture, version: version);
  /* The same cloth, shown the same way: its photo too (a backup can bring another C-1 at version 1, with the same name
     and colour, and another photo). */
  bool same(ClothView o) => o.id == id && o.name == name && o.stock == stock && o.box == box && o.fabric == fabric &&
      o.version == version && o.lab == lab && o.image == image;
}

/* A cloth's stored photo, read from the shelf when a square or a swatch first shows it; the list the studio watches
   does not carry it (Shelf.watchCloth). It is named by the cloth's id, the photo's number (Cloths.photoNumber), which
   every stored photo gets anew, a re-crop's and an import's too, and the cloth's version and when it was added, which
   a tab still on the code from before photo numbers changes on a re-crop (version) and an import (added) while it
   leaves the number as it was: two pictures are equal exactly when they are the same photo, so the image cache keeps
   one decode for both and never hands one photo out for another. This picture keeps its own read from when it starts, so the board's square and the dock's swatch beside it,
   decoded at two sizes in the same moment, read the shelf once, and a cloth removed while its square is still drawn
   (stableCloth's gone) keeps its photo. One never read before it went from the shelf shows nothing, and nothing is
   reported. */
@immutable
class ClothPhoto extends ImageProvider<ClothPhoto> {
  ClothPhoto(this.shelf, this.id, this.photo, this.version, this.added);
  final Shelf shelf;
  final String id;
  final int photo, version;
  final DateTime added;
  final _held = _Held();

  /* The photo as stored, while the cloth still holds this one; null once it does not, so another photo is never
     cached under this picture's key. */
  Future<Uint8List?> bytes() => shelf.photoOf(id, photo, version, added);

  /* The read this picture already has, done or under way, else a new one from the shelf, kept from then on. A read
     that finds nothing, or fails, is not kept: the next one asks the shelf again. */
  Future<Uint8List?> _shown() {
    if (_held.read case final read?) return read;
    late final Future<Uint8List?> read;
    void forget() {
      if (identical(_held.read, read)) _held.read = null;
    }
    read = bytes().then((b) {
      if (b == null) forget();
      return b;
    }, onError: (Object e, StackTrace s) {
      forget();
      return Future<Uint8List?>.error(e, s);
    });
    return _held.read = read;
  }

  @override
  Future<ClothPhoto> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(ClothPhoto key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _codec(decode), scale: 1, debugLabel: 'ClothPhoto($id#$photo v$version $added)');

  Future<ui.Codec> _codec(ImageDecoderCallback decode) async =>
      decode(await ui.ImmutableBuffer.fromUint8List(await _shown() ?? _nothing));

  @override
  bool operator ==(Object other) => other is ClothPhoto && identical(other.shelf, shelf) && other.id == id &&
      other.photo == photo && other.version == version && other.added == added;

  @override
  int get hashCode => Object.hash(identityHashCode(shelf), id, photo, version, added);
}

/* A picture's small copy, read from the shelf when its row first shows it: ClothPhoto's reading and caching, keyed by
   the picture's own id (a new one at every save; ids are never dealt twice) under its own prefix, so it is never
   taken for a cloth's photo. */
@immutable
class PictureThumb extends ClothPhoto {
  PictureThumb(Shelf shelf, this.picture, DateTime made) : super(shelf, 'picture-$picture', picture, 1, made);
  final int picture;
  @override
  Future<Uint8List?> bytes() => shelf.thumbOf(picture);
}

/* One saved picture: of `design` while that is saved, else Picture only. */
class PictureView {
  const PictureView({required this.id, required this.design, required this.name, required this.made, required this.thumb});
  final int id;
  final String? design;
  final String name;
  final DateTime made;
  final ImageProvider thumb;
}

class _Held {
  Future<Uint8List?>? read;
}

/* A 1 × 1 PNG, fully clear: what a cloth no longer on the shelf shows. */
final _nothing = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=');

/* One saved design, as My designs lists it and the board opens it. */
class DesignView {
  const DesignView({required this.id, required this.name, required this.layout, required this.mount, required this.box,
      required this.seed, required this.started, required this.firstSolve, required this.grid, required this.rot, required this.saved});
  final String id, name;
  final LayoutKey layout;
  final Mount mount;
  final int? box, seed;
  final String? started, firstSolve;
  final List<String> grid;
  final List<int> rot;
  final DateTime saved;
  DesignView copyWithGrid(List<String> g) => DesignView(id: id, name: name, layout: layout, mount: mount, box: box, seed: seed,
      started: started, firstSolve: firstSolve, grid: g, rot: rot, saved: saved);
  /* The same design: what a file is made from, and when it was saved. */
  bool sameAs(DesignView o) => o.id == id && o.name == name && o.layout == layout && o.mount == mount && o.box == box &&
      o.saved == saved && listEquals(o.grid, grid) && listEquals(o.rot, rot);
  /* A test's convenience: the same design with other turns. */
  DesignView copyWithRot(List<int> r) => DesignView(id: id, name: name, layout: layout, mount: mount, box: box, seed: seed,
      started: started, firstSolve: firstSolve, grid: grid, rot: r, saved: saved);
  /* A test's convenience: the same design on another mount, named as the shelf stores it. */
  DesignView withMount(String m) => DesignView(id: id, name: name, layout: layout, mount: Mount.values.byName(m), box: box,
      seed: seed, started: started, firstSolve: firstSolve, grid: grid, rot: rot, saved: saved);

  static DesignView of(DesignRow r) {
    final cells = (jsonDecode(r.grid) as List).cast<Map<String, dynamic>>();
    return DesignView(
      id: r.id, name: r.name,
      layout: LayoutKey.values.asNameMap()[r.layout] ?? LayoutKey.contrast,
      mount: Mount.values.asNameMap()[r.mount] ?? Mount.none, // a mount that no longer exists opens as Plain
      box: r.box, seed: r.seed, started: r.started, firstSolve: r.firstSolve,
      grid: [for (final c in cells) c['id'] as String], rot: [for (final c in cells) c['rot'] as int], saved: r.saved,
    );
  }
}

class ShelfState {
  const ShelfState(this.cloth, this.boxes, this.designs, [this.pictures = const []]);
  final List<ClothView> cloth;
  final List<BoxView> boxes;
  final List<DesignView> designs;
  final List<PictureView> pictures;
}

PictureView _pictureView(Shelf shelf, PictureFacts p) =>
    PictureView(id: p.id, design: p.design, name: p.name, made: p.made, thumb: PictureThumb(shelf, p.id, p.made));

ClothView _fromRow(Shelf shelf, ClothFacts r) => ClothView(id: r.id, name: r.name, lab: (l: r.l, a: r.a, b: r.b),
    busy: busyOf(r.spread), edge: edgeOf(r.spread), grain: null, stock: r.pieces, box: r.box, fabric: r.fabric,
    image: ClothPhoto(shelf, r.id, r.photo, r.version, r.added), version: r.version);

BoxView _boxView(BoxRow b) => BoxView(id: b.id, number: b.number, sample: b.name == sampleBoxName);

/* Her boxes, cloth and designs, live, as one stream. */
Stream<ShelfState> shelfFeed(Shelf shelf) {
  late final StreamController<ShelfState> out;
  final subs = <StreamSubscription<Object?>>[];
  List<BoxRow>? boxes;
  List<ClothFacts>? cloth;
  List<DesignRow>? designs;
  List<PictureFacts>? pictures;
  void emit() {
    if (boxes == null || cloth == null || designs == null || pictures == null) return;
    out.add(_stateOf(shelf, boxes!, cloth!, designs!, pictures!));
  }
  out = StreamController<ShelfState>(
    onListen: () {
      subs
        ..add(shelf.watchBoxes().listen((b) { boxes = b; emit(); }, onError: out.addError))
        ..add(shelf.watchCloth().listen((c) { cloth = c; emit(); }, onError: out.addError))
        ..add(shelf.watchDesigns().listen((d) { designs = d; emit(); }, onError: out.addError))
        ..add(shelf.watchPictures().listen((p) { pictures = p; emit(); }, onError: out.addError));
    },
    onCancel: () async { for (final s in subs) { await s.cancel(); } },
  );
  return out.stream;
}

/* What the shelf holds now, read once. */
Future<ShelfState> shelfNow(Shelf shelf) async {
  final boxes = await shelf.watchBoxes().first, cloth = await shelf.watchCloth().first, designs = await shelf.watchDesigns().first;
  final pictures = await shelf.watchPictures().first;
  return _stateOf(shelf, boxes, cloth, designs, pictures);
}

ShelfState _stateOf(Shelf shelf, List<BoxRow> boxes, List<ClothFacts> cloth, List<DesignRow> designs,
        List<PictureFacts> pictures) =>
    ShelfState([for (final c in cloth) _fromRow(shelf, c)], [for (final b in boxes) _boxView(b)],
        designs.map(DesignView.of).toList(), [for (final p in pictures) _pictureView(shelf, p)]);

/* The restock: a cloth keeps its place, so a design's squares still point
   at the same cloth. A new one goes on the end; one that has gone keeps its place
   but leaves every box (no box, none in stock), and keeps its photo. A cloth whose count or name changed, and not its
   photo, keeps the picture it had, and with it the photo that picture has read. Nothing changed: the same list back. */
List<ClothView> stableCloth(List<ClothView> prev, List<ClothView> now) {
  final by = {for (final c in now) c.id: c};
  final had = {for (final c in prev) c.id};
  final next = [
    for (final c in prev)
      if (by[c.id] case final n?)
        (n.same(c) ? c : n.image == c.image ? n._showing(c.image) : n)
      else
        (c.box == null && c.stock == 0 ? c : c.gone()),
  ];
  final added = [for (final c in now) if (!had.contains(c.id)) c];
  if (added.isEmpty && [for (var i = 0; i < next.length; i++) identical(next[i], prev[i])].every((x) => x)) return prev;
  return [...next, ...added];
}
