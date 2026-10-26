/* A library imported `deferred as`, loaded: a load that fails (offline for a moment, or a release gone from the
   server) is asked for once more before the failure goes to whoever asked, who says so in its own words. On the web
   the compiler's own loader has already tried each part a few times; a failed load is forgotten, so this second ask,
   and any later one, fetches it again. */
Future<void> loadTwice(Future<void> Function() load) async {
  try {
    await load();
  } catch (_) {
    await load();
  }
}
