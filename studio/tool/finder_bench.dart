/* Runs the square finder's Web Worker in headless Chrome on a folder of photos, and reports per photo the
   squares found, the time taken (as it is and with Chrome's CPU slowed down), and, given the Python
   reference's JSON for each photo, how the squares compare with it. It also scores the grouping of repeated
   cloths on a folder of single-square pictures with an answer key, and, with --measure, cuts every found square
   from the photo as the studio would and reads it with the studio's own measure.

   Run in studio/, after tool/prepare_web.sh has compiled web/finder_worker.js:
     dart run tool/finder_bench.dart [--photos DIR] [--reference DIR] [--slow 6] [--runs 1] [--json FILE] [photo.jpg ...]
   --photos     where the photos are (default ~/kantha-finder-photos); read at run time, never copied
   --reference  JSON files named <photo without .jpg>.<anything>.json, each {"squares": [[[x, y] x 4], ...]} in
                the finder's 900 px working picture
   --slow       Chrome's CPU slow-down for the slowed timing (Emulation.setCPUThrottlingRate); 1 skips it
   --chrome     the Chrome to run (default: Google Chrome on a Mac)
   --cells      a folder holding crops/00.png, 01.png … (one cloth square each) and key.json ({"cloth": [picture
                numbers], …}); default <photos>/halloween, skipped when it has no key.json. A <reference>/
                <folder name>.json, {"labels": […]}, is the Python grouping to compare with
   --measure    cut and measure every found square (lib/measure/measure.dart), and print the readings
   With no photo names, every .jpg in --photos. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:kantha_studio/data/numbers.dart' show busyOf;
import 'package:kantha_studio/measure/measure.dart';

Future<void> main(List<String> args) async {
  String opt(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final home = Platform.environment['HOME'] ?? '';
  final photos = Directory(opt('photos', '$home/kantha-finder-photos'));
  final reference = opt('reference', '');
  final slow = int.parse(opt('slow', '6'));
  final runs = int.parse(opt('runs', '1'));
  final chrome = opt('chrome', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome');
  final jsonOut = opt('json', '');
  final cells = Directory(opt('cells', '${photos.path}/halloween'));
  final measure = args.contains('--measure');
  final valued = {'--photos', '--reference', '--slow', '--runs', '--chrome', '--json', '--cells'};
  final named = [
    for (var i = 0; i < args.length; i++)
      if (args[i].startsWith('--')) ...[] else if (i > 0 && valued.contains(args[i - 1])) ...[] else args[i]
  ];
  final names = named.isNotEmpty
      ? named
      : ([for (final f in photos.listSync()) if (f.path.endsWith('.jpg')) f.uri.pathSegments.last]..sort());
  for (final f in ['web/finder_worker.js', 'web/opencv_finder.js']) {
    if (!File(f).existsSync()) {
      stderr.writeln('finder_bench: $f is missing (run tool/prepare_web.sh in studio/).');
      exit(2);
    }
  }

  // Chrome slows a page's own thread, not its workers (measured 30 October 2026: the worker took the same time
  // at 6x). So the slowed timing runs the same compiled worker on the page's thread (page.html), and so does
  // one at 1x, to show the two threads take the same time unslowed.
  final runsOn = [('worker', 1), if (slow > 1) ...[('page', 1), ('page', slow)]];
  final server = await _serve(photos, cells);
  final keyFile = File('${cells.path}/key.json');
  Map<String, dynamic>? cellResult;
  final browser = await _Chrome.start(chrome);
  final results = <String, Map<String, Object?>>{};
  try {
    for (final (where, rate) in runsOn) {
      final page = await browser.page('http://127.0.0.1:${server.port}/$where.html', rate);
      final ready = await page.eval('ready');
      stdout.writeln('$where, CPU ${rate}x: OpenCV.js loaded and started in ${ready}ms');
      for (final name in names) {
        for (var r = 0; r < runs; r++) {
          final cut = measure && where == 'worker' && r == 0;
          final m = jsonDecode(await page.eval('find(${jsonEncode(name)}, $cut)') as String) as Map<String, dynamic>;
          if (m['error'] != null) throw StateError('$name: ${m['error']}');
          final row = results.putIfAbsent(name,
              () => {'name': name, 'squares': m['squares'], 'groups': m['groups'], 'side': m['side'], 'scale': m['scale']});
          if (cut) row['crops'] = m['crops'];
          if (jsonEncode(row['squares']) != jsonEncode(m['squares'])) throw StateError('$name: squares differ between runs');
          ((row['ms $where ${rate}x'] ??= <int>[]) as List<int>).add(m['totalMs'] as int);
          row['parts $where ${rate}x'] =
              'decode ${m['decodeMs']}, outlines ${m['outlineMs']}, lines+checks ${m['linesMs']}, groups ${m['groupMs']}';
          row['fromLines'] = m['fromLines'];
        }
      }
      if (where == 'worker' && keyFile.existsSync()) {
        final n = Directory('${cells.path}/crops').listSync().where((f) => f.path.endsWith('.png')).length;
        cellResult = jsonDecode(await page.eval('group($n)') as String) as Map<String, dynamic>;
        if (cellResult['error'] != null) throw StateError('cells: ${cellResult['error']}');
      }
      await page.close();
    }
  } finally {
    await browser.close();
    await server.close(force: true);
  }

  for (final name in names) {
    final row = results[name]!;
    final web = [for (final q in row['squares'] as List) _corners(q as List)];
    stdout.writeln('\n$name: ${web.length} squares (${row['fromLines']} from lines), side ${(row['side'] as num).round()} px');
    for (final (where, rate) in runsOn) {
      final ms = row['ms $where ${rate}x'] as List<int>;
      stdout.writeln('  $where, CPU ${rate}x: ${ms.map((v) => (v / 1000).toStringAsFixed(2)).join(', ')} s '
          '(last run: ${row['parts $where ${rate}x']} ms)');
    }
    _reportGroups(row, web);
    if (row['crops'] != null) _reportMeasure(row);
    if (reference.isEmpty) continue;
    final stem = name.replaceAll(RegExp(r'\.jpe?g$'), '');
    final refs = Directory(reference).listSync().whereType<File>().where((f) {
      final n = f.uri.pathSegments.last;
      return n.startsWith('$stem.') && n.endsWith('.json');
    }).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in refs) {
      final ref = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final py = [for (final q in ref['squares'] as List) _corners([for (final p in q as List) ...(p as List)])];
      final c = _compare(web, py);
      row['vs ${f.uri.pathSegments.last}'] = c;
      stdout.writeln('  vs ${f.uri.pathSegments.last} (${py.length} squares, ${ref['seconds']} s in Python): '
          '${c['matched']} the same within 5 px, ${c['near']} within 15 px, ${c['extra']} only on the web, '
          '${c['missing']} only in Python; matched corners ${c['mean']} px apart on average, ${c['max']} at most');
      final pyGroups = ref['groups'] as List?;
      if (pyGroups != null) {
        stdout.writeln('    Python made ${pyGroups.toSet().length} groups of its ${py.length} squares; '
            'of the squares both found, the two groupings agree with adjusted Rand index '
            '${_sharedAri(web, row['groups'] as List, py, pyGroups)}');
      }
    }
  }
  if (cellResult != null) _reportCells(cells, keyFile, cellResult, reference);
  if (jsonOut.isNotEmpty) {
    File(jsonOut).writeAsStringSync(jsonEncode([for (final r in results.values) {...r}..remove('crops')]));
  }
}

String _centre(List<math.Point<double>> q) {
  final c = q.reduce((a, b) => a + b) * 0.25;
  return '(${c.x.round()}, ${c.y.round()})';
}

/// The groups the worker made of a photo's squares; every group of more than one square, by centre.
void _reportGroups(Map<String, Object?> row, List<List<math.Point<double>>> web) {
  final groups = (row['groups'] as List).cast<int>();
  final count = groups.toSet().length;
  stdout.writeln('  groups: $count of ${web.length} squares');
  for (var g = 0; g < count; g++) {
    final members = [for (var i = 0; i < groups.length; i++) if (groups[i] == g) i];
    if (members.length < 2) continue;
    stdout.writeln('    joined: ${members.map((i) => 'square $i at ${_centre(web[i])}').join(', ')}');
  }
}

/// Each found square, cut and read by the studio's measure.
void _reportMeasure(Map<String, Object?> row) {
  final crops = (row['crops'] as List).cast<Map<String, dynamic>>();
  final sides = [for (final c in crops) c['side'] as int]..sort();
  stdout.writeln('  cut at ${sides.first} to ${sides.last} px a side (middle ${sides[sides.length ~/ 2]}), '
      'from a picture ${math.min(2560, (900 / (row['scale'] as num)).round())} px on its long side');
  final groups = (row['groups'] as List).cast<int>();
  var prints = 0;
  for (var i = 0; i < crops.length; i++) {
    final side = crops[i]['side'] as int;
    final rgb = base64Decode(crops[i]['rgb'] as String);
    final m = measureImage(img.Image.fromBytes(width: side, height: side, bytes: Uint8List.fromList(rgb).buffer, numChannels: 3));
    stdout.writeln('    square $i (group ${groups[i]}): $side px, L*a*b* ${m.lab.l} ${m.lab.a} ${m.lab.b}, '
        '${m.name}, spread ${m.spread} (${busyOf(m.spread) ? 'print' : 'plain'}), measured on ${m.width} x ${m.height}');
    prints += busyOf(m.spread) ? 1 : 0;
  }
  stdout.writeln('  read as print: $prints of ${crops.length}');
}

/// The adjusted Rand index (Hubert and Arabie) of two labellings of the same items.
double _ari(List<int> a, List<int> b) {
  double pairs(int n) => n * (n - 1) / 2;
  final table = <(int, int), int>{}, rows = <int, int>{}, cols = <int, int>{};
  for (var i = 0; i < a.length; i++) {
    table[(a[i], b[i])] = (table[(a[i], b[i])] ?? 0) + 1;
    rows[a[i]] = (rows[a[i]] ?? 0) + 1;
    cols[b[i]] = (cols[b[i]] ?? 0) + 1;
  }
  final index = table.values.map(pairs).fold(0.0, (x, y) => x + y);
  final ra = rows.values.map(pairs).fold(0.0, (x, y) => x + y), cb = cols.values.map(pairs).fold(0.0, (x, y) => x + y);
  final expected = ra * cb / pairs(a.length), most = (ra + cb) / 2;
  return most == expected ? 1 : (index - expected) / (most - expected);
}

/// The adjusted Rand index of two groupings over the squares both runs found (the same within 5 px).
String _sharedAri(List<List<math.Point<double>>> web, List webGroups, List<List<math.Point<double>>> py, List pyGroups) {
  final a = <int>[], b = <int>[];
  for (var i = 0; i < web.length; i++) {
    for (var j = 0; j < py.length; j++) {
      if (_apart(web[i], py[j]) <= 5) {
        a.add(webGroups[i] as int);
        b.add(pyGroups[j] as int);
        break;
      }
    }
  }
  return '${_ari(a, b).toStringAsFixed(2)} (${a.length} squares)';
}

/// The grouping of single-square pictures against their answer key: squares in the right group (each group's
/// most common cloth counts as right, as the Python scored it) and the adjusted Rand index.
void _reportCells(Directory cells, File keyFile, Map<String, dynamic> result, String reference) {
  final key = (jsonDecode(keyFile.readAsStringSync()) as Map<String, dynamic>).values.toList();
  final groups = (result['groups'] as List).cast<int>();
  final truth = List.filled(groups.length, -1);
  for (var k = 0; k < key.length; k++) {
    for (final i in key[k] as List) {
      truth[i as int] = k;
    }
  }
  var right = 0;
  for (final g in groups.toSet()) {
    final counts = <int, int>{};
    for (var i = 0; i < groups.length; i++) {
      if (groups[i] == g) counts[truth[i]] = (counts[truth[i]] ?? 0) + 1;
    }
    right += counts.values.reduce(math.max);
  }
  final name = cells.uri.pathSegments.where((s) => s.isNotEmpty).last;
  stdout.writeln('\n$name: ${groups.length} squares in ${groups.toSet().length} groups (the key has ${key.length}); '
      '$right in the right group; adjusted Rand index ${_ari(truth, groups).toStringAsFixed(2)}; ${result['totalMs']} ms');
  final ref = File('$reference/$name.json');
  if (reference.isNotEmpty && ref.existsSync()) {
    final py = ((jsonDecode(ref.readAsStringSync()) as Map)['labels'] as List).cast<int>();
    stdout.writeln('  vs Python: ${py.toSet().length} groups; the two groupings agree with adjusted Rand index '
        '${_ari(py, groups).toStringAsFixed(2)}');
  }
}

List<math.Point<double>> _corners(List flat) =>
    [for (var i = 0; i < 8; i += 2) math.Point((flat[i] as num).toDouble(), (flat[i + 1] as num).toDouble())];

/// How far apart two squares are: the furthest any corner of one is from the nearest corner of the other.
double _apart(List<math.Point<double>> a, List<math.Point<double>> b) {
  double one(List<math.Point<double>> x, List<math.Point<double>> y) =>
      x.map((p) => y.map(p.distanceTo).reduce(math.min)).reduce(math.max);
  return math.max(one(a, b), one(b, a));
}

/// Pairs each web square with one Python square, closest first; "the same" within 5 px, "near" within 15.
Map<String, Object> _compare(List<List<math.Point<double>>> web, List<List<math.Point<double>>> py) {
  final pairs = <(double, int, int)>[
    for (var i = 0; i < web.length; i++)
      for (var j = 0; j < py.length; j++) (_apart(web[i], py[j]), i, j)
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final usedW = <int>{}, usedP = <int>{};
  final close = <double>[];
  var near = 0;
  for (final (d, i, j) in pairs) {
    if (d > 15) break;
    if (usedW.contains(i) || usedP.contains(j)) continue;
    usedW.add(i);
    usedP.add(j);
    if (d <= 5) {
      close.add(d);
    } else {
      near++;
    }
  }
  return {
    'matched': close.length, 'near': near, 'extra': web.length - usedW.length, 'missing': py.length - usedP.length,
    'mean': close.isEmpty ? '-' : (close.reduce((a, b) => a + b) / close.length).toStringAsFixed(1),
    'max': close.isEmpty ? '-' : close.reduce(math.max).toStringAsFixed(1),
  };
}

const _common = '''<!doctype html><meta charset="utf-8"><title>finder bench</title><script>
const waiting = {};
let next = 0, readyMs;
const ready = new Promise((r) => { readyMs = r; });
function heard(data) {
  const m = JSON.parse(data);
  if (m.type === 'ready') return readyMs(m.ms);
  waiting[m.id](data);
}
async function find(name, crops) {
  const photo = await (await fetch('/photo/' + encodeURIComponent(name))).arrayBuffer();
  const id = ++next;
  return new Promise((r) => { waiting[id] = r; ask({id, photo, crops}); });
}
async function group(n) {
  const cells = [];
  for (let i = 0; i < n; i++) cells.push(await (await fetch('/cell/' + String(i).padStart(2, '0') + '.png')).arrayBuffer());
  const id = ++next;
  return new Promise((r) => { waiting[id] = r; ask({id, cells}); });
}
</script>''';

/// The finder in its worker, as the studio runs it.
const _workerPage = '''$_common<script>
const worker = new Worker('/finder_worker.js');
worker.onmessage = (e) => heard(e.data);
worker.onerror = (e) => { for (const k in waiting) waiting[k](JSON.stringify({error: e.message || 'worker failed'})); };
const ask = (m) => worker.postMessage(m);
</script>''';

/// The same worker script on the page's own thread: OpenCV.js by a script tag, its messages by hand.
const _threadPage = '''$_common<script>
self.importScripts = () => {};
self.postMessage = heard;
const ask = (m) => self.onmessage({data: m});
</script><script src="/opencv_finder.js"></script><script src="/finder_worker.js"></script>''';

/// The bench page, the worker and OpenCV.js from web/, and the photos and cells from their folders, on 127.0.0.1 only.
Future<HttpServer> _serve(Directory photos, Directory cells) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final path = req.uri.path;
    final res = req.response;
    File? file;
    if (path == '/worker.html' || path == '/page.html') {
      res.headers.contentType = ContentType.html;
      res.write(path == '/worker.html' ? _workerPage : _threadPage);
    } else if (path == '/finder_worker.js' || path == '/opencv_finder.js') {
      file = File('web$path');
      res.headers.contentType = ContentType('text', 'javascript', charset: 'utf-8');
    } else if (path.startsWith('/photo/')) {
      final name = Uri.decodeComponent(path.substring(7));
      if (!name.contains('/')) file = File('${photos.path}/$name');
      res.headers.contentType = ContentType('image', 'jpeg');
    } else if (path.startsWith('/cell/')) {
      final name = Uri.decodeComponent(path.substring(6));
      if (!name.contains('/')) file = File('${cells.path}/crops/$name');
      res.headers.contentType = ContentType('image', 'png');
    }
    if (file != null && file.existsSync()) {
      await res.addStream(file.openRead());
    } else if (!path.endsWith('.html')) {
      res.statusCode = HttpStatus.notFound;
    }
    await res.close();
  });
  return server;
}

/// Headless Chrome over the DevTools protocol.
class _Chrome {
  _Chrome(this._process, this._socket, this._dir) {
    _socket.listen((raw) {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      final id = m['id'];
      if (id != null) {
        final c = _waiting.remove(id);
        if (m['error'] != null) {
          c?.completeError(StateError('${m['error']}'));
        } else {
          c?.complete((m['result'] ?? {}) as Map<String, dynamic>);
        }
      } else {
        for (final l in [..._listeners]) {
          l(m);
        }
      }
    });
  }

  final Process _process;
  final WebSocket _socket;
  final Directory _dir;
  final _waiting = <int, Completer<Map<String, dynamic>>>{};
  final _listeners = <void Function(Map<String, dynamic>)>[];
  var _next = 0;

  static Future<_Chrome> start(String chrome) async {
    final dir = Directory.systemTemp.createTempSync('finder-bench-');
    final p = await Process.start(chrome, [
      '--headless=new', '--remote-debugging-port=0', '--user-data-dir=${dir.path}', '--no-first-run',
      '--no-default-browser-check', 'about:blank',
    ]);
    final url = Completer<String>();
    p.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
      final m = RegExp(r'DevTools listening on (ws://\S+)').firstMatch(l);
      if (m != null && !url.isCompleted) url.complete(m[1]);
    });
    p.stdout.drain<void>();
    return _Chrome(p, await WebSocket.connect(await url.future.timeout(const Duration(seconds: 30))), dir);
  }

  Future<Map<String, dynamic>> send(String method, [Map<String, Object?> params = const {}, String? session]) {
    final id = ++_next;
    final c = _waiting[id] = Completer();
    _socket.add(jsonEncode({'id': id, 'method': method, 'params': params, 'sessionId': ?session}));
    return c.future;
  }

  /// A fresh tab on [url], its CPU slowed [rate] times.
  Future<_Page> page(String url, int rate) async {
    final target = (await send('Target.createTarget', {'url': 'about:blank'}))['targetId'] as String;
    final session = (await send('Target.attachToTarget', {'targetId': target, 'flatten': true}))['sessionId'] as String;
    await send('Emulation.setCPUThrottlingRate', {'rate': rate}, session);
    await send('Page.enable', const {}, session);
    await send('Page.navigate', {'url': url}, session);
    final p = _Page(this, session, target);
    while (await p.eval('typeof find') != 'function') {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return p;
  }

  Future<void> close() async {
    await _socket.close();
    _process.kill();
    await _process.exitCode;
    try {
      _dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Chrome may still hold a file for a moment; the folder is in the system's temporary folder.
    }
  }
}

class _Page {
  _Page(this._chrome, this._session, this._target);
  final _Chrome _chrome;
  final String _session, _target;

  Future<Object?> eval(String expression) async {
    final r = await _chrome.send('Runtime.evaluate', {'expression': expression, 'awaitPromise': true, 'returnByValue': true},
        _session);
    if (r['exceptionDetails'] != null) throw StateError('$expression: ${r['exceptionDetails']}');
    return (r['result'] as Map)['value'];
  }

  Future<void> close() => _chrome.send('Target.closeTarget', {'targetId': _target});
}
