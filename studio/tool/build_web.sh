#!/bin/sh
# The web studio, built to be served as files by a web server at /studio. Run in studio/.
# Nothing it loads at run time comes from another site: CanvasKit is bundled
# (--no-web-resources-cdn), the fonts are bundled, sqlite3.wasm and the two workers ship
# with the app. Building needs the network: pub get, and prepare_web.sh downloads
# sqlite3.wasm and drift_worker.js from the drift release that pubspec.lock names.
#
# What it leaves in build/web (2026-10-08 panels-and-speed decisions 6-8):
#   index.html               the only file that names the release; served no-cache
#   drift_worker.js          one address for every release, no-cache (lib/data/connect.dart says why)
#   r/<release>/…            every other file; served immutable, kept for a year
#   *.br, *.gz beside each text and wasm file, so the server sends them compressed without compressing
# The release is the short commit. A build from a tree whose tracked files differ from HEAD would
# carry a name that is not what it holds, so it stops, unless KANTHA_RELEASE names the build.
# Untracked files do not count. The check runs after pub get and prepare_web.sh, which may change
# a tracked file (pubspec.lock), so the build that follows is the commit it is named for.
set -eu

# 1. What the build needs: the packages, sqlite3.wasm, drift_worker.js and the solver's worker in web/.
flutter pub get
./tool/prepare_web.sh

# 2. The release.
if [ -z "${KANTHA_RELEASE:-}" ]; then
	if ! git diff --quiet HEAD --; then
		echo "build_web.sh: tracked files differ from HEAD. Commit them, or set KANTHA_RELEASE to name this build." >&2
		exit 1
	fi
	KANTHA_RELEASE=$(git rev-parse --short HEAD)
fi
release=$KANTHA_RELEASE
# Hex only: it goes into paths, a sed line, and the site's e2e reads it back as [0-9a-f]+.
case $release in
*[!0-9a-f]* | '')
	echo "build_web.sh: KANTHA_RELEASE '$release' is not a short commit (0-9, a-f)." >&2
	exit 1
	;;
esac
echo "build_web.sh: release $release"

# 3. Build. The app reads the release (lib/platform/release.dart) to find sqlite3.wasm and the solver's worker.
# From an empty folder: a flutter drive leaves its own build here, and an earlier build's r/ or .br
# copies would otherwise ship beside this one.
rm -rf build/web
# flutter build web copies all of web/ (the three files prepare_web.sh made among them).
flutter build web --release --base-href /studio/ --no-web-resources-cdn --dart-define=KANTHA_RELEASE="$release"
# The worker's Dart source and the compiler's notes on it are not part of the site.
rm -f build/web/solver_worker.dart build/web/solver_worker.js.deps build/web/solver_worker.js.map

# 4. Every file but index.html moves into r/<release>/. drift_worker.js is copied back beside index.html:
# drift names its shared worker by the worker's address, so every release must use the same one.
mkdir build/web/r
mkdir "build/web/r/$release"
find build/web -mindepth 1 -maxdepth 1 ! -name index.html ! -name r -exec mv {} "build/web/r/$release/" \;
cp "build/web/r/$release/drift_worker.js" build/web/drift_worker.js

# 5. The loader looks for the app, its assets, CanvasKit and its fallback fonts in the release folder
# (web/flutter_bootstrap.js says how), and index.html names its four files there.
# Each rewrite is checked: a pattern that matched nothing would ship a studio that loads nothing.
rewrite() { # file, sed expression
	sed "$2" "$1" >"$1.new"
	mv "$1.new" "$1"
}
rewrite "build/web/r/$release/flutter_bootstrap.js" "s|^const releaseFolder = '';\$|const releaseFolder = 'r/$release/';|"
grep -qx "const releaseFolder = 'r/$release/';" "build/web/r/$release/flutter_bootstrap.js" || {
	echo "build_web.sh: flutter_bootstrap.js has no releaseFolder line to rewrite." >&2
	exit 1
}
for ref in 'href="icons/Icon-192.png"' 'href="favicon.png"' 'href="manifest.json"' 'src="flutter_bootstrap.js"'; do
	attr=${ref%%=*}
	file=${ref#*=}
	rewrite build/web/index.html "s|$ref|$attr=\"r/$release/${file#\"}|"
	grep -q "$attr=\"r/$release/${file#\"}" build/web/index.html || {
		echo "build_web.sh: index.html has no $ref to point into the release folder." >&2
		exit 1
	}
done

# 6. Compressed once, here, at the strongest setting: brotli for browsers that take it, gzip for the rest.
# A server that serves precompressed files sends these in place of the file.
find build/web -type f \( -name '*.js' -o -name '*.wasm' -o -name '*.json' -o -name '*.html' -o -name '*.css' \
	-o -name '*.ttf' -o -name '*.otf' -o -name '*.svg' -o -name '*.txt' \) \
	-exec brotli -q 11 -k -f {} + -exec gzip -9 -k -f {} +
echo "build_web.sh: built build/web/r/$release"
