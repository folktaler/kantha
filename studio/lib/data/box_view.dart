/* What a sample box stores in its `name`; her boxes store none. */
const sampleBoxName = 'sample';

/* A box as the studio sees it: its id, the number she sees (none for a sample box), and whether it is the sample. */
class BoxView {
  const BoxView({required this.id, required this.number, required this.sample});
  final int id;
  final int? number;
  final bool sample;
}
