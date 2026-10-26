import 'dart:js_interop';

extension type _Element(JSObject _) implements JSObject {
  external void remove();
}

@JS('document.getElementById')
external _Element? _byId(String id);

void hideLoading() => _byId('loading')?.remove();
