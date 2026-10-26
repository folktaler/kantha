import 'dart:typed_data';

/* A JPEG's size from its frame header, read by walking its segments up to the first scan: the image package's own
   header read (startDecode) builds the frame's coefficient blocks for every pixel, which took about 0.7 s for a 12 MP
   photo and 1.3 s for a 48 MP one at 6x CPU in a phone's browser, twice per photo. Only the frames the package decodes
   (baseline, extended, progressive: SOF0-2), so what passes here the package can read. Null when the bytes are not a
   JPEG, or its segments do not lead to such a frame and then a scan (pickedSize asks the image package then). Apart
   from prepare.dart, and with no image package, so that making the files can ask it (smallerJpeg) without loading
   that package. */
({int width, int height})? jpegSize(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  ({int width, int height})? size;
  var i = 2;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    if (marker == 0xFF) { // a fill byte before a marker
      i++;
      continue;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) { // TEM or RST0-7: a marker alone, with no length
      i += 2;
      continue;
    }
    final end = i + 2 + (b[i + 2] << 8 | b[i + 3]);
    if (end < i + 4 || end > b.length) return null;
    if (marker == 0xDA) return size;
    if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
      // A frame: precision (1 byte), then height and width (2 bytes each).
      if (marker > 0xC2 || size != null || end < i + 9) return null;
      size = (width: b[i + 7] << 8 | b[i + 8], height: b[i + 5] << 8 | b[i + 6]);
    }
    i = end;
  }
  return null;
}
