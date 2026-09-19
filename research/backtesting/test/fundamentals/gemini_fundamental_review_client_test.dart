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
        supportPercent: 18,
        opposePercent: 82,
        model: 'test',
      );
      expect(review.available, isTrue);
      expect(review.risk, FundamentalRisk.highRisk);
      expect(review.supportPercent, 18);
      expect(review.opposePercent, 82);
      expect(FundamentalRisk.values, hasLength(3));
    },
  );

  test(
    '95 percent opposition is review data and does not invalidate candidate',
    () {
      const review = GeminiFundamentalReview(
        available: true,
        risk: FundamentalRisk.highRisk,
        goldBias: 'bearish',
        summary: 'High event risk',
        relevantFactors: ['US CPI'],
        supportPercent: 5,
        opposePercent: 95,
        model: 'test',
      );

      expect(review.available, isTrue);
      expect(review.supportPercent, 5);
      expect(review.opposePercent, 95);
    },
  );

  test('unavailable AI explicitly preserves candidate semantics', () {
    final review = GeminiFundamentalReview.unavailable(
      model: 'test',
      reason: 'quota',
    );
    expect(review.available, isFalse);
    expect(review.supportPercent, isNull);
    expect(review.opposePercent, isNull);
    expect(review.summary, contains('candidate remains valid'));
  });
}
