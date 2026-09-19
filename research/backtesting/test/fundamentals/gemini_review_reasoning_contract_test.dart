import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('Gemini prompt defines evidence order and stale-context semantics', () {
    final source = File(
      'lib/src/fundamentals/gemini_fundamental_review_client.dart',
    ).readAsStringSync();
    expect(source, contains('M5/M15/H1/H4 marketContext'));
    expect(source, contains('Read contextFreshness'));
    expect(source, contains('marked stale'));
    expect(source, contains('review balance, not a measured probability'));
    expect(source, contains('95%+'));
    expect(source, contains('MUST NOT invalidate or gate'));
  });
}
