import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review.dart';

void main() {
  test(
    'fundamental review remains advisory and supports three risk states',
    () {
      const review = GeminiFundamentalReview(
        available: true,
        risk: FundamentalRisk.highRisk,
        goldBias: 'mixed',
        summary: 'CPI soon',
        relevantFactors: ['US CPI'],
        model: 'test',
      );
      expect(review.available, isTrue);
      expect(review.risk, FundamentalRisk.highRisk);
      expect(FundamentalRisk.values, hasLength(3));
    },
  );

  test('unavailable AI explicitly preserves candidate semantics', () {
    final review = GeminiFundamentalReview.unavailable(
      model: 'test',
      reason: 'quota',
    );
    expect(review.available, isFalse);
    expect(review.summary, contains('candidate remains valid'));
  });
}
