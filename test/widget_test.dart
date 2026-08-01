import 'package:flutter_test/flutter_test.dart';

import 'package:bible_xpress/data/books_data.dart';

void main() {
  test('KJV canon has 66 books', () {
    expect(kAllBooks.length, 66);
    expect(kOldTestament.length, 39);
    expect(kNewTestament.length, 27);
    expect(chapterCount('Genesis'), 50);
    expect(chapterCount('Revelation'), 22);
  });
}
