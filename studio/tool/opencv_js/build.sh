#!/bin/sh
# Builds web/opencv_finder.js: OpenCV.js holding only the functions the square finder (lib/finder/) calls,
# listed in finder_config.py, with Felzenszwalb's graph segmentation from opencv_contrib's ximgproc.
# The output is committed, so building the studio never needs Emscripten; run this only to change it.
# Run in studio/. Needs git, python3, cmake and make (or ninja), and the network the first time.
#
#   OPENCV_JS_WORK  where the sources, the Emscripten SDK and the build go (default: $HOME/.cache/kantha-opencv-js)
#   EMSDK           an Emscripten SDK already activated; when unset, the pinned one is fetched into the work folder
set -eu

OPENCV_VERSION=4.14.0
EMSDK_VERSION=3.1.74
here=$(cd "$(dirname "$0")" && pwd)
out="$here/../../web/opencv_finder.js"
work=${OPENCV_JS_WORK:-$HOME/.cache/kantha-opencv-js}
mkdir -p "$work"

fetch() { # repository, tag, folder
	[ -d "$work/$3" ] || git clone -q --depth 1 -b "$2" "$1" "$work/$3"
}
fetch https://github.com/opencv/opencv.git "$OPENCV_VERSION" opencv
fetch https://github.com/opencv/opencv_contrib.git "$OPENCV_VERSION" opencv_contrib

if [ -z "${EMSDK:-}" ]; then
	fetch https://github.com/emscripten-core/emsdk.git main emsdk
	"$work/emsdk/emsdk" install "$EMSDK_VERSION"
	"$work/emsdk/emsdk" activate "$EMSDK_VERSION"
	# shellcheck disable=SC1091
	. "$work/emsdk/emsdk_env.sh"
fi

# One wasm file inside the script (OpenCV's default), so the finder's worker loads it with one importScripts.
# Only the modules ximgproc needs are built; the whitelist decides what reaches JavaScript, and the linker
# drops the rest. ximgproc names imgcodecs, which OpenCV.js normally leaves out; it is built with no codecs.
python3 "$work/opencv/platforms/js/build_js.py" "$work/build" \
	--build_wasm \
	--config "$here/finder_config.py" \
	--extra_modules "$work/opencv_contrib/modules/ximgproc" \
	--build_flags "-Oz -s ENVIRONMENT=worker" \
	-DBUILD_LIST=core,imgproc,ximgproc,js \
	-DBUILD_opencv_imgcodecs=ON \
	-DBUILD_TESTS=OFF \
	-DBUILD_PERF_TESTS=OFF \
	-DBUILD_EXAMPLES=OFF

cp "$work/build/bin/opencv.js" "$out"
echo "build.sh: $(wc -c <"$out" | tr -d ' ') bytes in web/opencv_finder.js (OpenCV $OPENCV_VERSION, Emscripten $EMSDK_VERSION)"
