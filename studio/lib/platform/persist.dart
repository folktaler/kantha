import 'persist_io.dart' if (dart.library.js_interop) 'persist_web.dart' as impl;

/* Spec decision 13: on the web the browser is asked to keep this site's data rather than clear it
   when space runs short. A phone's app keeps its data until the app is removed, so there it is `true`. */
Future<bool> askToKeepStorage() => impl.askToKeepStorage();
