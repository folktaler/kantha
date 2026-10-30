/* Runs the square finder's Web Worker in headless Chrome on a folder of photos, and reports per photo the
   squares found, the time taken (as it is and with Chrome's CPU slowed down), and, given the Python
   reference's JSON for each photo, how the squares compare with it.

   Run in studio/, after tool/prepare_web.sh has compiled web/finder_worker.js:
     dart run tool/finder_bench.dart [--photos DIR] [--reference DIR] [--slow 6] [--runs 1] [--json FILE] [photo.jpg ...]
   --photos     where the photos are (default ~/kantha-finder-photos); read at run time, never copied
   --reference  JSON files named <photo without .jpg>.<anything>.json, each {"squares": [[[x, y] x 4], ...]} in
                the finder's 900 px working picture
   --slow       Chrome's CPU slow-down for the slowed timing (Emulation.setCPUThrottlingRate); 1 skips it
   --chrome     the Chrome to run (default: Google Chrome on a Mac)
   With no photo names, every .jpg in --photos. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
  final valued = {'--photos', '--reference', '--slow', '--runs', '--chrome', '--json'};
  final named = [
    for (var i = 0; i < args.length; i++)
      if (valued.contains(args[i])) ...[] else if (i > 0 && valued.contains(args[i - 1])) ...[] else args[i]
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
  final server = await _serve(photos);
  final browser = await _Chrome.start(chrome);
  final results = <String, Map<String, Object?>>{};
  try {
    for (final (where, rate) in runsOn) {
      final page = await browser.page('http://127.0.0.1:${server.port}/$where.html', rate);
      final ready = await page.eval('ready');
      stdout.writeln('$where, CPU ${rate}x: OpenCV.js loaded and started in ${ready}ms');
      for (final name in names) {
        for (var r = 0; r < runs; r++) {
          final m = jsonDecode(await page.eval('find(${jsonEncode(name)})') as String) as Map<String, dynamic>;
          if (m['error'] != null) throw StateError('$name: ${m['error']}');
          final row = results.putIfAbsent(name, () => {'name': name, 'squares': m['squares'], 'side': m['side']});
          if (jsonEncode(row['squares']) != jsonEncode(m['squares'])) throw StateError('$name: squares differ between runs');
          ((row['ms $where ${rate}x'] ??= <int>[]) as List<int>).add(m['totalMs'] as int);
          row['parts $where ${rate}x'] = 'decode ${m['decodeMs']}, outlines ${m['outlineMs']}, lines+checks ${m['linesMs']}';
          row['fromLines'] = m['fromLines'];
        }
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
    }
  }
  if (jsonOut.isNotEmpty) File(jsonOut).writeAsStringSync(jsonEncode(results.values.toList()));
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
async function find(name) {
  const photo = await (await fetch('/photo/' + encodeURIComponent(name))).arrayBuffer();
  const id = ++next;
  return new Promise((r) => { waiting[id] = r; ask({id, photo}); });
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

/// The bench page, the worker and OpenCV.js from web/, and the photos from their folder, on 127.0.0.1 only.
Future<HttpServer> _serve(Directory photos) async {
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
