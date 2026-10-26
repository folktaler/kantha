import '../solver/geometry.dart' show a4;

/* The paper the sheet is printed on (owner, 26 Oct 2026: Letter beside A4). The panel is the same 5 × 7 squares of
   4 cm on both. Letter is 21.59 × 27.94 cm, and the panel is 28 cm tall: it cannot fit one Letter page either way
   round, so on Letter its rows are split over two pages. Every reader starts on A4 and picks Letter
   in Share (owner, 26 Oct 2026). */
enum Paper { a4, letter }

/* The panel's rows each page holds, top to bottom: all 7 on A4; 4, then 3, on Letter. */
List<({int from, int to})> pagesOf(Paper p) => switch (p) {
      Paper.a4 => [(from: 0, to: a4.rows)],
      Paper.letter => [(from: 0, to: 4), (from: 4, to: a4.rows)],
    };
