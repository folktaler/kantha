import 'package:flutter/foundation.dart';

/* A failure into Flutter's error log: what was being done, and which part of the studio was doing it. */
void reportError(Object e, StackTrace? s, String doing, {String library = 'kantha studio'}) =>
    FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: library, context: ErrorDescription(doing)));
