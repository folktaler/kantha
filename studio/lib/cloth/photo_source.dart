/* Where a new cloth's photo comes from: the camera or the gallery. The app hands one down
   from its start, so a test can hand in a fixture picture instead. */
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/* The long side a picked photo is brought down to as it is read (his decision, 20 Oct): by readPhoto, with the image
   package's area average on a phone (prepare_io.dart) and the browser's 'high' resize on the web (prepare_web.dart). */
const pickedLongSide = 2560;
/* The long side of the picture the cropper shows (about 1200 px): it is drawn in a 300 px stage, and lays the picture out
   by the size of the one it cuts from (PickedPhoto.parser), so the cut still comes from the whole 2560 px picture. */
const previewLongSide = 1200;

abstract interface class PhotoSource {
  /* The picture's bytes, or null when she backed out. */
  Future<Uint8List?> pick({required bool camera});
}

/* A source that knows the name of the file it last gave, so an error can name it. */
abstract interface class NamedPhotoSource implements PhotoSource {
  String? get lastName;
}

class ImagePickerSource implements NamedPhotoSource {
  ImagePickerSource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  @override
  String? lastName;

  @override
  Future<Uint8List?> pick({required bool camera}) async {
    lastName = null;
    // The picker is not asked to shrink it, on either: image_picker_android shrinks by nearest pixel and saves it again
    // at JPEG quality 100, and image_picker_for_web redraws it through an <img> and a canvas, which converts its colours
    // by an embedded profile. Either would hand the measure other pixels than the other platform. readPhoto brings it
    // down instead, from the file's own numbers.
    final wantsCamera = camera && _picker.supportsImageSource(ImageSource.camera);
    XFile? file;
    try {
      file = await _picker.pickImage(source: wantsCamera ? ImageSource.camera : ImageSource.gallery,
          requestFullMetadata: false);
    } on PlatformException catch (e) {
      // A device with no camera (a simulator) says so when asked: the gallery instead.
      if (!wantsCamera || e.code != 'no_available_camera') rethrow;
      file = await _picker.pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    }
    if (file == null) return null;
    lastName = file.name;
    return file.readAsBytes();
  }
}
