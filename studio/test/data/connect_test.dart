import 'package:drift_flutter/drift_flutter.dart' show WasmStorageImplementation;
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/data/connect.dart';

void main() {
  test('only memory loses what she makes when the page closes, so only memory is told to her', () {
    expect(WasmStorageImplementation.values.where((i) => !keepsData(i)), [WasmStorageImplementation.inMemory]);
  });

  test('only a new database on OPFS gives back the space of deleted photos: never IndexedDB, never memory', () {
    expect(WasmStorageImplementation.values.where(freesSpace),
        [WasmStorageImplementation.opfsShared, WasmStorageImplementation.opfsLocks]);
  });
}
