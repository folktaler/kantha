import 'page_base_io.dart' if (dart.library.js_interop) 'page_base_web.dart' as impl;

/* On the web every studio file but index.html sits in /studio/r/<release>/, named by the commit it was
   built from (tool/build_web.sh passes it; 2026-10-08 panels-and-speed decision 8). Empty in a build
   that leaves the files beside index.html: flutter run, flutter drive, the tests. */
const release = String.fromEnvironment('KANTHA_RELEASE');

/* The address of one of the release's files, absolute. Absolute because drift hands sqlite3.wasm's
   address to its worker as a string, and a worker reads a relative address against its own script. */
Uri releaseFile(String name, Uri base, [String folder = release]) =>
    base.resolve(folder.isEmpty ? name : 'r/$folder/$name');

/* What the release's files are resolved against: the document's base, /studio/ under
   <base href="/studio/">, whatever route the page is on. Not Uri.base, which is the page's own address
   (/studio/backup on a path route). Only the web reads it. */
Uri pageBase() => impl.pageBase();
