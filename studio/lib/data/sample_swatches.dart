/* The Sample box's photos measured (sample_box.dart says what they are). Apart from sample_box.dart so this code is
   loaded (deferred) only when a Sample box is made. The image package it uses is not: measure.dart, which shelf.dart
   imports, loads it with the studio. */
import 'dart:typed_data';
import '../measure/measure.dart';

/* Each photo measured by the same code as a photograph of hers; run through compute. */
List<Measured> measureAll(List<Uint8List> photos) => [for (final p in photos) measureBytes(p)];
