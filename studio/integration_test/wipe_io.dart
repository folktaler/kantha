/* On a phone: the database's file in the app's documents folder, as drift_flutter names it, and its journal. */
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> deleteKantha(String name) async {
  final dir = await getApplicationDocumentsDirectory();
  for (final end in ['', '-journal', '-wal', '-shm']) {
    final f = File('${dir.path}/$name.sqlite$end');
    if (f.existsSync()) f.deleteSync();
  }
}
