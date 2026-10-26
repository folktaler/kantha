import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../studio/shelf_feed.dart';
import 'smaller_io.dart' if (dart.library.js_interop) 'smaller_web.dart';
import '../platform/report.dart';

/* A 4 cm square at 600 px is 380 ppi on paper; more only makes the file bigger. */
const embedPx = 600;

/* Each cloth's photo as a JPEG small enough to embed in the files, kept by its picture (ClothPhoto: the cloth's id,
   its photo's number, new for every photo stored, its version and when it was added), or by id and version for any other. Her photos are stored at up to 600 px (1500 px before 20 Oct); one
   larger than 600 px is made smaller here: on a phone off the screen's thread, on the web by the browser's own codecs. A photo that
   cannot be read is null, and its squares are drawn plain. */
class ClothImages {
  final _made = <Object, Future<Uint8List?>>{};

  Future<Uint8List?> jpeg(ClothView c) {
    final Object key = c.image is ClothPhoto ? c.image! : '${c.id}@${c.version}';
    return _made[key] ??= _make(c.image).then((b) {
      if (b == null) _made.remove(key); // asked again next time
      return b;
    });
  }

  /* Lets go of every photo made ready: after an import, whose photos are all new. */
  void clear() => _made.clear();

  Future<Uint8List?> _make(ImageProvider? image) async {
    try {
      final bytes = switch (image) {
        ClothPhoto() => await image.bytes(),
        MemoryImage(:final bytes) => bytes,
        _ => null,
      };
      if (bytes == null) return null;
      return await smallerJpeg(bytes);
    } catch (e, st) {
      reportError(e, st, "while a cloth's photo was made ready for a file");
      return null;
    }
  }
}
