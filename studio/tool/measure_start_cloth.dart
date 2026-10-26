/* Measures the named photos in test/fixtures/start-cloth/ again, with the studio's own measure (measureBytes, as for
   a photo of hers), and writes each one's colour (lab), edge (edgeOf its spread, as for a photo of hers) and the colour
   word of its name into tool/start_cloth.json. For a photo that has been cropped since it was recorded. Everything else
   in the file stays as it was, the busy marks (set by hand) included. The source line names every photo measured so
   far, this run's and earlier runs'. Run in studio/, then tool/start_panels.dart for the home page's panels:
     dart run tool/measure_start_cloth.dart KF-35.jpg KF-36.jpg … */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:kantha_studio/data/numbers.dart' show edgeOf;
import 'package:kantha_studio/measure/measure.dart';
import 'package:kantha_studio/measure/named_colours.dart';

const _note = '; the colour, edge and name of these measured from their photos by tool/measure_start_cloth.dart: ';
// The note as any run wrote it, and the photos it names.
final _anyNote = RegExp(r'; the [^;]* measured from their photos by tool/measure_start_cloth\.dart: (.*)$');

/* The photos the source line names as measured. */
Set<String> measuredPhotos(String source) =>
    (_anyNote.firstMatch(source)?[1] ?? '').split(', ').where((p) => p.isNotEmpty).toSet();

/* The cloth's name with its colour word (a CSS colour name, capitalised) put to `colour`: 'Dimgray 41' and
   'KF-041 Dimgray' keep their form. A name with no colour word, or more than one, is an error. */
String renamed(String name, String colour) {
  final words = name.split(' ');
  final at = [for (var i = 0; i < words.length; i++) if (namedColours.containsKey(words[i].toLowerCase())) i];
  if (at.length != 1) throw ArgumentError('"$name" has ${at.length} colour words; it needs exactly one');
  words[at.single] = colour[0].toUpperCase() + colour.substring(1);
  return words.join(' ');
}

Map<String, dynamic> remeasured(Map<String, dynamic> json, Map<String, List<int>> photos) {
  final cloth = (json['cloth'] as List).cast<Map<String, dynamic>>();
  for (final MapEntry(key: file, value: bytes) in photos.entries) {
    final c = cloth.where((c) => c['photo'] == file).singleOrNull;
    if (c == null) throw ArgumentError('$file is not a photo in start_cloth.json');
    final m = measureBytes(Uint8List.fromList(bytes));
    c['lab'] = [m.lab.l, m.lab.a, m.lab.b];
    c['edge'] = double.parse(edgeOf(m.spread).toStringAsFixed(4)); // spread is to 0.1, so 4 places hold it exactly
    c['name'] = renamed(c['name'] as String, m.name);
  }
  final source = json['source'] as String;
  final measured = {...measuredPhotos(source), ...photos.keys};
  final named = cloth.map((c) => c['photo']).where(measured.contains).join(', ');
  return {...json, 'source': '${source.replaceFirst(_anyNote, '')}$_note$named', 'cloth': cloth};
}

void main(List<String> args) {
  if (args.isEmpty || args.any((a) => a.startsWith('-'))) {
    stderr.writeln('usage: dart run tool/measure_start_cloth.dart <photo in test/fixtures/start-cloth/> …');
    exit(64);
  }
  final file = File('tool/start_cloth.json');
  final out = remeasured(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      {for (final a in args) a: File('test/fixtures/start-cloth/$a').readAsBytesSync()});
  file.writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(out)}\n');
  stdout.writeln('measured ${args.length} photos into ${file.path}');
}
