/* The file's name: her design's name in letters and dashes.
   Dart has no Unicode normaliser to take accents off, so the accented
   Latin letters a name is likely to hold are folded by this table. */
const _fold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ý': 'y', 'ÿ': 'y',
};

String fileName(String name, String ext) {
  final folded = name.toLowerCase().split('').map((ch) => _fold[ch] ?? ch).join();
  var slug = folded.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 60) slug = slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '');
  return '${slug.isEmpty ? 'design' : slug}.$ext';
}
