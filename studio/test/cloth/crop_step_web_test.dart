@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'crop_step_test.dart' as cropper;

/* The cropper's test on the web's path (prepare_web.dart): the browser's 1200 px preview and its 2560 px picture. */
void main() => cropper.main();
