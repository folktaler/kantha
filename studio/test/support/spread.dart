/* The recorded pool's pieces, spread one to each cloth in turn until `total`, never more than a cloth has.
   Its own file so the Chrome solver tests can use it without the fixture's native database. */
List<int> spread(List<int> stock, [int total = 105]) {
  final out = List<int>.filled(stock.length, 0);
  var left = total;
  var gave = true;
  while (left > 0 && gave) {
    gave = false;
    for (var i = 0; i < stock.length && left > 0; i++) {
      if (out[i] < stock[i]) { out[i]++; left--; gave = true; }
    }
  }
  return out;
}
