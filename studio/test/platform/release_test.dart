import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/platform/release.dart';

void main() {
  final studio = Uri.parse('https://kantha.app/studio/');

  test('a release file is an absolute address in its release folder, under the page\'s base', () {
    expect(releaseFile('sqlite3.wasm', studio, 'abc1234').toString(), 'https://kantha.app/studio/r/abc1234/sqlite3.wasm');
    expect(releaseFile('drift_worker.js', studio, 'abc1234').toString(), 'https://kantha.app/studio/r/abc1234/drift_worker.js');
  });

  test('a build with no release keeps its files beside index.html', () {
    expect(releaseFile('sqlite3.wasm', studio, '').toString(), 'https://kantha.app/studio/sqlite3.wasm');
  });

  test('the tests are such a build', () {
    expect(release, isEmpty);
    expect(releaseFile('solver_worker.js', studio).toString(), 'https://kantha.app/studio/solver_worker.js');
  });
}
