@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app\'s word files are what en.json makes today', () async {
    final r = await Process.run('dart', ['run', 'tool/l10n_from_messages.dart', '--check']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('a stale app_localizations_en.dart makes --check fail', () async {
    final f = File('lib/l10n/app_localizations_en.dart');
    final good = f.readAsStringSync();
    try {
      f.writeAsStringSync(good.replaceFirst("'Save'", "'Sav3'"));
      final r = await Process.run('dart', ['run', 'tool/l10n_from_messages.dart', '--check']);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stderr}', contains('app_localizations_en.dart'));
    } finally {
      f.writeAsStringSync(good);
    }
  });

  /* The tool, gen-l10n and test/l10n/ml_probe.dart, run in a copy of the studio whose messages/ holds en.json and
     test/l10n/ml.json: a language file with 4 of en.json's keys. Tagged l10n-probe: `flutter test` leaves it out
     (dart_test.yaml skips it), and it runs before each release with
     `flutter test --tags l10n-probe --run-skipped`. */
  test('a second language file makes its own ARB and class, and the studio shows it, in English where it has no words',
      () async {
    final tmp = Directory.systemTemp.createTempSync('l10n_lang');
    try {
      final studio = '${tmp.path}/studio';
      Directory('${tmp.path}/messages').createSync();
      File('../messages/en.json').copySync('${tmp.path}/messages/en.json');
      File('test/l10n/ml.json').copySync('${tmp.path}/messages/ml.json');
      Directory(studio).createSync();
      for (final f in ['pubspec.yaml', 'pubspec.lock', 'l10n.yaml', 'analysis_options.yaml', 'build.yaml', 'dart_test.yaml']) {
        File(f).copySync('$studio/$f');
      }
      for (final d in ['lib', 'test', 'tool', 'assets']) { _copy(Directory(d), '$studio/$d'); }
      File('test/l10n/ml_probe.dart').copySync('$studio/test/l10n/ml_probe_test.dart');
      Future<ProcessResult> tool([List<String> more = const []]) =>
          Process.run('dart', ['run', 'tool/l10n_from_messages.dart', ...more], workingDirectory: studio);

      var r = await tool();
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final arb = jsonDecode(File('$studio/lib/l10n/app_ml.arb').readAsStringSync()) as Map<String, dynamic>;
      expect(arb.keys, ['@@locale', 'canvasSave', 'canvasPanelName', 'canvasSavedFirst', 'canvasAddMore']);
      expect(arb['canvasPanelName'], 'ഡിസൈൻ #');
      expect(arb['canvasAddMore'], contains('other{{n} കഷണങ്ങൾ'));

      r = await Process.run('flutter', ['gen-l10n'], workingDirectory: studio);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final ml = File('$studio/lib/l10n/app_localizations_ml.dart').readAsStringSync();
      expect(ml, contains("String get canvasSave => 'സേവ് ചെയ്യുക';"));
      expect(ml, contains("String get canvasDuplicate => 'Duplicate';"));
      expect(ml, contains('Delete “\$name”? This cannot be undone.'));
      expect(File('$studio/lib/l10n/app_localizations.dart').readAsStringSync(), contains("Locale('ml')"));

      r = await Process.run('flutter', ['test', 'test/l10n/ml_probe_test.dart'], workingDirectory: studio);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect('${r.stdout}', contains('+2: All tests passed!'));

      r = await tool(['--check']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');

      // Refused, each with the file and the reason.
      final refusals = {
        'pt-BR.json': ('{"canvas": {"save": "Salvar"}}', 'add messages/pt.json'),
        'tlh.json': ('{"canvas": {"save": "Qap"}}', "no words in 'tlh'"),
        'ta.json': ('{"canvas": {"deleteSure": "{nom} நீக்கவா?"}}', 'canvas.deleteSure has {nom}; English has {name}'),
      };
      for (final e in refusals.entries) {
        final f = File('${tmp.path}/messages/${e.key}')..writeAsStringSync(e.value.$1);
        r = await tool(['--check']);
        expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
        expect('${r.stderr}', allOf(contains('messages/${e.key}'), contains(e.value.$2)));
        f.deleteSync();
      }

      // Its messages file gone: --check names the ARB, and writing deletes the ARB and its class.
      File('${tmp.path}/messages/ml.json').deleteSync();
      r = await tool(['--check']);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect('${r.stderr}', contains('app_ml.arb'));
      r = await tool();
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(File('$studio/lib/l10n/app_ml.arb').existsSync(), isFalse);
      expect(File('$studio/lib/l10n/app_localizations_ml.dart').existsSync(), isFalse);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }, tags: 'l10n-probe', timeout: const Timeout(Duration(minutes: 5)));

  test('every word of the studio\'s namespaces is in the app', () {
    final en = jsonDecode(File('../messages/en.json').readAsStringSync()) as Map<String, dynamic>;
    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    var count = 0;
    void walk(Object? node, List<String> path) {
      if (node is String) {
        final id = path.first + path.skip(1).map((s) => s[0].toUpperCase() + s.substring(1)).join();
        expect(arb.containsKey(id), isTrue, reason: path.join('.'));
        count++;
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) { walk(node[i], [...path, '$i']); }
      } else {
        (node as Map<String, dynamic>).forEach((k, v) => walk(v, [...path, k]));
      }
    }
    for (final ns in ['canvas', 'cloth', 'boxes', 'editBox', 'device']) { walk(en[ns], [ns]); }
    expect(count, greaterThan(150));
  });
}

void _copy(Directory from, String to) {
  for (final e in from.listSync(recursive: true)) {
    if (e is File) File(e.path).copySync((File('$to/${e.path.substring(from.path.length + 1)}')..parent.createSync(recursive: true)).path);
  }
}
