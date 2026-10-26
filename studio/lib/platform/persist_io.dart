/* A phone's app keeps its database until the app is removed: nothing to ask. */
Future<bool> askToKeepStorage() async => true;
