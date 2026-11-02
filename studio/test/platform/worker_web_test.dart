@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/worker_web.dart';
import 'package:web/web.dart' as web;

/* A worker of the page's (worker_web.dart) whose start fails, as one that did not load does, does not end the work:
   the next ask starts another. The stand-in asks the page, on a BroadcastChannel, whether to fail as it starts; one
   that fails throws before it says "ready". */
void main() {
  const script = '''
const line = new BroadcastChannel('worker-web-test');
const asked = [];
let ok = false;
const answer = (m) => postMessage(JSON.stringify({id: JSON.parse(m.data).id, said: 'yes'}));
onmessage = (m) => ok ? answer(m) : asked.push(m);
line.onmessage = (e) => {
  if (e.data === 'fail') throw new Error('did not load');
  if (e.data !== 'ok') return;
  ok = true;
  postMessage('{"type":"ready"}');
  asked.forEach(answer);
};
line.postMessage('started');
''';
  late String url;
  late web.BroadcastChannel line;
  var starts = 0;
  var mode = 'ok';

  setUp(() {
    url = web.URL.createObjectURL(web.Blob(<JSAny>[script.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript')));
    line = web.BroadcastChannel('worker-web-test');
    starts = 0;
    line.onmessage = ((web.MessageEvent e) {
      if ((e.data! as JSString).toDart != 'started') return;
      starts++;
      line.postMessage(mode.toJS);
    }).toJS;
  });
  tearDown(() {
    line.close();
    web.URL.revokeObjectURL(url);
  });

  Future<Object?> ask(PageWorker w) => w.ask((id) => '{"id":$id}'.toJS, wait: const Duration(seconds: 10));

  test('a worker started again (as Stop does) that fails to start: what was asked of it fails; the next ask starts '
      'another, which answers', () async {
    final w = PageWorker(url);
    addTearDown(w.dispose);
    expect(await ask(w), containsPair('said', 'yes'));
    mode = 'fail';
    w.restart();
    await expectLater(ask(w), throwsA(isA<WorkerFailed>()));
    mode = 'ok';
    expect(await ask(w), containsPair('said', 'yes'));
    expect(starts, 3);
  });

  test('restart lets go of what the worker held: each ask fails with WorkerStopped', () async {
    final w = PageWorker(url);
    addTearDown(w.dispose);
    expect(await ask(w), containsPair('said', 'yes'));
    // The stand-in answers at once, so this one is let go before its answer comes.
    final held = ask(w);
    w.restart();
    await expectLater(held, throwsA(isA<WorkerStopped>()));
    expect(await ask(w), containsPair('said', 'yes'));
  });

  test('after dispose nothing is asked, and no worker starts: an ask fails with WorkerStopped', () async {
    final w = PageWorker(url);
    expect(await ask(w), containsPair('said', 'yes'));
    w.dispose();
    await expectLater(ask(w), throwsA(isA<WorkerStopped>()));
    w.post('{"id":0}'.toJS);
    w.warm();
    w.restart();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect((starts, w.running), (1, false));
  });

  test('an ask that cannot be sent fails at once, as the worker gone; a buffer handed over is never sent again',
      () async {
    final w = PageWorker(url);
    addTearDown(w.dispose);
    await expectLater(w.ask((id) => throw StateError('no message')), throwsA(isA<WorkerFailed>()));
    final buffer = JSArrayBuffer(8);
    expect(await w.ask((id) => '{"id":$id}'.toJS, transfer: [buffer]), containsPair('said', 'yes'));
    expect(buffer.toDart.lengthInBytes, 0, reason: 'handed over');
    await expectLater(w.ask((id) => '{"id":$id}'.toJS, transfer: [buffer]), throwsA(isA<WorkerGone>()));
    expect(await ask(w), containsPair('said', 'yes'), reason: 'the worker is as it was');
  });
}
