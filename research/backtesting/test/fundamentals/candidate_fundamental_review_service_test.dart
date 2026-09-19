import 'package:test/test.dart';

import 'package:tradeforge_backtesting/src/fundamentals/candidate_fundamental_review_service.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_event_context.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_news_context.dart';

void main() {
  test('multiple candidates reuse news inside TTL', () async {
    var newsCalls = 0;
    var eventCalls = 0;
    var reviewCalls = 0;
    final start = DateTime.utc(2026, 9, 18, 12);

    final service = CandidateFundamentalReviewService(
      loadNews: (now) async {
        newsCalls++;
        return GoldNewsContext(
          observedAtUtc: now,
          items: const [],
          availability: GoldNewsAvailability.available,
          provider: 'alpha_vantage',
        );
      },
      loadEvents: (now) async {
        eventCalls++;
        return GoldEventContext(
          observedAtUtc: now,
          events: const [],
          risk: GoldEventRisk.normal,
          source: 'finance_calendar',
        );
      },
      review: (candidate, calendar, news) async {
        reviewCalls++;
        return const GeminiFundamentalReview(
          available: true,
          risk: FundamentalRisk.normal,
          goldBias: 'unclear',
          summary: 'No material supplied risk.',
          relevantFactors: [],
          model: 'test',
        );
      },
    );

    final first = await service.reviewIndependentCandidate(
      candidate: const {'strategy': 'C5', 'side': 'BUY'},
      nowUtc: start,
    );
    final second = await service.reviewIndependentCandidate(
      candidate: const {'strategy': 'NR7_BREAKOUT', 'side': 'SELL'},
      nowUtc: start.add(const Duration(minutes: 10)),
    );

    expect(first.newsCacheHit, isFalse);
    expect(second.newsCacheHit, isTrue);
    expect(second.calendarCacheHit, isTrue);
    expect(newsCalls, 1);
    expect(eventCalls, 1);
    expect(reviewCalls, 2);
    expect(second.candidatePreserved, isTrue);
    expect(second.contextAudit.candidateCoreComplete, isFalse);
  });

  test('complete review input is audited without gating candidate', () async {
    final now = DateTime.utc(2026, 9, 18, 12);
    final service = CandidateFundamentalReviewService(
      loadNews: (at) async => GoldNewsContext(
        observedAtUtc: at,
        items: const [],
        availability: GoldNewsAvailability.available,
        provider: 'alpha_vantage',
      ),
      loadEvents: (at) async => GoldEventContext(
        observedAtUtc: at,
        events: const [],
        risk: GoldEventRisk.normal,
        source: 'finance_calendar',
      ),
      review: (_, _, _) async =>
          GeminiFundamentalReview.unavailable(model: 'test', reason: 'test'),
    );

    final result = await service.reviewIndependentCandidate(
      candidate: const {
        'strategy': 'C5',
        'side': 'BUY',
        'entry': 3700.0,
        'stopLoss': 3690.0,
        'takeProfit': 3720.0,
        'riskReward': 2.0,
        'reason': 'trigger',
        'exposureStatus': 'independent',
      },
      nowUtc: now,
    );

    expect(result.contextAudit.candidateCoreComplete, isTrue);
    expect(result.contextAudit.newsAvailable, isTrue);
    expect(result.contextAudit.calendarAvailable, isTrue);
    expect(result.contextAudit.marketContextAvailable, isFalse);
    expect(result.contextAudit.coverage, 'PARTIAL');
    expect(result.candidatePreserved, isTrue);
  });

  test('expired news TTL refreshes provider once', () async {
    var newsCalls = 0;
    final start = DateTime.utc(2026, 9, 18, 12);
    final service = CandidateFundamentalReviewService(
      newsTtl: const Duration(minutes: 45),
      loadNews: (now) async {
        newsCalls++;
        return GoldNewsContext(
          observedAtUtc: now,
          items: const [],
          availability: GoldNewsAvailability.available,
          provider: 'alpha_vantage',
        );
      },
      loadEvents: (now) async => GoldEventContext(
        observedAtUtc: now,
        events: const [],
        risk: GoldEventRisk.normal,
        source: 'finance_calendar',
      ),
      review: (candidate, calendar, news) async =>
          GeminiFundamentalReview.unavailable(model: 'test', reason: 'test'),
    );

    await service.reviewIndependentCandidate(
      candidate: const {'strategy': 'A'},
      nowUtc: start,
    );
    final result = await service.reviewIndependentCandidate(
      candidate: const {'strategy': 'C5'},
      nowUtc: start.add(const Duration(minutes: 46)),
    );

    expect(newsCalls, 2);
    expect(result.newsCacheHit, isFalse);
    expect(result.candidatePreserved, isTrue);
  });

  test('provider and AI failures are fail-open', () async {
    final now = DateTime.utc(2026, 9, 18, 12);
    final service = CandidateFundamentalReviewService(
      loadNews: (_) async => throw StateError('news down'),
      loadEvents: (_) async => throw StateError('calendar down'),
      review: (_, _, _) async => throw StateError('gemini down'),
    );

    final result = await service.reviewIndependentCandidate(
      candidate: const {'strategy': 'C5', 'side': 'BUY'},
      nowUtc: now,
    );

    expect(result.candidatePreserved, isTrue);
    expect(result.newsContext.isAvailable, isFalse);
    expect(result.eventContext.risk, GoldEventRisk.normal);
    expect(result.review.available, isFalse);
    expect(result.review.risk, FundamentalRisk.normal);
    expect(result.contextAudit.newsAvailable, isFalse);
    expect(result.contextAudit.calendarAvailable, isFalse);
  });
}
