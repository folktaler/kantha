/* Share as one sheet for one saved design (phone redesign handover, Bottom sheets; the owner's
   markup of 19 Oct): it saves the photo, prints the sheet and leads to the stitching guide.
   Every file is made here, on the device. */
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pool/pool.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../downloads/caption.dart';
import '../downloads/cloth_images.dart';
import '../downloads/delivery.dart';
import '../downloads/file_name.dart';
import '../downloads/footer_png.dart';
import '../downloads/photo_png.dart';
// The pdf package is loaded when a sheet is first made, not with the studio's first screen (his decision, 20 Oct).
import '../downloads/sheet_pdf.dart' deferred as sheet_pdf;
import '../l10n/app_localizations.dart';
import '../platform/deferred.dart';
import '../platform/fonts.dart';
import '../platform/links.dart' show helpUri;
import 'controller.dart';
import 'phone/phone_sheet.dart';
import 'phone/phone_theme.dart';
import 'shelf_feed.dart';
import '../platform/report.dart';

/* The pdf package and the sheet drawn with it, loaded the first time a sheet is made. */
Future<void> loadSheetPdf() => loadTwice(sheet_pdf.loadLibrary);

/* The photo Save photo saves, and its small copy when `withThumb`, for one version of one design. `png` is null while it
   is being made, and `failed` if it could not be. */
class _Photo {
  _Photo(this.version, this.withThumb);
  final String version;
  final bool withThumb;
  Uint8List? png, thumb;
  bool failed = false;
}

/* What Share makes, kept for the app's life: each cloth's picture, ready to embed,
   and the latest photo (only the latest is kept, 526-533). */
class TakeAway {
  TakeAway({required this.delivery, ClothImages? images}) : images = images ?? ClothImages();
  final Delivery delivery;
  final ClothImages images;
  _Photo? _photo;
  Future<({Uint8List png, Uint8List? thumb})?>? _making;

  /* Each cloth the design uses that is still in a box she reads; one that has gone is null,
     and its squares come out plain (usesGoneCloth, 579-585). */
  Map<String, ClothView?> _clothOf(StudioController c, DesignView d) {
    final byId = {for (final x in c.cloth) x.id: x};
    return {for (final id in d.grid.toSet()) id: byId[id]?.box == null ? null : byId[id]};
  }

  /* versionOf: what it is made of, its mount, its name, and its cloth's pictures, each named as ClothImages
     keeps it (ClothPhoto: the cloth's id, its photo's number, its version and when it was added); and the imports since the studio opened, so nothing
     made before an import is handed out after it. */
  String versionOf(StudioController c, DesignView d) => jsonEncode({
        'id': d.id, 'grid': d.grid, 'rot': d.rot, 'mount': d.mount.name, 'name': d.name, 'imports': c.imports,
        'pictures': [
          for (final x in _clothOf(c, d).values)
            switch (x?.image) {
              final ClothPhoto p => [p.id, p.photo, p.version, p.added.microsecondsSinceEpoch],
              _ => x?.version,
            },
        ],
      });

  /* Each cloth's photo read and made ready four at a time, so the reads and the decodes overlap. */
  Future<Map<String, Uint8List?>> _jpegs(StudioController c, DesignView d) async {
    final cloth = _clothOf(c, d).entries.toList();
    final pool = Pool(4);
    final jpegs = await Future.wait([
      for (final e in cloth) e.value == null ? Future<Uint8List?>.value() : pool.withResource(() => images.jpeg(e.value!)),
    ]);
    await pool.close();
    return {for (var i = 0; i < cloth.length; i++) cloth[i].key: jpegs[i]};
  }

  /* The files' own faces: Public Sans, which every file sets, made here the first time a file is made from the files
     the app fetched just after its first frame (fetched now if that failed), and Malayalam
     (which the app loads just after its first frame; asked for again, in case that load failed) only when the words
     have Malayalam in them, so a Malayalam face that will not load fails no file without it. */
  static Future<void> _faces(Iterable<String> words) async {
    await loadPublicSans();
    if (words.any(hasMalayalam)) await loadMalayalam();
  }

  /* The A4 sheet (Print pattern PDF). */
  Future<Uint8List> sheet(StudioController c, DesignView d) async {
    final jpegs = await _jpegs(c, d);
    final footer = wordsFor(c.words, d).footer;
    await _faces([footer]);
    await loadSheetPdf();
    return sheet_pdf.sheetPdf(d, jpegs, await footerPng(footer));
  }

  /* preparePhoto: the photo for the design as it is now, unless it is made or
     being made already; made again after it failed. With `thumb`, its small copy too (a saved design's picture). */
  void preparePhoto(StudioController c, DesignView d, {bool thumb = false}) {
    final version = versionOf(c, d);
    final now = _photo;
    if (now != null && now.version == version && !now.failed && (now.withThumb || !thumb)) return;
    final photo = _photo = _Photo(version, thumb);
    final making = _making = _drawPhoto(c, d, thumb);
    making.then((made) {
      photo.png = made?.png;
      photo.thumb = made?.thumb;
      photo.failed = made == null;
    });
  }

  Future<({Uint8List png, Uint8List? thumb})?> _drawPhoto(StudioController c, DesignView d, bool thumb) async {
    final decoded = <String, ui.Image?>{};
    try {
      final pool = Pool(4);
      await Future.wait([
        for (final e in (await _jpegs(c, d)).entries)
          if (e.value == null) Future.sync(() => decoded[e.key] = null)
          else pool.withResource(() async => decoded[e.key] = await _decode(e.value!)),
      ]);
      await pool.close();
      final caption = wordsFor(c.words, d).caption;
      await _faces(caption);
      return await photoPng(d, decoded, caption, thumb: thumb);
    } catch (e, st) {
      reportError(e, st, 'while the photo of a design was made');
      return null;
    } finally {
      for (final i in decoded.values) {
        i?.dispose();
      }
    }
  }

  static Future<ui.Image?> _decode(Uint8List jpeg) async {
    try {
      final codec = await ui.instantiateImageCodec(jpeg);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null; // drawn plain
    }
  }

  /* photoFor: the photo for the design as it is now — null while it is made. */
  _Photo? _photoFor(StudioController c, DesignView d) {
    final p = _photo;
    return p != null && p.version == versionOf(c, d) ? p : null;
  }

  /* A saved design's picture (the photo Save photo saves) and its small copy, for My designs. Null when the photo
     could not be made. */
  Future<({Uint8List png, Uint8List thumb})?> picture(StudioController c, DesignView d) async {
    final p = _photoFor(c, d);
    if ((p?.png, p?.thumb) case (final png?, final thumb?)) return (png: png, thumb: thumb);
    preparePhoto(c, d, thumb: true);
    final made = await _making;
    return made?.thumb == null ? null : (png: made!.png, thumb: made.thumb!);
  }

  /* The photo for the design as it is now, if it is made already. */
  Uint8List? photoMade(StudioController c, DesignView d) => _photoFor(c, d)?.png;

  /* The photo as it is now, waiting for it if it is still being made: no small copy is made for it. */
  Future<Uint8List?> photoNow(StudioController c, DesignView d) async {
    if (photoMade(c, d) case final png?) return png;
    preparePhoto(c, d);
    return (await _making)?.png;
  }
}

/* A row's file made and handed over. The sheet stays open while its file is made, the row busy and not to be pressed
   again; then it closes. A file that could not be made leaves the row saying so, to try again. */
mixin _Delivers<W extends StatefulWidget> on State<W> {
  void _close() => Navigator.of(context).pop();

  /* Rows at work making or handing over their file, and rows whose file could not be made. */
  final _busy = <String>{}, _failed = <String>{};
  final _rows = <String, GlobalKey>{};
  GlobalKey _key(String row) => _rows.putIfAbsent(row, GlobalKey.new);

  /* Where the row is on the screen: an iPad's share sheet points at it. */
  Rect? _origin(String row) {
    final box = _rows[row]?.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
  }

  Future<void> _deliver(String row, Future<void> Function(Rect? origin) make) async {
    if (_busy.contains(row)) return;
    setState(() { _busy.add(row); _failed.remove(row); });
    try {
      await make(_origin(row));
      if (mounted) _close();
    } catch (e, st) {
      reportError(e, st, 'while the $row file was made or handed over');
      if (mounted) setState(() => _failed.add(row));
    } finally {
      if (mounted) setState(() => _busy.remove(row));
    }
  }
}

/* The Share sheet (the owner's markup of 19 Oct): Save photo, Print pattern PDF, then Kantha stitching guide. A design whose cloth has gone says so first, in red. */
Future<void> showExportSheet(BuildContext context, {required String designId, required StudioController c,
    required TakeAway takeAway, required void Function(Uri) openLink}) {
  return showPhoneSheet<void>(
    context,
    title: L.of(context).canvasShare,
    builder: (_) => _ExportBody(designId: designId, c: c, takeAway: takeAway, openLink: openLink),
  );
}

class _ExportBody extends StatefulWidget {
  const _ExportBody({required this.designId, required this.c, required this.takeAway, required this.openLink});
  final String designId;
  final StudioController c;
  final TakeAway takeAway;
  final void Function(Uri) openLink;

  @override
  State<_ExportBody> createState() => _ExportBodyState();
}

class _ExportBodyState extends State<_ExportBody> with _Delivers<_ExportBody> {
  StudioController get c => widget.c;
  TakeAway get t => widget.takeAway;

  /* Whether Save photo's last failure was the photo not being made, rather than its handing over. */
  var _photoNotMade = false;

  /* A row that makes a file: its icon, a spinner in its place while it works, its failure (in `failedText`) and a retry
     after. */
  Widget _fileRow(String row, {required String name, String? note, required tabler.Icon icon, required String failedText,
      required Future<void> Function(Rect? origin)? make}) {
    final busy = _busy.contains(row), failed = _failed.contains(row) && !busy;
    return KeyedSubtree(
      key: _key(row),
      child: SheetRow(name: failed ? failedText : name, note: note, icon: icon,
          iconBusy: busy ? const _Spinner() : null,
          onPressed: make == null || busy ? null : () => _deliver(row, make)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = L.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final d = c.designFor(widget.designId);
        // As the sheet opens (and once the design it names has reached the studio): its photo, so Save photo has it in
        // hand at the press and saves it inside the tap — Safari only downloads inside the tap that asked. The sheet does
        // not listen for the photo: nothing on it changes when the photo is made.
        if (d != null && t._photoFor(c, d) == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) t.preparePhoto(c, d); });
        }
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (c.usesGoneCloth(widget.designId))
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(words.canvasMissingCloth, style: pText(PType.metadata, color: PhonePalette.red))),
          _fileRow('photo', name: words.canvasSavePhoto, icon: const tabler.PhotoDown(),
              failedText: _photoNotMade ? words.canvasSharePhotoFailed : words.canvasDownloadFailed,
              make: d == null ? null : (_) async {
                // Made already, it is handed over before anything is awaited: still inside the tap.
                final png = t.photoMade(c, d) ?? await t.photoNow(c, d);
                _photoNotMade = png == null;
                if (png == null) throw StateError('the photo could not be made');
                await t.delivery.savePhoto(png, fileName(d.name, 'png'));
              }),
          _fileRow('pdf', name: words.canvasPrintPattern, note: words.canvasPrintPatternNote, icon: const tabler.Printer(),
              failedText: words.canvasDownloadFailed,
              make: d == null ? null : (origin) async =>
                  t.delivery.sharePdf(await t.sheet(c, d), fileName(d.name, 'pdf'), origin: origin)),
          SheetRow(name: words.canvasStitchingGuide, note: words.canvasStitchingGuideNote, icon: const tabler.Book(),
              onPressed: () {
                _close();
                widget.openLink(helpUri('lay'));
              }),
        ]);
      },
    );
  }
}

/* View (owner, 20 Oct): a saved picture, titled with its name, over the sheet that asked: the picture itself, then
   Save photo and Share…, which hand over the picture as stored. It is read as the sheet opens, so Save photo has it in
   hand at the press (Safari only downloads inside the tap that asked); until then both rows wait. */
Future<void> showPictureSheet(BuildContext context, {required PictureView picture, required StudioController c,
    required TakeAway takeAway}) {
  return showPhoneSheet<void>(context, title: picture.name,
      builder: (_) => _PictureBody(picture: picture, c: c, takeAway: takeAway));
}

class _PictureBody extends StatefulWidget {
  const _PictureBody({required this.picture, required this.c, required this.takeAway});
  final PictureView picture;
  final StudioController c;
  final TakeAway takeAway;

  @override
  State<_PictureBody> createState() => _PictureBodyState();
}

class _PictureBodyState extends State<_PictureBody> with _Delivers<_PictureBody> {
  Uint8List? _png;

  @override
  void initState() {
    super.initState();
    widget.c.shelf.pictureOf(widget.picture.id).then((png) {
      if (mounted) setState(() => _png = png);
    }, onError: (Object e, StackTrace st) {
      reportError(e, st, 'while a picture was read to be viewed');
    });
  }

  Widget _row(String row, {required String name, required tabler.Icon icon,
      required Future<void> Function(Uint8List png, Rect? origin) give}) {
    final png = _png, busy = _busy.contains(row), failed = _failed.contains(row) && !busy;
    return KeyedSubtree(
      key: _key(row),
      child: SheetRow(name: failed ? L.of(context).canvasDownloadFailed : name, icon: icon,
          iconBusy: busy ? const _Spinner() : null,
          onPressed: png == null || busy ? null : () => _deliver(row, (origin) => give(png, origin))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = L.of(context);
    final file = fileName(widget.picture.name, 'png');
    final png = _png;
    // The picture at its 4:5, as wide as the sheet allows and at most 40 % of the screen's height, decoded at that size.
    return LayoutBuilder(builder: (context, room) {
      final width = math.min(room.maxWidth - 32, 0.4 * MediaQuery.sizeOf(context).height * photoWidth / photoHeight);
      final height = width * photoHeight / photoWidth, dpr = MediaQuery.devicePixelRatioOf(context);
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Center(child: Container(
            key: const ValueKey('picture-view'),
            width: width, height: height, color: PhonePalette.canvas,
            child: png == null ? null : Image(
                image: ResizeImage(MemoryImage(png), width: (width * dpr).round(), height: (height * dpr).round(),
                    policy: ResizeImagePolicy.fit),
                fit: BoxFit.contain, excludeFromSemantics: true, gaplessPlayback: true),
          )),
        ),
        _row('photo', name: words.canvasSavePhoto, icon: const tabler.PhotoDown(),
            give: (png, _) => widget.takeAway.delivery.savePhoto(png, file)),
        _row('share', name: words.canvasShareTo, icon: const tabler.Share(),
            give: (png, origin) => widget.takeAway.delivery.sharePhoto(png, file, origin: origin)),
      ]);
    });
  }
}

/* .spin: the loader turning once a second, the size of an icon beside a card label, in text2; still where she asked for
   less motion. */
class _Spinner extends StatefulWidget {
  const _Spinner();
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _turn, child: roleIcon(const tabler.Loader2(), PType.cardLabel, color: PhonePalette.text2));
}
