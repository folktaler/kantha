import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'backup/files.dart';
import 'cloth/photo_source.dart';
import 'data/backup.dart' show loadBackupCode;
import 'data/sample_box.dart';
import 'data/shelf.dart';
import 'downloads/delivery.dart';
import 'l10n/app_localizations.dart';
import 'platform/browser.dart' as browser;
import 'platform/deferred.dart';
import 'platform/fonts.dart';
import 'platform/links.dart' as links;
import 'platform/loading.dart' as loading;
import 'platform/solver_runner.dart';
import 'studio/controller.dart';
import 'studio/phone/backup_sheet.dart';
import 'studio/phone/boxes_sheet.dart';
import 'studio/phone/cloth_sheet.dart';
import 'studio/phone/designs_phone_sheet.dart';
import 'studio/phone/phone_theme.dart';
import 'studio/phone/phone_toast.dart';
import 'studio/shelf_feed.dart';
import 'studio/studio_screen.dart';
import 'studio/take_menus.dart';
import 'theme.dart';
import 'platform/report.dart';

/* Kantha: the studio at /, and at /backup the studio with the Back up sheet up over it (2026-10-11 one-screen spec,
   decision 6). Everything else off the studio is a sheet over it. It makes the studio's controller and feeds it from
   the shelf (her boxes, cloth and designs), and shows nothing until the shelf first answers.
   `photos` is the camera and gallery, `delivery` where Share, DIY and Back up send their files, `files`
   where a backup is opened from, `makeSolver` starts the arranging off the screen's thread; each is the
   device's own unless a test passes its own.
   If the studio cannot open at all (the shelf fails before it first answers, or the solver cannot start),
   the page says so (`boxes.unread`) rather than standing blank, and the error is reported. */
class KanthaApp extends StatefulWidget {
  const KanthaApp({super.key, required this.shelf, this.photos, this.delivery, this.files,
      this.makeSolver = createSolverRunner, this.storageKept, this.openLink = links.openLink, this.controller,
      this.hideLoading = loading.hideLoading, this.safariOnIphone = browser.safariOnIphone, this.malayalam = loadMalayalam});
  final Shelf shelf;
  final PhotoSource? photos;
  final Delivery? delivery;
  final Files? files;
  final SolverRunner Function() makeSolver;
  /* drift's word on whether this browser keeps anything (null: not known, counted as kept). It is read once,
     when the shelf first answers, and handed to the controller, whose first save says it: drift's onResult
     fires while the database opens, before the first query, so by then it has spoken. */
  final ValueListenable<bool?>? storageKept;
  final void Function(Uri) openLink;
  /* A controller already fed from `shelf` and started (widget tests): used as it is, and not disposed here. */
  final StudioController? controller;
  /* Takes web/index.html's loading screen away (lib/platform/loading.dart); a test counts the call. */
  final void Function() hideLoading;
  /* Whether this is Safari on an iPhone, not opened from the Home Screen (lib/platform/browser.dart), asked once. */
  final bool Function() safariOnIphone;
  /* Loads the Malayalam face (platform/fonts.dart); a test counts the call. */
  final Future<void> Function() malayalam;

  /* The studio on a controller the test has fed and started; the links lead to `openLink`, else nowhere. */
  factory KanthaApp.forTest({Key? key, required StudioController controller, required Shelf shelf, PhotoSource? photos,
          Delivery? delivery, Files? files, bool? kept, void Function(Uri)? openLink, bool safariOnIphone = false}) =>
      KanthaApp(key: key ?? ObjectKey(controller), shelf: shelf, controller: controller, photos: photos, delivery: delivery,
          files: files, storageKept: kept == null ? null : ValueNotifier(kept), openLink: openLink ?? (_) {},
          safariOnIphone: () => safariOnIphone);

  @override
  State<KanthaApp> createState() => _KanthaAppState();
}

/* The words for the first of `preferred` the studio has, as MaterialApp picks its locale (it is given no callback
   of its own), so the controller's words are in the language the screen is. */
L wordsForLocales(List<Locale> preferred) => lookupL(basicLocaleListResolution(preferred, L.supportedLocales));

class _KanthaAppState extends State<KanthaApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  late final StudioController c;
  late final bool _owned = widget.controller == null;
  late final PhotoSource _photos = widget.photos ?? ImagePickerSource();
  late final Delivery _delivery = widget.delivery ?? PlatformDelivery();
  late final TakeAway _takeAway = TakeAway(delivery: _delivery);
  late final StudioActions _actions;
  /* The studio's toasts: one toaster for the app, so a toast outlives a rebuild of the screen. */
  late final _toaster = Toaster();
  late final bool _safariOnIphone = widget.safariOnIphone();
  StreamSubscription<ShelfState>? _feed;
  bool _ready = false, _made = false, _failed = false, _starting = false;

  @override
  void initState() {
    super.initState();
    try {
      c = widget.controller ??
          StudioController(shelf: widget.shelf, solver: widget.makeSolver(),
              words: wordsForLocales(WidgetsBinding.instance.platformDispatcher.locales));
      _made = true;
    } catch (e, st) {
      reportError(e, st, 'while the studio started its solver');
      _failed = true;
      _afterFirstFrame();
      return;
    }
    _actions = StudioActions(openTakeAway: _openTakeAway, openCloth: _openCloth, openBoxes: _openBoxes, deleteBox: _deleteBox,
        openBackup: _openBackup, openLink: widget.openLink, openDesigns: _openDesigns, openPicture: _openPicture);
    // Each save makes the design's picture, as Save photo makes its photo. A test's controller is used as it is.
    if (_owned) c.drawPicture = (d) => _takeAway.picture(c, d);
    _imports = c.imports;
    c.addListener(_afterImport);
    WidgetsBinding.instance.addObserver(this);
    if (_owned) {
      unawaited(_openShelf());
    } else {
      _ready = true;
      c.storageKept = widget.storageKept?.value ?? true;
      _afterFirstFrame();
    }
  }

  /* The Sample box first, so the feed's first answer already holds it and c.start() opens on it. A Sample box
     that could not be made is reported and the studio opens anyway, on what the shelf holds. */
  Future<void> _openShelf() async {
    try {
      await widget.shelf.db.addMissingColumns();
    } catch (e, st) {
      reportError(e, st, 'while the studio checked its tables');
    }
    try {
      await ensureSampleBox(widget.shelf);
    } catch (e, st) {
      reportError(e, st, 'while the Sample box was made');
    }
    // A Sample box made before 22 Oct gets its real cloth before the studio opens on it, unless a design made from its
    // swatches needs its picture made first: that waits for the studio, below (the shelf refuses, 'noPicture').
    var swapped = false;
    try {
      await replaceDrawnSample(widget.shelf);
      swapped = true;
    } on ShelfError catch (e, st) {
      if (e.key != 'noPicture') reportError(e, st, 'while the Sample box was given its real cloth');
    } catch (e, st) {
      reportError(e, st, 'while the Sample box was given its real cloth');
    }
    // Her board's size, before the first solve (it never throws).
    await c.loadBoard();
    if (!mounted) return; // dispose ran during the await: subscribing now would leak
    _feed = shelfFeed(widget.shelf).listen((s) {
      c.restock(s);
      if (_ready || _failed || _starting) return;
      c.storageKept = widget.storageKept?.value ?? true;
      c.start();
      _starting = true;
      if (!swapped) {
        unawaited(c.replaceDrawnSample().catchError((Object e, StackTrace st) {
          reportError(e, st, 'while the Sample box was given its real cloth');
        }));
      }
      // A name on the first screen written in Malayalam (the design's, or a cloth's in the box it opens on): its face
      // first, so that screen is drawn in it from the start. A face that will not load is reported, and the studio opens.
      final names = [c.name, for (final x in c.cloth) if (x.box != null && x.box == c.box) x.name];
      if (!names.any(hasMalayalam)) return _open();
      widget.malayalam()
          .catchError((Object e, StackTrace st) => reportError(e, st, 'while the Malayalam face loaded'))
          .whenComplete(_open);
    }, onError: (Object e, StackTrace st) {
      reportError(e, st, 'while the studio read the shelf');
      // Once the studio is up it carries on with what it has; before that, the page says it cannot open.
      if (_ready || _failed || _starting || !mounted) return;
      setState(() => _failed = true);
      _afterFirstFrame();
    });
  }

  /* The studio, drawn: its first frame. */
  void _open() {
    if (!mounted || _ready) return;
    setState(() => _ready = true);
    _afterFirstFrame();
  }


  /* Once, after the frame that draws the studio or _CannotOpen (not the ground drawn while the shelf opens): the page's
     loading screen goes. Opened at /backup, the Back up sheet comes up over the studio in the same moment. */
  void _afterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.hideLoading();
      // Malayalam, unless a name on the first screen needed it already: its face loads now, after it (his decision,
      // 20 Oct). Public Sans, which only the files set: its files are fetched into memory now, so Print pattern and
      // Save photo still work once the network has gone, and its face is made from them when a file is first made
      // (take_menus.dart), so its fonts-change message does not lay out every line on the screen again just after
      // the first frame.
      unawaited(widget.malayalam().catchError((Object e, StackTrace st) => reportError(e, st, 'while the Malayalam face loaded')));
      unawaited(fetchPublicSans().catchError((Object e, StackTrace st) {
        reportError(e, st, 'while the Public Sans files were fetched');
        return const <ByteData>[];
      }));
      // And the code left out of the first download (`deferred as`): the cloth sheets, the files, the backup and the
      // Sample box's measuring. Loaded now, after the first frame, so a sheet opens without waiting and a studio opened
      // online still saves a backup or a sheet once the network has gone.
      unawaited(Future.wait([loadTwice(loadClothSheets), loadSheetPdf(), loadBackupCode(), loadSwatches()])
          .catchError((Object e, StackTrace st) { reportError(e, st, 'while the rest of the studio loaded'); return const <void>[]; }));
      // The path alone: a query or a fragment on the link still opens the sheet.
      if (!_failed && Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName).path == '/backup') _openBackup();
    });
  }

  /* After an import every photo is new (Shelf.replaceEverythingWith): the decoded squares, and the photos made ready
     for the files, of the device as it was are let go of. */
  late int _imports;
  void _afterImport() {
    if (c.imports == _imports) return;
    _imports = c.imports;
    _takeAway.images.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  /* A sheet over the studio, once its navigator is there. */
  void _over(void Function(BuildContext) show) {
    final context = _navigator.currentContext;
    if (context != null) show(context);
  }

  /* Add a piece or Fix this cloth. */
  void _openCloth(ClothOpen open) => _over((context) => showClothSheet(context, open: open, c: c, photos: _photos, toaster: _toaster));

  /* Your boxes. */
  void _openBoxes() => _over((context) => showBoxesSheet(context, c: c, toaster: _toaster));

  Future<bool> _deleteBox(int box) async {
    final context = _navigator.currentContext;
    return context != null && await askDeleteBox(context, c: c, box: box);
  }

  /* The Back up sheet. */
  void _openBackup() => _over((context) => showBackupSheet(context, c: c, delivery: _delivery,
      files: widget.files ?? const PickerFiles(), toaster: _toaster));

  void _openDesigns() => _over((context) => showDesignsPhone(context, c: c, actions: _actions));

  /* View, over My designs. */
  void _openPicture(BuildContext over, PictureView p) => showPictureSheet(over, picture: p, c: c, takeAway: _takeAway);

  /* The Share sheet. */
  void _openTakeAway(String id) =>
      _over((context) => showExportSheet(context, designId: id, c: c, takeAway: _takeAway, openLink: widget.openLink));

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_made && locales != null) c.words = wordsForLocales(locales);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // `_takeAway` is not disposed: a photo it is still making may finish after the app has gone.
    _feed?.cancel();
    _toaster.dispose();
    if (_made) c.removeListener(_afterImport);
    if (_owned && _made) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const KanthaFrame(home: _CannotOpen());
    // Until the shelf first answers: the studio's own ground, and nothing on it.
    if (!_ready) return const ColoredBox(color: PhonePalette.canvas);
    return KanthaFrame(
      navigatorKey: _navigator,
      home: StudioScreen(
        controller: c,
        actions: _actions,
        toaster: _toaster,
        safariOnIphone: _safariOnIphone,
      ),
    );
  }
}

/* The app's frame: its title, theme and words, around `home`. There is no page off it: whatever the address
   (/backup, or an old /boxes), the navigator opens on `home` alone, and the app reads the address itself. */
class KanthaFrame extends StatelessWidget {
  const KanthaFrame({super.key, required this.home, this.navigatorKey});
  final Widget home;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kantha',
        navigatorKey: navigatorKey,
        routes: {Navigator.defaultRouteName: (_) => home},
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(settings: const RouteSettings(name: Navigator.defaultRouteName), builder: (_) => home),
        ],
        theme: kanthaTheme(),
        // English alone: the studio's words, and Flutter's own English for its widgets (MaterialApp adds
        // DefaultMaterialLocalizations, DefaultCupertinoLocalizations and DefaultWidgetsLocalizations after these),
        // so flutter_localizations' other languages do not ship. With another language in messages/, Flutter's own
        // words (a sheet's Dismiss, a dialog's name, Cut and Paste) follow it too.
        localizationsDelegates: L.supportedLocales.length == 1 ? const [L.delegate] : L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
      );
}

/* The whole page when the studio cannot open: one plain sentence, at a reading measure. */
class _CannotOpen extends StatelessWidget {
  const _CannotOpen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Semantics(liveRegion: true,
                  child: Text(L.of(context).boxesUnread, textAlign: TextAlign.center, style: pText(PType.bodySmall))),
            ),
          ),
        ),
      );
}
