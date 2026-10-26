/* Writes lib/l10n/app_<lang>.arb for each messages/<lang>.json, and lib/l10n/keyed.g.dart,
   from the one place the studio's words live. en.json is the template. Run in studio/:
     dart run tool/l10n_from_messages.dart           write them, then run `flutter gen-l10n`
     dart run tool/l10n_from_messages.dart --check   exit 1 if any is out of date, or if
                                                   app_localizations*.dart is not what `flutter gen-l10n` makes of the ARBs

   Another language's ARB holds only the words it translates, in en.json's keys; a key it lacks,
   or leaves empty, is left out, and `flutter gen-l10n` writes the English words into that
   language's class in its place. A key en.json no longer has is dropped. A language file is refused,
   with the reason, if it is regional (pt-BR) with no file for its language (pt), if Flutter's own
   widgets have no words in its language, or if a message's placeholders are not English's.

   ICU in, ICU out, with two rewrites gen-l10n needs: `#` in a plural becomes the
   plural's own {name}, and a selector's space before its brace goes. A simple
   {name} is a String (the caller formats a number with jsNum, as String(n) did);
   a plural's count is a num printed with decimalPattern, printed as ICU prints #. */
import 'dart:convert';
import 'dart:io';

const namespaces = ['canvas', 'cloth', 'boxes', 'editBox', 'device'];

String idOf(List<String> path) => path.first + path.skip(1).map((s) => s[0].toUpperCase() + s.substring(1)).join();

class Msg {
  Msg(this.key, this.id, this.text);
  final String key, id, text;
}

void walk(Object? node, List<String> path, List<Msg> all, Map<String, List<String>> lists) {
  if (node is String) { all.add(Msg(path.join('.'), idOf(path), node)); return; }
  if (node is List) {
    final ids = <String>[];
    for (var i = 0; i < node.length; i++) {
      final p = [...path, '$i'];
      all.add(Msg(p.join('.'), idOf(p), node[i] as String));
      ids.add(idOf(p));
    }
    lists[path.join('.')] = ids;
    return;
  }
  (node as Map<String, dynamic>).forEach((k, v) => walk(v, [...path, k], all, lists));
}

final _plural = RegExp(r'\{(\w+),\s*plural,');
final _simple = RegExp(r'\{(\w+)\}');
final _arg = RegExp(r'\{(\w+)[},]');
final _selector = RegExp(r'(=\d+|zero|one|two|few|many|other)\s+\{');

/* Says why, and stops. */
Never refuse(String why) {
  stderr.writeln(why);
  exit(1);
}

/* `file` names the messages file in a refusal. A `#` with no plural is the character itself. */
({String text, Map<String, Object> placeholders}) icu(Msg m, {String file = 'messages/en.json'}) {
  final plurals = {for (final x in _plural.allMatches(m.text)) x.group(1)!};
  var text = m.text.replaceAllMapped(_selector, (x) => '${x.group(1)}{');
  if (text.contains('#') && plurals.isNotEmpty) {
    if (plurals.length > 1) refuse('$file: ${m.key} has # in a message with more than one plural; write the number\'s {name} instead.');
    text = text.replaceAll('#', '{${plurals.single}}');
  }
  // Placeholders in the order they first appear, which is the order of the generated method's parameters.
  final names = <String>{for (final x in _arg.allMatches(text)) x.group(1)!};
  final simples = {for (final x in _simple.allMatches(text)) x.group(1)!};
  return (text: text, placeholders: {
    for (final n in names)
      if (plurals.contains(n)) n: {'type': 'num', 'format': 'decimalPattern'}
      else if (simples.contains(n)) n: {'type': 'String'},
  });
}

/* Runs Flutter's own gen-l10n on the ARBs in a scratch copy of the project's settings and
   returns the generated files that differ from lib/l10n, or that lib/l10n has and it does not make. */
List<String> genL10nBehind(Map<String, String> arbs) {
  final tmp = Directory.systemTemp.createTempSync('l10n_check');
  try {
    File('pubspec.yaml').copySync('${tmp.path}/pubspec.yaml');
    File('l10n.yaml').copySync('${tmp.path}/l10n.yaml');
    Directory('${tmp.path}/lib/l10n').createSync(recursive: true);
    arbs.forEach((path, text) => File('${tmp.path}/$path').writeAsStringSync(text));
    final r = Process.runSync('flutter', ['gen-l10n'], workingDirectory: tmp.path);
    if (r.exitCode != 0) { stderr.write('${r.stdout}${r.stderr}'); exit(1); }
    final made = {
      for (final f in generated(Directory('${tmp.path}/lib/l10n'))) f.uri.pathSegments.last: f.readAsStringSync(),
    };
    return [
      for (final e in made.entries)
        if (!File('lib/l10n/${e.key}').existsSync() || File('lib/l10n/${e.key}').readAsStringSync() != e.value)
          'lib/l10n/${e.key}',
      for (final f in generated(Directory('lib/l10n')))
        if (!made.containsKey(f.uri.pathSegments.last)) 'lib/l10n/${f.uri.pathSegments.last} (no ARB makes it; delete it)',
    ];
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

Iterable<File> generated(Directory d) => d.listSync().whereType<File>().where((f) =>
    f.uri.pathSegments.last.startsWith('app_localizations') && f.uri.pathSegments.last.endsWith('.dart'));

/* The words at a dotted key of en.json in another language's file, or null if it has none there. */
String? lookUp(Map<String, dynamic> words, String key) {
  Object? node = words;
  for (final part in key.split('.')) {
    final i = int.tryParse(part);
    node = switch (node) {
      Map<String, dynamic> m => m[part],
      List<dynamic> l when i != null && i < l.length => l[i],
      _ => null,
    };
  }
  return node is String && node.isNotEmpty ? node : null;
}

/* The languages Flutter's own widgets have words in (flutter_localizations' kMaterialSupportedLanguages), read
   from the SDK that `flutter pub get` named in .dart_tool/package_config.json. */
Set<String> materialLanguages() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) refuse('no .dart_tool/package_config.json — run flutter pub get');
  final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List<dynamic>;
  final root = (packages.firstWhere((p) => p['name'] == 'flutter_localizations') as Map<String, dynamic>)['rootUri'] as String;
  final source = File.fromUri(config.uri.resolve(root.endsWith('/') ? root : '$root/')
      .resolve('lib/src/l10n/generated_material_localizations.dart')).readAsStringSync();
  final list = RegExp(r'kMaterialSupportedLanguages = HashSet<String>\.from\(const <String>\[([^\]]*)\]').firstMatch(source);
  if (list == null) refuse('kMaterialSupportedLanguages not found in flutter_localizations');
  return {for (final x in RegExp(r"'(\w+)'").allMatches(list.group(1)!)) x.group(1)!};
}

String arbOf(Map<String, Object> arb) => '${const JsonEncoder.withIndent('  ').convert(arb)}\n';

/* The same placeholder names, and the same of them plurals. */
bool _sameKeys(Map<String, Object> a, Map<String, Object> b) =>
    a.length == b.length && a.entries.every((e) => b.containsKey(e.key) && '${b[e.key]}' == '${e.value}');

void main(List<String> args) {
  final en = jsonDecode(File('../messages/en.json').readAsStringSync()) as Map<String, dynamic>;
  final all = <Msg>[];
  final lists = <String, List<String>>{};
  for (final ns in namespaces) { walk(en[ns], [ns], all, lists); }

  final arb = <String, Object>{'@@locale': 'en'};
  final plain = <Msg>[];
  for (final m in all) {
    final x = icu(m);
    arb[m.id] = x.text;
    if (x.placeholders.isEmpty) {
      plain.add(m);
    } else {
      arb['@${m.id}'] = {'placeholders': x.placeholders};
    }
  }
  final arbs = {'lib/l10n/app_en.arb': arbOf(arb)};

  final others = [
    for (final f in Directory('../messages').listSync().whereType<File>())
      if (f.path.endsWith('.json') && f.uri.pathSegments.last != 'en.json') f,
  ]..sort((a, b) => a.path.compareTo(b.path));
  final material = others.isEmpty ? const <String>{} : materialLanguages();
  final bases = {'en'};
  for (final f in others) {
    final lang = f.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), '');
    final file = 'messages/${f.uri.pathSegments.last}';
    final base = lang.split('-').first;
    if (base != lang && !File('../messages/$base.json').existsSync()) {
      refuse('$file: a regional language needs its language first; add messages/$base.json, then $file.');
    }
    if (!material.contains(base)) {
      refuse("$file: Flutter's own widgets have no words in '$base' (kMaterialSupportedLanguages), so the studio cannot show it.");
    }
    bases.add(base);
    final words = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final out = <String, Object>{'@@locale': lang.replaceAll('-', '_')};
    for (final m in all) {
      final text = lookUp(words, m.key);
      if (text == null) continue;
      final x = icu(Msg(m.key, m.id, text), file: file);
      final want = icu(m).placeholders;
      if (!_sameKeys(x.placeholders, want)) {
        refuse('$file: ${m.key} has {${x.placeholders.keys.join('}, {')}}; English has {${want.keys.join('}, {')}}.');
      }
      out[m.id] = x.text;
    }
    arbs['lib/l10n/app_${lang.replaceAll('-', '_')}.arb'] = arbOf(out);
  }

  final keyed = StringBuffer('// GENERATED by tool/l10n_from_messages.dart from messages/en.json — do not edit.\n')
    ..writeln("import 'app_localizations.dart';")
    ..writeln()
    ..writeln('/* A message with no placeholders, by its key in en.json. */')
    ..writeln('String? plainByKey(L l, String key) => switch (key) {');
  for (final m in plain) { keyed.writeln("      '${m.key}' => l.${m.id},"); }
  keyed
    ..writeln('      _ => null,')
    ..writeln('    };')
    ..writeln()
    ..writeln('/* A list in en.json (a template\'s "how"), by its key. */')
    ..writeln('List<String> listByKey(L l, String key) => switch (key) {');
  lists.forEach((k, ids) => keyed.writeln("      '$k' => [${ids.map((i) => 'l.$i').join(', ')}],"));
  keyed
    ..writeln('      _ => const <String>[],')
    ..writeln('    };');

  final files = {...arbs, 'lib/l10n/keyed.g.dart': keyed.toString()};
  // An ARB whose messages file is gone, and in write mode the class gen-l10n made of it.
  final gone = Directory('lib/l10n').existsSync()
      ? [
          for (final f in Directory('lib/l10n').listSync().whereType<File>())
            if (f.path.endsWith('.arb') && !files.containsKey('lib/l10n/${f.uri.pathSegments.last}')) f,
        ]
      : <File>[];
  final made = {'app_localizations.dart', for (final b in bases) 'app_localizations_$b.dart'};
  final orphans = Directory('lib/l10n').existsSync()
      ? [for (final f in generated(Directory('lib/l10n'))) if (!made.contains(f.uri.pathSegments.last)) f]
      : <File>[];
  if (args.contains('--check')) {
    final stale = [
      for (final e in files.entries) if (!File(e.key).existsSync() || File(e.key).readAsStringSync() != e.value) e.key,
      for (final f in gone) 'lib/l10n/${f.uri.pathSegments.last} (no messages file makes it)',
    ];
    if (stale.isNotEmpty) { stderr.writeln('out of date: ${stale.join(', ')} — run dart run tool/l10n_from_messages.dart'); exit(1); }
    final behind = genL10nBehind(arbs);
    if (behind.isNotEmpty) { stderr.writeln('out of date: ${behind.join(', ')} — run flutter gen-l10n'); exit(1); }
    return;
  }
  Directory('lib/l10n').createSync(recursive: true);
  for (final f in [...gone, ...orphans]) { f.deleteSync(); }
  files.forEach((path, text) => File(path).writeAsStringSync(text));
}
