import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'backup/files.dart';
import 'cloth/photo_source.dart';
import 'data/connect.dart';
import 'data/database.dart';
import 'data/sample_box.dart' show loadSwatches;
import 'data/shelf.dart';
import 'downloads/delivery.dart';
import 'platform/persist.dart';
import 'platform/solver_runner.dart';

void main() => runKantha();

bool _pathsSet = false;

/* The one way in: the app on this device's own camera, files, solver and database, or on a test's own.
   In a browser the addresses are paths under /studio/ (/studio/backup, …), not #fragments,
   and the browser is asked to keep this site's data (spec decision 13). That question is not waited for:
   a browser may put it to her, and the studio does not stand blank until she answers. */
Future<void> runKantha({PhotoSource? photos, Delivery? delivery, Files? files,
    SolverRunner? solver, QueryExecutor? database, bool? web}) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set once: a browser refuses a second URL strategy, and a test starts the app more than once.
  if (!_pathsSet) usePathUrlStrategy();
  _pathsSet = true;
  final onWeb = web ?? kIsWeb;
  // The Sample box's measuring, which a first visit needs before its first frame, asked for now: on the web it then
  // downloads beside CanvasKit rather than after it. Loaded from the cache, or not needed, it costs nothing to ask.
  unawaited(loadSwatches().catchError((Object _) {}));
  if (onWeb) unawaited(askToKeepStorage());
  final kept = ValueNotifier<bool?>(null);
  // A new database on a phone's file gives back the space of deleted photos; on the web drift's choice of storage says
  // (connect.dart freesSpace), before the file is made. A database handed in (a test) never does.
  var frees = database == null && !onWeb;
  final shelf = Shelf(KanthaDatabase(database ?? openKantha(onStorage: (k, f) { kept.value = k; frees = f; }),
      freesSpace: () => frees));
  runApp(KanthaApp(shelf: shelf, photos: photos, delivery: delivery, files: files,
      makeSolver: solver == null ? createSolverRunner : () => solver, storageKept: kept));
}
