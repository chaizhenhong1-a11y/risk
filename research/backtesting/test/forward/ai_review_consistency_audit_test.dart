import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/ai_review_consistency_audit.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review.dart';

GeminiFundamentalReview review(int support) => GeminiFundamentalReview(
  available: true,
  risk: FundamentalRisk.normal,
  goldBias: 'unclear',
  summary: 'review',
  relevantFactors: const [],
  supportPercent: support,
  opposePercent: 100 - support,
  model: 'test',
);

void main() {
  test('flags large swing only for comparable strategy and side', () {
    final audit = auditAiReviewConsistency(
      candidate: const {'strategy': 'A', 'side': 'BUY'},
      current: review(35),
      previousCandidate: const {'strategy': 'A', 'side': 'BUY'},
      previous: review(80),
    );

    expect(audit.comparable, isTrue);
    expect(audit.supportDelta, 45);
    expect(audit.largeSwing, isTrue);
  });

  test('different side is not treated as inconsistent', () {
    final audit = auditAiReviewConsistency(
      candidate: const {'strategy': 'A', 'side': 'SELL'},
      current: review(20),
      previousCandidate: const {'strategy': 'A', 'side': 'BUY'},
      previous: review(80),
    );

    expect(audit.comparable, isFalse);
    expect(audit.largeSwing, isFalse);
  });

  test('audit is advisory and never changes review percentages', () {
    final current = review(5);
    final audit = auditAiReviewConsistency(
      candidate: const {'strategy': 'C5', 'side': 'BUY'},
      current: current,
      previousCandidate: const {'strategy': 'C5', 'side': 'BUY'},
      previous: review(90),
    );

    expect(audit.largeSwing, isTrue);
    expect(current.supportPercent, 5);
    expect(current.opposePercent, 95);
    expect(audit.toJson()['advisoryOnly'], isTrue);
  });
}
