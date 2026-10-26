import 'package:flutter_test/flutter_test.dart';
import 'package:kantha_studio/solver/geometry.dart';
import 'package:kantha_studio/solver/layouts.dart';
import 'package:kantha_studio/studio/memory.dart';

const a = Arrangement(grid: [1, 2], rot: [0, 1], seed: 7, name: 'High contrast panel', mount: Mount.none);

void main() {
  test('an arrangement comes back for the same box and template', () {
    final m = remember(const {}, keyOf(3, LayoutKey.contrast), a);
    expect(recall(m, keyOf(3, LayoutKey.contrast)), a);
  });
  test('another box or another template has nothing remembered', () {
    final m = remember(const {}, keyOf(3, LayoutKey.contrast), a);
    expect(recall(m, keyOf(4, LayoutKey.contrast)), isNull);
    expect(recall(m, keyOf(3, LayoutKey.heart)), isNull);
  });
  test('a deleted design is forgotten, and the arrangement it held still shows', () {
    final m = remember(remember(const {}, keyOf(3, LayoutKey.contrast), a.copyWith(savedId: 'gone', savedGrid: 's1')),
        keyOf(3, LayoutKey.heart), a.copyWith(seed: 8, savedId: 'kept', savedGrid: 's2'));
    final after = forget(m, 'gone');
    expect(recall(after, keyOf(3, LayoutKey.contrast)), a);
    expect(recall(after, keyOf(3, LayoutKey.heart)), a.copyWith(seed: 8, savedId: 'kept', savedGrid: 's2'));
    expect(recall(m, keyOf(3, LayoutKey.contrast))!.savedId, 'gone', reason: 'the memory it was given is unchanged');
  });
  test('remembering again replaces, and never changes the memory it was given', () {
    final before = remember(const {}, keyOf(3, LayoutKey.contrast), a);
    final after = remember(before, keyOf(3, LayoutKey.contrast), a.copyWith(seed: 9));
    expect(recall(before, keyOf(3, LayoutKey.contrast))!.seed, 7);
    expect(recall(after, keyOf(3, LayoutKey.contrast))!.seed, 9);
  });
  test('a deleted design\'s arrangement still shows under the name and mount it had', () {
    final m = remember(const {}, keyOf(3, LayoutKey.contrast), a.copyWith(savedId: 'p1', savedGrid: 's1', name: 'For Amma', mount: Mount.frame));
    final after = recall(forget(m, 'p1'), keyOf(3, LayoutKey.contrast))!;
    expect((after.name, after.mount, after.savedId), ('For Amma', Mount.frame, null));
  });
}
