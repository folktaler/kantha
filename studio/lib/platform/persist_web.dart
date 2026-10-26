import 'dart:js_interop';

@JS('navigator.storage.persist')
external JSPromise<JSBoolean> _persist();

/* Spec decision 13: ask the browser to keep this site's data. It may say no; she is told either way. */
Future<bool> askToKeepStorage() async {
  try {
    return (await _persist().toDart).toDart;
  } catch (_) {
    return false;
  }
}
