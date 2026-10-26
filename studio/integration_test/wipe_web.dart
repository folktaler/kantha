/* In a browser: drift's own deleteDatabase, for every copy of it the browser holds (OPFS or IndexedDB). */
import 'package:drift/wasm.dart';

Future<void> deleteKantha(String name) async {
  final probe = await WasmDatabase.probe(sqlite3Uri: Uri.parse('sqlite3.wasm'), driftWorkerUri: Uri.parse('drift_worker.js'),
      databaseName: name);
  for (final existing in probe.existingDatabases) {
    if (existing.$2 == name) await probe.deleteDatabase(existing);
  }
}
