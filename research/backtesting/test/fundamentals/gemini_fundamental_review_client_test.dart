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
        supportExplanation: '策略结构仍有部分支持。',
        opposeExplanation: '重要数据临近，短线风险较高。',
        model: 'test',
      );
      expect(review.available, isTrue);
      expect(review.risk, FundamentalRisk.highRisk);
      expect(review.supportPercent, 18);
      expect(review.opposePercent, 82);
      expect(review.supportExplanation, isNotEmpty);
      expect(review.opposeExplanation, isNotEmpty);
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
        supportExplanation: '仍保留少量技术支持。',
        opposeExplanation: '事件风险明显高于支持因素。',
        model: 'test',
      );

      expect(review.available, isTrue);
      expect(review.supportPercent, 5);
      expect(review.opposePercent, 95);
      expect(review.opposeExplanation, contains('风险'));
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
    expect(review.supportExplanation, isEmpty);
    expect(review.opposeExplanation, isEmpty);
    expect(review.summary, contains('candidate remains valid'));
  });
}
