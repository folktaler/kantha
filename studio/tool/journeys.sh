#!/bin/sh
# The two journeys in Chrome: integration_test/journey_test.dart and backup_test.dart, driven by flutter drive
# through chromedriver. Run in studio/. Stops at the first journey that fails.
#
# The Chrome is CHROME_EXECUTABLE, the one the Chrome step of the checks also uses. Its chromedriver must be the
# same version, so it is fetched to match with Chrome for Testing's own installer, @puppeteer/browsers, into
# ~/.cache/kantha-browsers (once; after that the installer finds it there). It needs the network the first time.
#
# flutter drive builds into build/web, over whatever is there: the deploy script runs this before the studio's build.
set -eu
chrome=${CHROME_EXECUTABLE:?journeys.sh: set CHROME_EXECUTABLE to the Chrome to drive (CONTRIBUTING.md)}

# What the app needs beside index.html: sqlite3.wasm, drift_worker.js, the solver's worker.
flutter pub get
./tool/prepare_web.sh

# "Google Chrome for Testing 154.0.8037.92" → 154.0.8037.92
version=$("$chrome" --version | awk '{print $NF}')
driver=$(npx -y @puppeteer/browsers@3.2.5 install "chromedriver@$version" --path "$HOME/.cache/kantha-browsers" \
	--format '{{path}}')
# flutter drive talks to whatever answers on 4444, so another chromedriver there, of another version, would be used.
if curl -sf http://localhost:4444/status >/dev/null; then
	echo "journeys.sh: something already answers on port 4444; stop it (pkill chromedriver), then run this again." >&2
	exit 1
fi
mkdir -p build
"$driver" --port=4444 >build/chromedriver.log 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do
	curl -sf http://localhost:4444/status >/dev/null && break
	sleep 1
done
kill -0 "$pid" 2>/dev/null && curl -sf http://localhost:4444/status >/dev/null || {
	echo "journeys.sh: chromedriver $version did not start on port 4444 (build/chromedriver.log says why)." >&2
	exit 1
}

for journey in journey backup; do
	flutter drive --driver=test_driver/integration_test.dart --target="integration_test/${journey}_test.dart" \
		-d web-server --chrome-binary="$chrome" --profile --browser-dimension=1360,1000
done
