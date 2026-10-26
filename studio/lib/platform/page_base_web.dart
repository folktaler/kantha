import 'dart:js_interop';

@JS('document.baseURI')
external JSString get _baseUri;

Uri pageBase() => Uri.parse(_baseUri.toDart);
