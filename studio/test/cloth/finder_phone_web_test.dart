/* The phones' finder (opencv_dart, lib/finder/opencv_native.dart) against the web's (OpenCV.js) on the owner's test
   photos: the same pieces, the same cloths, the same tiny outlines and so the same next step. Both find in the same
   pixels: each photo decoded by the image package. The web's answers are test/fixtures/finder/web.json, recorded in
   Chrome on 17 November 2026 by `dart run tool/finder_bench.dart --decode --slow 1 --json …` once for each of the
   three folders (the photos at the top, full/ and workshop-2026-11-10/), then merged under each photo's path.
   The photos are the owner's and are not in the repository: the test reads them from ~/kantha-finder-photos (or
   KANTHA_FINDER_PHOTOS) and is skipped where they are not. Then the isolate finder the sheet uses, once, on one of
   them. A drawn photo checks the phones' OpenCV everywhere, CI too. */
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/cloth/piece_finder.dart';
import 'package:kantha_studio/cloth/piece_finder_io.dart';
import 'package:kantha_studio/cloth/prepare.dart' show PickedPhoto;
import 'package:kantha_studio/finder/finder_session.dart';
import 'package:kantha_studio/finder/opencv_native.dart';

/// The most a corner may move between the two, in the finder's 900 px working picture: "within a few pixels", the
/// build plan's mark. Measured 17 November 2026: every square of 15 photos within 0.01 px; r4-checker's 38 within
/// 4 px, 2 of them found from a line segment the two line detectors give the other way round, so anchored at its
/// other end.
const cornerSlack = 4.0;

void main() {
  final home = Platform.environment['KANTHA_FINDER_PHOTOS'] ??
      '${Platform.environment['HOME']}/kantha-finder-photos';
  final there = Directory(home).existsSync();
  final web = jsonDecode(File('test/fixtures/finder/web.json').readAsStringSync()) as Map<String, dynamic>;

  img.Image picture(String name) =>
      img.decodeImage(File('$home/$name').readAsBytesSync())!.convert(numChannels: 4, format: img.Format.uint8);

  for (final MapEntry(key: name, value: w as Map<String, dynamic>) in web.entries) {
    test('$name: the same pieces, cloths and step as the web', () {
      final p = picture(name);
      final session = FinderSession(OpenCvNative());
      final phone = session.find(p.getBytes(order: img.ChannelOrder.rgba), p.width, p.height);
      session.forget();

      final webSquares = [for (final q in w['squares'] as List) Float32List.fromList((q as List).cast<num>().map((v) => v.toDouble()).toList())];
      final phoneSquares = (phone['squares']! as List).cast<Float32List>();
      expect(phone['tiny'], w['tiny'], reason: 'tiny outlines');
      expect(phoneSquares.length, webSquares.length, reason: 'pieces found');
      // Each web square has its own phone square, every corner within cornerSlack.
      final unmatched = [...phoneSquares];
      final order = <int>[]; // the phone square of each web square, by index into phoneSquares
      var worst = 0.0;
      for (final q in webSquares) {
        final (best, d) = _nearest(q, unmatched);
        expect(d, lessThanOrEqualTo(cornerSlack), reason: 'a square at (${q[0].round()}, ${q[1].round()})');
        worst = math.max(worst, d);
        order.add(phoneSquares.indexOf(best));
        unmatched.remove(best);
      }
      // One cloth on the web is one cloth on the phone: the same partition of the matched squares.
      final webGroups = (w['groups'] as List).cast<int>(), phoneGroups = (phone['groups']! as List).cast<int>();
      expect(_partition([for (final i in order) phoneGroups[i]]), _partition(webGroups), reason: 'cloths');
      // And so the same next step.
      final size = Size(p.width.toDouble(), p.height.toDouble());
      final scale = (phone['scale']! as num).toDouble();
      FinderAnswer answer(List<Float32List> squares, List<int> groups, Map<String, dynamic>? look) => FinderAnswer(
            squares: [for (final q in squares) Float32List.fromList([for (final v in q) v / scale])],
            groups: groups,
            tiny: phone['tiny']! as int,
            look: look == null
                ? null
                : (
                    boxSpread: (look['boxSpread'] as num).toDouble(),
                    ringSpread: (look['ringSpread'] as num).toDouble(),
                    ringVsBox: (look['ringVsBox'] as num).toDouble(),
                    ringVsOutside: (look['ringVsOutside'] as num?)?.toDouble(),
                  ),
          );
      expect(routeOf(answer(phoneSquares, phoneGroups, phone['look'] as Map<String, dynamic>?), size),
          routeOf(answer(webSquares, webGroups, w['look'] as Map<String, dynamic>?), size), reason: 'next step');
      // ignore: avoid_print
      print('$name: ${phoneSquares.length} pieces, ${webGroups.toSet().length} cloths, ${phone['tiny']} tiny, '
          'corners at most ${worst.toStringAsFixed(2)} px apart; ${phone['totalMs']} ms');
    }, skip: there ? false : 'the owner\'s test photos are not on this machine ($home)');
  }

  group('a drawn photo of 9 pieces of 3 cloths, wherever the test runs', () {
    final p = _drawn();
    final rgba = p.getBytes(order: img.ChannelOrder.rgba);

    test('the phones\' OpenCV finds the 9 pieces as 3 cloths', () {
      final session = FinderSession(OpenCvNative());
      final f = session.find(rgba, p.width, p.height);
      expect(f['squares'], hasLength(9));
      expect((f['groups']! as List).toSet(), hasLength(3));
      final cuts = session.cut((f['squares']! as List).cast<Float32List>().take(2).toList());
      for (final (side, b) in cuts) {
        expect(b.length, side * side * 4);
      }
      session.forget();
    });

    test('a picture of the wrong size is refused before OpenCV holds it', () {
      expect(() => FinderSession(OpenCvNative()).find(Uint8List(10), p.width, p.height), throwsArgumentError);
    });

    test('in its isolate, from the picture as the sheet holds it (3 channels)', () async {
      final three = p.convert(numChannels: 3);
      final finder = isolateFinder();
      final a = await finder.find(PickedPhoto(Uint8List(0), p.width, p.height, three));
      expect(a.squares, hasLength(9));
      expect(a.groups.toSet(), hasLength(3));
      expect(await finder.cut(a.squares.take(1).toList()), hasLength(1));
      finder.stop();
      expect((await finder.find(PickedPhoto(Uint8List(0), p.width, p.height, p))).squares, hasLength(9));
      finder.forget();
    });
  });

  test('the sheet\'s finder, in its isolate: find, snap and cut on a many-piece photo', () async {
    const name = 'r3-stacks.jpg';
    final p = picture(name);
    final finder = isolateFinder();
    final photo = PickedPhoto(Uint8List(0), p.width, p.height, p);
    final a = await finder.find(photo);
    final w = web[name] as Map<String, dynamic>;
    expect(a.squares, hasLength((w['squares'] as List).length));
    expect(routeOf(a, Size(p.width.toDouble(), p.height.toDouble())), FoundRoute.check);
    // A tap in the middle of a found piece snaps to a piece there.
    final q = a.squares.first;
    final middle = Offset((q[0] + q[2] + q[4] + q[6]) / 4, (q[1] + q[3] + q[5] + q[7]) / 4);
    expect(await finder.snap(middle), isNotNull);
    // Each piece cut at its own size, as RGBA.
    final cuts = await finder.cut(a.squares.take(3).toList());
    expect(cuts, hasLength(3));
    for (final c in cuts) {
      final side = math.sqrt(c.length / 4).round();
      expect(side * side * 4, c.length);
      expect(side, greaterThan(50));
    }
    // Stopped, it answers the next find from a fresh isolate.
    finder.stop();
    expect((await finder.find(photo)).squares, hasLength(a.squares.length));
    finder.forget();
  }, skip: there ? false : 'the owner\'s test photos are not on this machine ($home)');
}

/// The square in [among] whose corners are nearest [q]'s, and the largest of its 4 corner distances. Which corner comes
/// first does not count: a square found from a line segment starts at the segment's first end, and the two bindings'
/// line detectors can give a segment either way round (r4-checker, 2 of 38 squares).
(Float32List, double) _nearest(Float32List q, List<Float32List> among) {
  Float32List? best;
  var bestD = double.infinity;
  for (final o in among) {
    for (var turn = 0; turn < 8; turn += 2) {
      var d = 0.0;
      for (var k = 0; k < 8; k += 2) {
        final j = (k + turn) % 8;
        d = math.max(d, math.sqrt(math.pow(q[k] - o[j], 2) + math.pow(q[k + 1] - o[j + 1], 2)));
      }
      if (d < bestD) {
        bestD = d;
        best = o;
      }
    }
  }
  return (best ?? Float32List(8), bestD);
}

/// Group numbers as a partition: for each item, the first item of its group.
List<int> _partition(List<int> groups) => [for (final g in groups) groups.indexOf(g)];

/// 9 pieces of 3 cloths, 220 px each and 100 px apart, on a pale table: integration_test/many_pieces_test.dart's.
img.Image _drawn() {
  const cloths = [(178, 34, 52), (32, 52, 110), (214, 160, 30)];
  final photo = img.Image(width: 1400, height: 1100, numChannels: 4)..clear(img.ColorRgba8(236, 230, 214, 255));
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      final (r, g, b) = cloths[(row + col) % 3];
      final x = 160 + col * 320, y = 110 + row * 320;
      img.fillRect(photo, x1: x, y1: y, x2: x + 219, y2: y + 219, color: img.ColorRgba8(r, g, b, 255));
    }
  }
  return photo;
}
