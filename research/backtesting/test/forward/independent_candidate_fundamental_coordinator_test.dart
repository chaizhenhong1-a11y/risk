import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/independent_candidate_fundamental_coordinator.dart';
import 'package:tradeforge_backtesting/src/fundamentals/candidate_fundamental_review_service.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_event_context.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_news_context.dart';

void main() {
  test('reviews independent candidate once and skips same exposure', () async {
    var newsCalls = 0;
    var aiCalls = 0;
    final service = CandidateFundamentalReviewService(
      loadNews: (now) async {
        newsCalls++;
        return GoldNewsContext(
          observedAtUtc: now,
          items: const [],
          availability: GoldNewsAvailability.available,
          provider: 'test',
        );
      },
      loadEvents: (now) async => GoldEventContext(
        observedAtUtc: now,
        events: const [],
        risk: GoldEventRisk.normal,
        source: 'test',
      ),
      review: (_, _, _) async {
        aiCalls++;
        return const GeminiFundamentalReview(
          available: true,
          risk: FundamentalRisk.normal,
          goldBias: 'unclear',
          summary: 'No material risk.',
          relevantFactors: [],
          model: 'test',
        );
      },
    );
    final coordinator = IndependentCandidateFundamentalCoordinator(service);
    final now = DateTime.utc(2026, 9, 18);
    final history = <Map<String, Object?>>[
      {
        'id': 'A|1',
        'strategy': 'A',
        'observedAt': now.toIso8601String(),
        'independentEvidence': true,
      },
      {
        'id': 'A|2',
        'strategy': 'A',
        'observedAt': now.add(const Duration(minutes: 5)).toIso8601String(),
        'independentEvidence': false,
      },
    ];

    await coordinator.enrich(history);
    await coordinator.enrich(history);

    expect(history.first['fundamentalReview'], isNotNull);
    expect(history.last['fundamentalReview'], isNull);
    expect(coordinator.reviewedIndependentCandidateCount, 1);
    expect(newsCalls, 1);
    expect(aiCalls, 1);
  });
}
