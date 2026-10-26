import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/* Where a backup file comes from: the device's file picker, or a fixture in a test. */
abstract interface class Files {
  Future<({String name, Uint8List bytes})?> pickBackup();
}

/* file_picker 13.1.0: one file, any type — a `.kantha` filter would need the type registered on iOS. */
class PickerFiles implements Files {
  const PickerFiles();
  @override
  Future<({String name, Uint8List bytes})?> pickBackup() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null; // she cancelled
    return (name: file.name, bytes: await file.readAsBytes());
  }
}
