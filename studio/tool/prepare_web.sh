#!/bin/sh
# Puts what the web build needs beside index.html: sqlite3.wasm and drift_worker.js
# from the drift release matching the drift version pubspec.lock resolved, as drift's
# web docs direct (and a copy beside the web backup test), and the solver's worker compiled
# from Dart (Task 10). Run in studio/.
set -eu
v=$(awk '/^  drift:$/{f=1} f && /version:/{gsub(/"/, "", $2); print $2; exit}' pubspec.lock)
base="https://github.com/simolus3/drift/releases/download/drift-$v"
curl -fL -o web/sqlite3.wasm "$base/sqlite3.wasm"
curl -fL -o web/drift_worker.js "$base/drift_worker.js"
# The Chrome test of a backup (test/data/backup_web_test.dart) loads it beside itself.
cp web/sqlite3.wasm test/data/sqlite3.wasm
dart compile js -O4 -o web/solver_worker.js web/solver_worker.dart
