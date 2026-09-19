import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/candidate_confidence_review.dart';
import 'package:tradeforge_backtesting/src/fundamentals/ai_review_context_audit.dart';
import 'package:tradeforge_backtesting/src/fundamentals/candidate_fundamental_review_service.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_event_context.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_news_context.dart';

void main() {
  FundamentalReviewResult fixture(FundamentalRisk risk, String bias) =>
      FundamentalReviewResult(
        review: GeminiFundamentalReview(
          available: true,
          risk: risk,
          goldBias: bias,
          summary: 'review',
          relevantFactors: const [],
          model: 'test',
        ),
        newsContext: GoldNewsContext(
          observedAtUtc: DateTime.utc(2026, 9, 19),
          items: const [],
          availability: GoldNewsAvailability.available,
          provider: 'test',
        ),
        eventContext: GoldEventContext(
          observedAtUtc: DateTime.utc(2026, 9, 19),
          events: const [],
          risk: GoldEventRisk.normal,
          source: 'test',
        ),
        contextAudit: const AiReviewContextAudit(
          presentCandidateFields: [],
          missingCandidateFields: [],
          newsAvailable: true,
          calendarAvailable: true,
          marketContextAvailable: false,
        ),
        newsCacheHit: true,
        calendarCacheHit: true,
        candidatePreserved: true,
      );

  test('aligned normal 2R candidate is STRONG but uncalibrated', () {
    final value = buildCandidateConfidenceReview(<String, Object?>{
      'side': 'BUY',
      'riskReward': 2.0,
      'regime': 'TREND',
    }, fixture(FundamentalRisk.normal, 'bullish'));
    expect(value.level, CandidateConfidenceLevel.strong);
    expect(value.calibrated, isFalse);
  });

  test('high risk remains STANDARD advisory', () {
    final value = buildCandidateConfidenceReview(<String, Object?>{
      'side': 'BUY',
      'riskReward': 2.5,
    }, fixture(FundamentalRisk.highRisk, 'bullish'));
    expect(value.level, CandidateConfidenceLevel.standard);
    expect(value.cautionReasons, isNotEmpty);
  });

  test('HIGH CONVICTION is reserved before forward calibration', () {
    final value = buildCandidateConfidenceReview(<String, Object?>{
      'side': 'SELL',
      'riskReward': 3.0,
    }, fixture(FundamentalRisk.normal, 'bearish'));
    expect(value.level, isNot(CandidateConfidenceLevel.highConviction));
  });
}
