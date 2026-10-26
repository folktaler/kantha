@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/loading.dart';

@JS('document.body.insertAdjacentHTML')
external void _insert(String where, String html);

@JS('document.getElementById')
external JSObject? _byId(String id);

/* web/index.html's loading screen is #loading; the app takes it away once the studio is drawn. */
void main() {
  test('hideLoading takes the loading screen away, and leaves a page without one alone', () {
    _insert('beforeend', '<div id="loading"></div>');
    expect(_byId('loading'), isNotNull);
    hideLoading();
    expect(_byId('loading'), isNull);
    hideLoading();
  });
}
