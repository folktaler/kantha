import 'dart:js_interop';
import 'browser.dart';

extension type _Navigator._(JSObject _) implements JSObject {
  external String get userAgent;
  /* Only Safari has it: true when the page was opened from the Home Screen. */
  external JSBoolean? get standalone;
}

@JS('navigator')
external _Navigator get _navigator;

bool safariOnIphone() => isSafariOnIphone(_navigator.userAgent, _navigator.standalone?.toDart ?? false);
