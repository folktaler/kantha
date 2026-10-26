import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/* The journeys in a browser, through chromedriver. A screenshot a test takes (KANTHA_SHOT) is written to
   the folder KANTHA_SHOTS names, else build/integration_shots. */
Future<void> main() => integrationDriver(onScreenshot: (name, bytes, [args]) async {
      final dir = Directory(Platform.environment['KANTHA_SHOTS'] ?? 'build/integration_shots')..createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    });
