/* The browser's own image codecs, for photo work the image package would otherwise do in Dart on the page's only
   thread (on the web, compute runs in place): createImageBitmap reads a picture, a canvas crops and sizes it, and
   the canvas's toBlob saves it. An HTMLCanvasElement rather than an OffscreenCanvas: Safari draws on an
   OffscreenCanvas only from 16.4. Only the web build imports this file. */
import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:web/web.dart' as web;

/* createImageBitmap, named so that a test can stand in for a browser that refuses an option. */
@visibleForTesting
Future<web.ImageBitmap> Function(web.ImageBitmapSource source, web.ImageBitmapOptions options) createBitmap =
    (source, options) => web.window.createImageBitmap(source, options).toDart;

/* Which of the options readInBrowser asks for this browser takes: imageOrientation 'from-image' (turn the picture by
   its EXIF; older browsers knew only 'none' and 'flipY') and colorSpaceConversion 'none' (keep the file's own colour
   numbers). A browser refuses a value it does not know with a TypeError, so each is tried once, on a 1 × 1 picture.
   And whether the picture readInBrowser gives is upright by its EXIF: always where 'from-image' is taken; where it is
   not, some browsers turn it anyway (older Chrome did) and some do not, so a 2 × 1 JPEG that names orientation 6 (a
   quarter turn) is read once, as readInBrowser reads, and comes out 1 × 2 from a browser that turns it. */
typedef BitmapOptions = ({bool orientation, bool raw, bool upright});
Future<BitmapOptions>? _takes;
Future<BitmapOptions> bitmapOptions() => _takes ??= () async {
      Future<bool> takes(web.ImageBitmapOptions options) async {
        try {
          (await createBitmap(web.ImageData(1.toJS, 1), options)).close();
          return true;
        } on Object {
          return false;
        }
      }
      final orientation = await takes(web.ImageBitmapOptions(imageOrientation: 'from-image'));
      final raw = await takes(web.ImageBitmapOptions(colorSpaceConversion: 'none'));
      if (orientation) return (orientation: true, raw: raw, upright: true);
      var upright = false;
      try {
        final options = web.ImageBitmapOptions(premultiplyAlpha: 'none');
        if (raw) options.colorSpaceConversion = 'none';
        final probe = await createBitmap(web.Blob(<JSAny>[base64Decode(_turnedProbe).toJS].toJS), options);
        upright = probe.width == 1 && probe.height == 2;
        probe.close();
      } on Object {
        // A browser that cannot read it is not trusted to have turned anything.
      }
      return (orientation: false, raw: raw, upright: upright);
    }();

/* A 2 × 1 grey JPEG whose EXIF names orientation 6: upright, it is 1 × 2. */
const _turnedProbe = '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/2wCEABALDA4MChAODQ4SERATGCgaGBYWGDEjJR0o'
    'OjM9PDkzODdASFxOQERXRTc4UG1RV19iZ2hnPk1xeXBkeFxlZ2MBERISGBUYLxoaL2NCOEJjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2Nj'
    'Y2NjY2NjY2NjY2NjY2NjY2NjY//AABEIAAEAAgMBEQACEQEDEQH/xAGiAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgsQAAIBAwMCBAMFBQQE'
    'AAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hp'
    'anN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+gEA'
    'AwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoLEQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ0'
    '4SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4'
    'ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/ACgD/9k=';

/* A test's: what bitmapOptions found is found again. */
@visibleForTesting
void forgetBitmapOptions() => _takes = null;

/* The picture read by the browser: upright by its EXIF where the browser turns it (bitmapOptions' upright; where it
   does not, the caller turns it), its colours the file's own numbers, not converted by an embedded colour
   profile, as the image package reads them. With `width` or `height`, the browser decodes it at that size, by its
   'high' resize, so a large photo is never held whole; the other side follows the picture's shape. A browser that does
   not know the resize options gives the picture at its own size. Fails when the browser cannot read it. */
Future<web.ImageBitmap> readInBrowser(Uint8List bytes, {int? width, int? height}) async {
  final takes = await bitmapOptions();
  final options = web.ImageBitmapOptions(premultiplyAlpha: 'none');
  if (takes.orientation) options.imageOrientation = 'from-image';
  if (takes.raw) options.colorSpaceConversion = 'none';
  if (width != null) options.resizeWidth = width;
  if (height != null) options.resizeHeight = height;
  if (width != null || height != null) options.resizeQuality = 'high';
  return createBitmap(web.Blob(<JSAny>[bytes.toJS].toJS), options);
}

/* A canvas `width` × `height`, and its 2D context with the browser's best smoothing for any drawing that
   changes a picture's size. */
(web.HTMLCanvasElement, web.CanvasRenderingContext2D) canvasOf(int width, int height) {
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
    ..width = width
    ..height = height;
  final context = canvas.getContext('2d') as web.CanvasRenderingContext2D
    ..imageSmoothingEnabled = true
    ..imageSmoothingQuality = 'high';
  return (canvas, context);
}

/* Lets go of a canvas's pixels now (a 2560 × 1920 canvas holds about 20 MB), rather than at a later garbage
   collection. It is not drawn on after. */
void release(web.HTMLCanvasElement canvas) => canvas
  ..width = 0
  ..height = 0;

/* What the canvas holds, as JPEG at `quality` (0–100), made by the browser. The canvas is released once it is made. */
Future<Uint8List> jpegOf(web.HTMLCanvasElement canvas, int quality) {
  final done = Completer<Uint8List>();
  final (width, height) = (canvas.width, canvas.height);
  canvas.toBlob((web.Blob? blob) {
    release(canvas);
    if (blob == null) {
      done.completeError(StateError('the browser made no JPEG of a $width × $height canvas'));
      return;
    }
    blob.arrayBuffer().toDart.then((b) => done.complete(b.toDart.asUint8List()), onError: done.completeError);
  }.toJS, 'image/jpeg', (quality / 100).toJS);
  return done.future;
}
