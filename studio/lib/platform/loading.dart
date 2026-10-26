import 'loading_io.dart' if (dart.library.js_interop) 'loading_web.dart' as impl;

/* On the web, web/index.html shows a loading screen (#loading) until the studio has something to show:
   its first frame is only its ground, drawn while the shelf opens. The app takes it away after the frame
   that draws the studio, or the page that says it cannot open. */
void hideLoading() => impl.hideLoading();
