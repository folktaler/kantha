{{flutter_js}}
{{flutter_build_config}}
// The folder every file but index.html sits in, relative to <base href>: '' as written here, the files
// beside index.html (flutter run, flutter drive); tool/build_web.sh rewrites this line to 'r/<release>/'
// when it moves them there (2026-10-08 panels-and-speed decision 8). Keep the trailing slash: the engine
// adds file names to these raw.
const releaseFolder = '';
_flutter.loader.load({ config: {
  assetBase: releaseFolder,
  entrypointBaseUrl: releaseFolder,
  canvasKitBaseUrl: releaseFolder + 'canvaskit/',
  // Fonts ship inside the app (spec decision 4); a glyph none of them has is not
  // fetched from Google's servers but looked for here, in the release folder, and goes without
  // (no fallback fonts ship, so the request is a 404 by design).
  fontFallbackBaseUrl: releaseFolder + 'assets/fonts-fallback/',
} });
