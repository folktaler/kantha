import 'dart:io';
import 'package:flutter/services.dart';

/* The bundled faces, so a width measured here is the width the browser draws. */
Future<void> loadFonts() async {
  final face = FontLoader('Public Sans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final f = File('assets/fonts/PublicSans-$w.ttf');
    if (f.existsSync()) face.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await face.load();
  final geist = FontLoader('Geist');
  for (final w in ['Regular', 'Medium', 'SemiBold']) {
    final f = File('assets/fonts/Geist-$w.ttf');
    if (f.existsSync()) geist.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await geist.load();
  final serif = FontLoader('Newsreader');
  final f = File('assets/fonts/Newsreader-Regular.ttf');
  if (f.existsSync()) serif.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await serif.load();
}
