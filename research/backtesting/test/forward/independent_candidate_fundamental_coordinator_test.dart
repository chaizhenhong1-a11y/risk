import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_closed_bar_store.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';
import 'package:tradeforge_backtesting/src/forward/independent_candidate_fundamental_coordinator.dart';
import 'package:tradeforge_backtesting/src/fundamentals/candidate_fundamental_review_service.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_event_context.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_news_context.dart';

void main() {
  CandidateFundamentalReviewService service({
    required void Function(Map<String, dynamic>) captureCandidate,
    void Function()? onAiCall,
  }) => CandidateFundamentalReviewService(
    loadNews: (now) async => GoldNewsContext(
      observedAtUtc: now,
      items: const [],
      availability: GoldNewsAvailability.available,
      provider: 'test',
    ),
    loadEvents: (now) async => GoldEventContext(
      observedAtUtc: now,
      events: const [],
      risk: GoldEventRisk.normal,
      source: 'test',
    ),
    review: (candidate, _, _) async {
      captureCandidate(candidate);
      onAiCall?.call();
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

  test('reviews independent candidate once and skips same exposure', () async {
    var aiCalls = 0;
    Map<String, dynamic>? captured;
    final coordinator = IndependentCandidateFundamentalCoordinator(
      service(
        captureCandidate: (value) => captured = value,
        onAiCall: () => aiCalls++,
      ),
    );
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
    expect(aiCalls, 1);
    expect(captured?['marketContext'], isNull);
  });

  test(
    'injects candidate-time CLOSED M5 M15 H1 H4 context into AI review',
    () async {
      final store = BiQuoteClosedBarStore();
      final observedAt = DateTime.utc(2026, 9, 19, 12);
      for (final tf in BiQuoteTimeframe.values) {
        store.addAll([
          _bar(tf, observedAt.subtract(tf.duration), 4300),
          _bar(tf, observedAt, 4310),
          // This later bar must never leak into the candidate review.
          _bar(tf, observedAt.add(tf.duration), 9999),
        ]);
      }

      Map<String, dynamic>? captured;
      final coordinator = IndependentCandidateFundamentalCoordinator(
        service(captureCandidate: (value) => captured = value),
        marketStore: store,
      );
      final history = <Map<String, Object?>>[
        {
          'id': 'C5|1',
          'strategy': 'C5',
          'side': 'BUY',
          'observedAt': observedAt.toIso8601String(),
          'entry': 4310.0,
          'stopLoss': 4300.0,
          'takeProfit': 4330.0,
          'riskReward': 2.0,
          'reason': 'trigger',
          'exposureStatus': 'independent',
          'independentEvidence': true,
        },
      ];

      await coordinator.enrich(history);

      final context = captured?['marketContext'] as Map<String, Object?>?;
      expect(context, isNotNull);
      expect(context?['observedAt'], observedAt.toIso8601String());
      final frames =
          context?['timeframes'] as Map<String, Map<String, Object?>>?;
      expect(frames?.keys, containsAll(<String>['M5', 'M15', 'H1', 'H4']));
      expect(frames?['M5']?['lastClose'], 4310.0);

      final review =
          history.single['fundamentalReview'] as Map<String, Object?>?;
      final audit = review?['aiContextAudit'] as Map<String, Object?>?;
      expect(audit?['marketContextAvailable'], isTrue);
      expect(audit?['coverage'], 'FULL');
    },
  );

  test(
    'missing one timeframe stays fail-open and candidate is preserved',
    () async {
      final store = BiQuoteClosedBarStore();
      final observedAt = DateTime.utc(2026, 9, 19, 12);
      for (final tf in <BiQuoteTimeframe>[
        BiQuoteTimeframe.m5,
        BiQuoteTimeframe.m15,
        BiQuoteTimeframe.h1,
      ]) {
        store.addAll([_bar(tf, observedAt, 4310)]);
      }

      Map<String, dynamic>? captured;
      final coordinator = IndependentCandidateFundamentalCoordinator(
        service(captureCandidate: (value) => captured = value),
        marketStore: store,
      );
      final history = <Map<String, Object?>>[
        {
          'id': 'A|1',
          'strategy': 'A',
          'side': 'SELL',
          'observedAt': observedAt.toIso8601String(),
          'entry': 4310.0,
          'stopLoss': 4320.0,
          'takeProfit': 4290.0,
          'riskReward': 2.0,
          'reason': 'trigger',
          'exposureStatus': 'independent',
          'independentEvidence': true,
        },
      ];

      await coordinator.enrich(history);

      expect(captured?['marketContext'], isNull);
      final review =
          history.single['fundamentalReview'] as Map<String, Object?>?;
      expect(review?['candidatePreserved'], isTrue);
      final audit = review?['aiContextAudit'] as Map<String, Object?>?;
      expect(audit?['marketContextAvailable'], isFalse);
      expect(audit?['coverage'], 'PARTIAL');
    },
  );
}

BiQuoteClosedBar _bar(
  BiQuoteTimeframe timeframe,
  DateTime closeTime,
  double close,
) => BiQuoteClosedBar(
  symbol: 'XAUUSD',
  timeframe: timeframe,
  openTime: closeTime.subtract(timeframe.duration),
  open: close - 1,
  high: close + 2,
  low: close - 2,
  close: close,
  tickVolume: 100,
);
