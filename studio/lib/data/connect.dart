import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../platform/release.dart';

/* One database per app install, or per browser profile on the web (spec decision 8).
   On the web sqlite3.wasm sits in the release's folder (platform/release.dart), but drift_worker.js has one
   address for every release, /studio/drift_worker.js: drift names its shared worker by that address, so tabs
   opened before and after a deploy still share one worker and one database. tool/build_web.sh puts it there.
   `onStorage` hears, once, whether this device keeps what she makes: on the web drift
   falls back to memory when the browser offers no lasting storage (a private window, no
   OPFS or IndexedDB), and then all of it is gone when the page closes — she is told so
   (`device.notKept`). It also hears whether a new database there gives back the space of deleted photos
   (freesSpace). drift says both before it makes or opens the file. It is never called on a phone, where the file
   always lasts and a new one always gives space back. */
QueryExecutor openKantha({String name = 'kantha', void Function(bool kept, bool freesSpace)? onStorage}) => driftDatabase(
      name: name,
      web: DriftWebOptions(sqlite3Wasm: releaseFile('sqlite3.wasm', pageBase()), driftWorker: pageBase().resolve('drift_worker.js'),
          onResult: (r) {
            if (r.missingFeatures.isNotEmpty) {
              debugPrint('Kantha storage: ${r.chosenImplementation.name}; the browser lacks ${r.missingFeatures.map((f) => f.name).join(', ')}');
            }
            onStorage?.call(keepsData(r.chosenImplementation), freesSpace(r.chosenImplementation));
          }),
    );

/* Whether drift's choice on the web lasts past the page: only memory does not. */
bool keepsData(WasmStorageImplementation chosen) => chosen != WasmStorageImplementation.inMemory;

/* Whether a new database in drift's choice on the web is made with auto_vacuum FULL (KanthaDatabase), so a delete
   shortens the file inside its own commit: OPFS keeps SQLite's rollback journal beside the file, so a commit cut off
   part-way is rolled back on the next open. Never IndexedDB, which holds the file in memory and writes its blocks
   later, so a tab closed during a commit that moves pages could leave a mix of old and new ones; never memory, which
   keeps nothing to give back. */
bool freesSpace(WasmStorageImplementation chosen) =>
    chosen == WasmStorageImplementation.opfsShared || chosen == WasmStorageImplementation.opfsLocks;
